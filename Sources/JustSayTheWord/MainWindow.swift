// ABOUTME: The app's one window: a sidebar of sections (History, Settings, Activity) and the selected one beside it.
// ABOUTME: While it is open the app shows in the Dock like any other; closing it leaves only the menu-bar icon.
import Cocoa
import SwiftUI

final class MainWindow: NSObject, NSWindowDelegate {
    private let model: AppModel
    private let window: NSWindow

    init(model: AppModel) {
        self.model = model
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        super.init()
        window.title = AppInfo.name
        window.isReleasedWhenClosed = false
        let content = NSHostingController(rootView: MainView(model: model))
        // The window keeps the size it is given (and later the one the user gives it), not the content's ideal one.
        content.sizingOptions = []
        window.contentViewController = content
        window.setContentSize(NSSize(width: 820, height: 560))
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.center()
        window.setFrameAutosaveName("Main")
        window.delegate = self
    }

    var isVisible: Bool { window.isVisible }

    /// Opens the window, on `section` when one is given, and brings the app to the front.
    func show(_ section: AppModel.Section? = nil) {
        if let section { model.section = section }
        model.refresh()
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        model.refresh()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct MainView: View {
    let model: AppModel

    var body: some View {
        NavigationSplitView {
            List(AppModel.Section.allCases, selection: selection) { section in
                Label(section.title, systemImage: section.symbol).tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
            .safeAreaInset(edge: .bottom) {
                Label {
                    Text(model.status)
                } icon: {
                    Image(nsImage: StatusIcon.mark(side: 12)).renderingMode(.template)
                }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } detail: {
            switch model.section {
            case .history: HistoryView(model: model)
            case .settings: SettingsView(model: model)
            case .activity: ActivityView(model: model)
            }
        }
    }

    /// The sidebar always has one section selected, so a cleared selection is ignored.
    private var selection: Binding<AppModel.Section?> {
        Binding(
            get: { model.section },
            set: { section in
                if let section { model.section = section }
            }
        )
    }
}
