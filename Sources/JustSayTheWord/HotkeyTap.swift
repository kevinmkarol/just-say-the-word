// ABOUTME: A listen-only CGEvent tap that reports the hotkey modifier going down and up, any other key press, and Escape.
// ABOUTME: Needs the Accessibility permission; tapCreate returns nil without it, so start() reports false and is retried.
import Cocoa
import JustSayTheWordCore

final class HotkeyTap {
    /// Stamped on the key events Paster posts (⌘V, Return), so the tap doesn't take our own paste for a shortcut.
    static let syntheticMarker: Int64 = 0xD1C7

    var hotkey: Hotkey
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?
    var onOtherKeyDown: (() -> Void)?
    var onEscape: (() -> Void)?

    private var port: CFMachPort?
    private var hotkeyIsDown = false

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    var isRunning: Bool { port != nil }

    func start() -> Bool {
        if port != nil { return true }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            if let refcon {
                Unmanaged<HotkeyTap>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.port = port
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
        case .flagsChanged:
            guard event.getIntegerValueField(.keyboardEventKeycode) == hotkey.keyCode else { return }
            let down = event.flags.rawValue & hotkey.deviceFlag != 0
            guard down != hotkeyIsDown else { return }
            hotkeyIsDown = down
            let handler = down ? onHotkeyDown : onHotkeyUp
            DispatchQueue.main.async { handler?() }
        case .keyDown:
            guard event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else { return }
            let handler = event.getIntegerValueField(.keyboardEventKeycode) == 53 ? onEscape : onOtherKeyDown
            DispatchQueue.main.async { handler?() }
        default:
            break
        }
    }
}
