// ABOUTME: What the main window shows: the settings, recent transcripts, failed recordings, the activity log and
// ABOUTME: the permissions the app has. The app delegate keeps it current; the views read it and send changes back.
import AVFoundation
import Cocoa
import JustSayTheWordCore
import SwiftUI

@Observable
final class AppModel {
    enum Section: String, CaseIterable, Identifiable {
        case history, settings, activity

        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var symbol: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            case .activity: return "list.bullet.rectangle"
            }
        }
    }

    var section: Section = .history
    /// What the app is doing right now, in the menu's words.
    var status = ""
    var config = Config()
    var transcripts: [Transcript] = []
    var failedRecordings: [URL] = []
    var activity: [ActivityEntry] = []
    var inputs: [String] = []
    var defaultInput: String?
    var hasAccessibility = false
    var hasMicrophone = false
    var launchesAtLogin = false

    /// How the window hands a change back to the app; set by the app delegate.
    var changeConfig: (Config) -> Void = { _ in }
    var retry: (URL) -> Void = { _ in }

    private let recordings: FailedRecordings

    init(recordings: FailedRecordings) {
        self.recordings = recordings
    }

    /// Reads again everything that lives outside the app's memory: files, devices, permissions.
    func refresh() {
        transcripts = History.recent(limit: 500)
        failedRecordings = recordings.all().reversed()
        activity = Log.recent(limit: 500)
        inputs = AudioDevices.inputDevices().map(\.name)
        defaultInput = AudioDevices.defaultInput()?.name
        hasAccessibility = AXIsProcessTrusted()
        hasMicrophone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        launchesAtLogin = LoginItem.isEnabled
    }

    /// A binding to one setting that saves and applies the change as it is made.
    func binding<Value>(_ setting: WritableKeyPath<Config, Value>) -> Binding<Value> {
        Binding(
            get: { self.config[keyPath: setting] },
            set: { value in
                var changed = self.config
                changed[keyPath: setting] = value
                self.changeConfig(changed)
            }
        )
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            try LoginItem.setEnabled(enabled)
        } catch {
            Log.problem("could not change launch at login: \(error.localizedDescription)")
        }
        refresh()
    }
}
