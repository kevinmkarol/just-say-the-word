// ABOUTME: Tests that the config file is optional in every key and round-trips, the hotkey table, and the rules for
// ABOUTME: which apps Return is pressed in.
import XCTest
@testable import JustSayTheWordCore

final class ConfigTests: XCTestCase {
    func testEmptyObjectIsAllDefaults() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        XCTAssertEqual(config, Config())
        XCTAssertEqual(config.hotkey, .rightCommand)
        XCTAssertTrue(config.paste)
        XCTAssertFalse(config.restoreClipboard)
        XCTAssertFalse(config.pressReturn)
        XCTAssertEqual(config.pressReturnApps, [])
        XCTAssertTrue(config.indicator)
    }

    func testTheModelsDefaultToTheOnesBuiltIntoTheApp() {
        let config = Config()
        XCTAssertEqual(config.modelPath(builtIn: "/app/medium.bin"), "/app/medium.bin")
        XCTAssertEqual(config.vadModelPath(builtIn: "/app/vad.bin"), "/app/vad.bin")
    }

    func testAConfiguredModelReplacesTheBuiltInOne() {
        var config = Config()
        config.model = "~/models/large.bin"
        config.vadModel = "/models/vad.bin"
        XCTAssertEqual(config.modelPath(builtIn: "/app/medium.bin"), Config.expand("~/models/large.bin"))
        XCTAssertEqual(config.vadModelPath(builtIn: "/app/vad.bin"), "/models/vad.bin")
    }

    func testTheVocabularyDefaultsToTheAppsConfigFolder() {
        XCTAssertEqual(Config().vocabulary, "~/.config/just-say-the-word/vocabulary.txt")
    }

    func testTheSpeechEngineIsNotASetting() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("config.json")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data(#"{"whisperCli": "/tmp/whisper-cli", "hotkey": "fn"}"#.utf8).write(to: url)
        let config = try Config.load(from: url)
        XCTAssertEqual(config.hotkey, .fn, "a file that names an engine still loads")
        try config.save(to: url)
        XCTAssertFalse(try String(contentsOf: url, encoding: .utf8).contains("whisperCli"))
    }

    func testARecordingIsAllowedAtLeastOneSecond() throws {
        var config = Config()
        config.maxSeconds = 0
        XCTAssertEqual(config.maxSeconds, 1)
        config = try JSONDecoder().decode(Config.self, from: Data(#"{"maxSeconds": -5}"#.utf8))
        XCTAssertEqual(config.maxSeconds, 1)
        config.maxSeconds = 20
        XCTAssertEqual(config.maxSeconds, 20)
    }

    func testTheConfigFolderIsReadableByItsUserAlone() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Config().save(to: dir.appendingPathComponent("config.json"))
        let permissions = try FileManager.default.attributesOfItem(atPath: dir.path)[.posixPermissions] as? Int
        XCTAssertEqual(permissions, 0o700)
    }

    func testTheIndicatorCanBeTurnedOff() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"indicator": false}"#.utf8))
        XCTAssertFalse(config.indicator)
    }

    func testReturnIsNeverPressedWhileTheSettingIsOff() throws {
        let json = #"{"pressReturnApps": ["iTerm2"]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertFalse(config.pressesReturn(inAppNamed: "iTerm2", bundleIdentifier: "com.googlecode.iterm2"))
    }

    func testReturnIsPressedInEveryAppWhenNoAppsAreListed() throws {
        let config = try JSONDecoder().decode(Config.self, from: Data(#"{"pressReturn": true}"#.utf8))
        XCTAssertTrue(config.pressesReturn(inAppNamed: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"))
        XCTAssertTrue(config.pressesReturn(inAppNamed: nil, bundleIdentifier: nil))
    }

    func testReturnIsPressedOnlyInTheListedApps() throws {
        let json = #"{"pressReturn": true, "pressReturnApps": ["iterm2", "com.apple.notes"]}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertTrue(
            config.pressesReturn(inAppNamed: "iTerm2", bundleIdentifier: "com.googlecode.iterm2"),
            "an app's name matches whatever its case"
        )
        XCTAssertTrue(
            config.pressesReturn(inAppNamed: "Notes", bundleIdentifier: "com.apple.Notes"),
            "so does its bundle identifier"
        )
        XCTAssertFalse(config.pressesReturn(inAppNamed: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap"))
        XCTAssertFalse(config.pressesReturn(inAppNamed: "iTerm2 Helper", bundleIdentifier: nil), "no partial matches")
        XCTAssertFalse(config.pressesReturn(inAppNamed: nil, bundleIdentifier: nil))
    }

    func testTheAppsToChooseFromAreTheListedOnesAndTheOpenOnes() {
        var config = Config()
        config.pressReturnApps = ["iTerm2", "com.apple.Notes"]
        XCTAssertEqual(
            config.pressReturnChoices(openApps: ["Slack", "iterm2", "Finder", "Slack"]),
            ["com.apple.Notes", "Finder", "iTerm2", "Slack"],
            "in alphabetical order, each once, a listed app under the spelling it is listed by"
        )
    }

    func testChoosingAnAppListsItAndChoosingItAgainRemovesIt() {
        var config = Config()
        config.togglePressReturn(inApp: "Slack")
        config.togglePressReturn(inApp: "iTerm2")
        XCTAssertEqual(config.pressReturnApps, ["Slack", "iTerm2"])
        config.togglePressReturn(inApp: "slack")
        XCTAssertEqual(config.pressReturnApps, ["iTerm2"], "an app's name matches whatever its case")
    }

    func testKeysOverrideIndividually() throws {
        let json = #"{"hotkey": "rightOption", "inputDevice": "USB Microphone", "paste": false}"#
        let config = try JSONDecoder().decode(Config.self, from: Data(json.utf8))
        XCTAssertEqual(config.hotkey, .rightOption)
        XCTAssertEqual(config.inputDevice, "USB Microphone")
        XCTAssertFalse(config.paste)
        XCTAssertEqual(config.model, Config().model)
    }

    func testUnknownHotkeyIsAnError() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(Config.self, from: Data(#"{"hotkey": "spacebar"}"#.utf8))
        )
    }

    func testMissingFileIsCreatedWithDefaults() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("config.json")
        XCTAssertEqual(try Config.load(from: url), Config())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"hotkey\" : \"rightCommand\""))
        var edited = Config()
        edited.hotkey = .fn
        try edited.save(to: url)
        XCTAssertEqual(try Config.load(from: url).hotkey, .fn)
    }

    func testTildeExpansion() {
        XCTAssertFalse(Config.expand("~/x").hasPrefix("~"))
        XCTAssertEqual(Config.expand("/opt/x"), "/opt/x")
    }

    func testEveryHotkeyHasItsKeyCodeDeviceFlagAndLabel() {
        XCTAssertEqual(Hotkey.allCases.map(\.keyCode), [54, 55, 61, 58, 62, 59, 60, 56, 63])
        XCTAssertEqual(Hotkey.allCases.map(\.deviceFlag), [0x10, 0x08, 0x40, 0x20, 0x2000, 0x01, 0x04, 0x02, 0x80_0000])
        XCTAssertEqual(
            Hotkey.allCases.map(\.label),
            ["Right ⌘", "Left ⌘", "Right ⌥", "Left ⌥", "Right ⌃", "Left ⌃", "Right ⇧", "Left ⇧", "fn"]
        )
    }
}
