// ABOUTME: Tests the whisper-cli argument list, the vocabulary file and its prompt, and the reading of
// ABOUTME: whisper-cli's JSON.
import XCTest
@testable import JustSayTheWordCore

final class WhisperTests: XCTestCase {
    func testArgumentsNameTheModelTheClipTheOutputAndTheOptions() {
        let args = WhisperCommand.arguments(
            model: "/m.bin", vadModel: "/vad.bin", prompt: "Ada, Grace", language: "en",
            audio: "/clip.wav", outputPrefix: "/tmp/out"
        )
        XCTAssertEqual(args[0...1], ["-m", "/m.bin"])
        XCTAssertEqual(args[args.firstIndex(of: "-f")! + 1], "/clip.wav")
        XCTAssertTrue(args.contains("-np") && args.contains("-sns") && args.contains("-oj"))
        XCTAssertEqual(args[args.firstIndex(of: "-of")! + 1], "/tmp/out")
        XCTAssertEqual(args[args.firstIndex(of: "-vm")! + 1], "/vad.bin")
        XCTAssertEqual(args[args.firstIndex(of: "--prompt")! + 1], "Ada, Grace")
    }

    func testVadAndPromptAreOptional() {
        let args = WhisperCommand.arguments(
            model: "/m.bin", vadModel: nil, prompt: "", language: "en", audio: "/a", outputPrefix: "/o"
        )
        XCTAssertFalse(args.contains("--vad"))
        XCTAssertFalse(args.contains("--prompt"))
    }

    func testVocabularyPrompt() {
        XCTAssertEqual(Vocabulary.prompt(from: "# names\nAda\n\n  Grace \nLinus\n"), "Ada, Grace, Linus")
        XCTAssertEqual(Vocabulary.prompt(from: ""), "")
    }

    func testAMissingVocabularyFileIsCreatedWithItsInstructions() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("vocabulary.txt")
        try Vocabulary.createFile(at: url)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.hasPrefix("# Names and terms"))
        XCTAssertEqual(Vocabulary.prompt(from: text), "", "the instructions are comments")
    }

    func testAnExistingVocabularyFileIsLeftAsItIs() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt")
        try "Ada\n".write(to: url, atomically: true, encoding: .utf8)
        try Vocabulary.createFile(at: url)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "Ada\n")
    }

    func testSegmentsAreJoinedAndSilenceIsEmpty() throws {
        let json = """
        {"transcription": [{"text": " First sentence.", "offsets": {"from": 0, "to": 1000}},
                           {"text": "  ", "offsets": {"from": 1000, "to": 1500}},
                           {"text": " Second one.", "offsets": {"from": 1500, "to": 3000}}]}
        """
        XCTAssertEqual(try WhisperOutput.text(fromJSON: Data(json.utf8)), "First sentence. Second one.")
        XCTAssertEqual(try WhisperOutput.text(fromJSON: Data(#"{"transcription": []}"#.utf8)), "")
        XCTAssertThrowsError(try WhisperOutput.text(fromJSON: Data("[]".utf8)))
    }
}
