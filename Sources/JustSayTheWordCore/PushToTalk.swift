// ABOUTME: The hold/tap state machine: when a hotkey press starts a recording, when its release ends one,
// ABOUTME: and when another key means "that was a shortcut, not dictation". Pure logic, no AppKit, fully tested.
import Foundation

public enum PushToTalkEvent: Equatable {
    case hotkeyDown(at: TimeInterval)
    case hotkeyUp(at: TimeInterval)
    case otherKeyDown
    case escape
    case timeout
}

public enum PushToTalkAction: Equatable {
    case start, stop, cancel, none
}

public final class PushToTalk {
    public enum State: Equatable {
        case idle
        case holding(since: TimeInterval)
        case handsFree
    }

    public var tapThreshold: TimeInterval
    public var tapTogglesHandsFree: Bool
    public private(set) var state: State = .idle

    public init(tapThreshold: TimeInterval = 0.3, tapTogglesHandsFree: Bool = true) {
        self.tapThreshold = tapThreshold
        self.tapTogglesHandsFree = tapTogglesHandsFree
    }

    public var isRecording: Bool { state != .idle }

    public func handle(_ event: PushToTalkEvent) -> PushToTalkAction {
        switch (state, event) {
        case (.idle, .hotkeyDown(let at)):
            state = .holding(since: at)
            return .start
        case (.holding(let since), .hotkeyUp(let at)):
            if tapTogglesHandsFree && at - since < tapThreshold {
                state = .handsFree
                return .none
            }
            state = .idle
            return .stop
        case (.holding, .otherKeyDown), (.holding, .escape):
            // A key pressed while the modifier is held is a shortcut (⌘C), not dictation.
            state = .idle
            return .cancel
        case (.handsFree, .hotkeyDown):
            state = .idle
            return .stop
        case (.handsFree, .escape):
            state = .idle
            return .cancel
        case (.holding, .timeout), (.handsFree, .timeout):
            state = .idle
            return .stop
        default:
            return .none
        }
    }
}
