// ABOUTME: Puts the transcript on the clipboard and presses ⌘V in the frontmost app (a synthetic key event, which
// ABOUTME: is why the app needs Accessibility). Optionally presses Return after it and puts the old clipboard back.
import Cocoa

enum Paster {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    static func paste(_ text: String, restoreClipboard: Bool, pressReturn: Bool) {
        let previous = restoreClipboard ? snapshot(NSPasteboard.general) : []
        copy(text)
        // A beat for the pasteboard change to land before the target app reads it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            press(vKey, flags: .maskCommand)
            if pressReturn {
                // A beat for the target app to take the paste in before the Return that submits it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { press(returnKey) }
            }
            guard !previous.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { restore(previous, to: NSPasteboard.general) }
        }
    }

    /// A copy of everything on the pasteboard, whatever its kind (text, an image, files), that can be put back.
    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func restore(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    private static let vKey: CGKeyCode = 9
    private static let returnKey: CGKeyCode = 36

    /// Presses and releases a key with exactly these modifiers, whatever is held on the real keyboard.
    private static func press(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: HotkeyTap.syntheticMarker)
            event.post(tap: .cghidEventTap)
        }
    }
}
