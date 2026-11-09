// ABOUTME: The start, stop and error sounds, each a system sound by name (/System/Library/Sounds), so the ear
// ABOUTME: knows when the microphone opens and closes without looking at the menu bar.
import Cocoa

enum Sounds {
    static let start = "Pop"
    static let stop = "Tink"
    static let error = "Basso"

    static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
