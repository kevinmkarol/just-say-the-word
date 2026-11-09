// ABOUTME: The app's settings, read from ~/.config/just-say-the-word/config.json; every key is optional and falls
// ABOUTME: back to a default. Also decides which apps Return is pressed in.
import Foundation

/// A modifier key held on its own: its key code (what the event tap sees), the device bit in CGEventFlags that is
/// set while this exact key is down (NX_DEVICE*KEYMASK), which tells left from right, and its name in the settings.
public enum Hotkey: String, Codable, CaseIterable {
    case rightCommand, leftCommand, rightOption, leftOption, rightControl, leftControl
    case rightShift, leftShift, fn

    public var keyCode: Int64 { key.code }
    public var deviceFlag: UInt64 { key.flag }
    public var label: String { key.label }

    private var key: (code: Int64, flag: UInt64, label: String) {
        switch self {
        case .rightCommand: return (54, 0x10, "Right ⌘")
        case .leftCommand: return (55, 0x08, "Left ⌘")
        case .rightOption: return (61, 0x40, "Right ⌥")
        case .leftOption: return (58, 0x20, "Left ⌥")
        case .rightControl: return (62, 0x2000, "Right ⌃")
        case .leftControl: return (59, 0x01, "Left ⌃")
        case .rightShift: return (60, 0x04, "Right ⇧")
        case .leftShift: return (56, 0x02, "Left ⇧")
        case .fn: return (63, 0x80_0000, "fn")  // NX_SECONDARYFNMASK
        }
    }
}

public struct Config: Codable, Equatable {
    public var hotkey: Hotkey = .rightCommand
    /// A press shorter than this is a tap: it leaves the recording running hands-free until the next tap.
    public var tapTogglesHandsFree = true
    public var tapThresholdMs = 300
    /// A recording stops itself after this long; never under a second, which would stop it before a word is said.
    public var maxSeconds = 600 {
        didSet { maxSeconds = max(1, maxSeconds) }
    }
    /// Part of an input device's name; empty means the system default input.
    public var inputDevice = ""
    public var paste = true
    /// Put whatever was on the clipboard back after pasting. Off by default, so the transcript stays on the
    /// clipboard in case the paste went to the wrong window.
    public var restoreClipboard = false
    /// Press Return after the paste, which submits the transcript (a prompt, a chat message).
    public var pressReturn = false
    /// The apps Return is pressed in, each by name ("iTerm2") or bundle identifier; empty means every app.
    public var pressReturnApps: [String] = []
    /// Show the floating indicator (level bars, then "Transcribing") at the bottom of the screen.
    public var indicator = true
    public var sounds = true
    public var language = "en"
    /// A ggml Whisper model file; empty means the one built into the app.
    public var model = ""
    /// A ggml voice detection model file; empty means the one built into the app.
    public var vadModel = ""
    public var vocabulary = "~/.config/just-say-the-word/vocabulary.txt"

    public static let defaultPath = "~/.config/just-say-the-word/config.json"
    public static var url: URL { URL(fileURLWithPath: expand(defaultPath)) }

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = Config()
        d.hotkey = try c.decodeIfPresent(Hotkey.self, forKey: .hotkey) ?? d.hotkey
        d.tapTogglesHandsFree = try c.decodeIfPresent(Bool.self, forKey: .tapTogglesHandsFree) ?? d.tapTogglesHandsFree
        d.tapThresholdMs = try c.decodeIfPresent(Int.self, forKey: .tapThresholdMs) ?? d.tapThresholdMs
        d.maxSeconds = try c.decodeIfPresent(Int.self, forKey: .maxSeconds) ?? d.maxSeconds
        d.inputDevice = try c.decodeIfPresent(String.self, forKey: .inputDevice) ?? d.inputDevice
        d.paste = try c.decodeIfPresent(Bool.self, forKey: .paste) ?? d.paste
        d.restoreClipboard = try c.decodeIfPresent(Bool.self, forKey: .restoreClipboard) ?? d.restoreClipboard
        d.pressReturn = try c.decodeIfPresent(Bool.self, forKey: .pressReturn) ?? d.pressReturn
        d.pressReturnApps = try c.decodeIfPresent([String].self, forKey: .pressReturnApps) ?? d.pressReturnApps
        d.indicator = try c.decodeIfPresent(Bool.self, forKey: .indicator) ?? d.indicator
        d.sounds = try c.decodeIfPresent(Bool.self, forKey: .sounds) ?? d.sounds
        d.language = try c.decodeIfPresent(String.self, forKey: .language) ?? d.language
        d.model = try c.decodeIfPresent(String.self, forKey: .model) ?? d.model
        d.vadModel = try c.decodeIfPresent(String.self, forKey: .vadModel) ?? d.vadModel
        d.vocabulary = try c.decodeIfPresent(String.self, forKey: .vocabulary) ?? d.vocabulary
        self = d
    }

    public static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }

    /// The Whisper model to transcribe with: the configured file, or the app's own (`builtIn`) when none is.
    public func modelPath(builtIn: String) -> String {
        model.isEmpty ? builtIn : Config.expand(model)
    }

    /// The voice detection model, chosen as the Whisper model is.
    public func vadModelPath(builtIn: String) -> String {
        vadModel.isEmpty ? builtIn : Config.expand(vadModel)
    }

    /// Whether a paste into the frontmost app, known by its name and bundle identifier, is followed by Return.
    public func pressesReturn(inAppNamed name: String?, bundleIdentifier: String?) -> Bool {
        guard pressReturn else { return false }
        if pressReturnApps.isEmpty { return true }
        let frontmost = [name, bundleIdentifier].compactMap { $0?.lowercased() }
        return pressReturnApps.contains { frontmost.contains($0.lowercased()) }
    }

    /// The apps to offer for `pressReturnApps`: the ones listed and the ones open now (`openApps`, by name), in
    /// alphabetical order. An open app that is listed appears once, under the spelling it is listed by.
    public func pressReturnChoices(openApps: [String]) -> [String] {
        var choices = pressReturnApps
        for app in openApps where !choices.contains(where: { $0.lowercased() == app.lowercased() }) {
            choices.append(app)
        }
        return choices.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Lists the app in `pressReturnApps`, or takes it off the list when it is already there.
    public mutating func togglePressReturn(inApp name: String) {
        if pressReturnApps.contains(where: { $0.lowercased() == name.lowercased() }) {
            pressReturnApps.removeAll { $0.lowercased() == name.lowercased() }
        } else {
            pressReturnApps.append(name)
        }
    }

    /// The config at `url`; a missing file is written with the defaults so there is something to edit.
    public static func load(from url: URL = url) throws -> Config {
        if !FileManager.default.fileExists(atPath: url.path) {
            try Config().save(to: url)
            return Config()
        }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    }

    public func save(to url: URL = url) throws {
        try Config.createFolder(for: url)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url)
    }

    /// Makes the folder the config file (`url`) lives in, readable by its user alone: it holds the vocabulary too,
    /// and ~/.config is usually open to every account on the Mac. The permissions are set on every save, in case
    /// the folder was made by hand.
    private static func createFolder(for url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
    }
}
