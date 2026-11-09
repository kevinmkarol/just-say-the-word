// ABOUTME: Clears out what a previous run left in the temporary folder: a recording or a transcription folder that
// ABOUTME: outlived the app because it was quit or crashed mid-dictation, so no audio lingers there.
import Foundation

public enum TempFiles {
    /// What the app's own entries in the temporary folder are named with, so they can be told from everything else there.
    public static let prefix = "just-say-the-word-"

    /// Removes every entry of `directory` whose name starts with `prefix`. A missing directory has nothing to remove.
    public static func removeLeftovers(in directory: URL, prefix: String) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }
        for entry in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where entry.lastPathComponent.hasPrefix(prefix) {
            try fm.removeItem(at: entry)
        }
    }
}
