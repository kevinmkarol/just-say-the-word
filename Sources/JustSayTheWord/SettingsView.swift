// ABOUTME: The Settings section: the settings as a form (all but the tap threshold, which stays a config-file key),
// ABOUTME: plus the permissions the app needs and whether it opens at login. Each change is saved as it is made.
import Cocoa
import JustSayTheWordCore
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        Form {
            Section("Permissions") {
                PermissionRow(
                    name: "Accessibility", purpose: "Hears the hotkey and pastes the transcript.",
                    isGranted: model.hasAccessibility, pane: "Privacy_Accessibility"
                )
                PermissionRow(
                    name: "Microphone", purpose: "Records while you hold the hotkey.",
                    isGranted: model.hasMicrophone, pane: "Privacy_Microphone"
                )
            }

            Section("General") {
                Toggle("Open at login", isOn: Binding(
                    get: { model.launchesAtLogin },
                    set: { model.setLaunchesAtLogin($0) }
                ))
                Toggle("Play sounds", isOn: model.binding(\.sounds))
                Toggle("Show the indicator while recording", isOn: model.binding(\.indicator))
            }

            Section("Recording") {
                Picker("Hotkey", selection: model.binding(\.hotkey)) {
                    ForEach(Hotkey.allCases, id: \.self) { hotkey in
                        Text(hotkey.label).tag(hotkey)
                    }
                }
                Toggle("A short tap records hands-free", isOn: model.binding(\.tapTogglesHandsFree))
                Picker("Microphone", selection: model.binding(\.inputDevice)) {
                    Text("System Default" + (model.defaultInput.map { " (\($0))" } ?? "")).tag("")
                    ForEach(microphones, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                TextField("Longest recording, in seconds", value: model.binding(\.maxSeconds), format: .number)
            }

            Section("After transcribing") {
                Toggle("Paste into the app in front", isOn: model.binding(\.paste))
                Toggle("Put the previous clipboard back", isOn: model.binding(\.restoreClipboard))
                    .disabled(!model.config.paste)
                Toggle("Press Return after pasting", isOn: model.binding(\.pressReturn))
                    .disabled(!model.config.paste)
                ReturnApps(model: model)
                    .disabled(!model.config.paste || !model.config.pressReturn)
            }

            Section("Transcription") {
                TextField("Language", text: model.binding(\.language))
                TextField("Model", text: model.binding(\.model), prompt: Text("Built in"))
                TextField("Voice detection model", text: model.binding(\.vadModel), prompt: Text("Built in"))
                TextField("Vocabulary", text: model.binding(\.vocabulary))
            }

            Section {
                Button("Show Config File in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Config.url])
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }

    /// The inputs to choose from, including the configured one when no connected device has exactly that name
    /// (the config matches on part of a name, and the device may be unplugged).
    private var microphones: [String] {
        let configured = model.config.inputDevice
        return model.inputs + (configured.isEmpty || model.inputs.contains(configured) ? [] : [configured])
    }
}

private struct PermissionRow: View {
    let name: String
    let purpose: String
    let isGranted: Bool
    /// The anchor of the pane in System Settings → Privacy & Security.
    let pane: String

    var body: some View {
        LabeledContent {
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button("Open System Settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        } label: {
            Text(name)
            Text(purpose)
        }
    }
}

/// The apps Return is pressed in, as one menu: every app, or the ones ticked in it.
private struct ReturnApps: View {
    let model: AppModel

    private var apps: [String] { model.config.pressReturnApps }

    /// The names of the apps that are open and have a place in the Dock, which is what the menu can offer:
    /// macOS has no list of the apps a paste could land in.
    private var openApps: [String] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0 != .current }
            .compactMap(\.localizedName)
    }

    var body: some View {
        LabeledContent {
            Menu(apps.isEmpty ? "Every App" : apps.joined(separator: ", ")) {
                Toggle("Every App", isOn: Binding(get: { apps.isEmpty }, set: { _ in change { $0.pressReturnApps = [] } }))
                Divider()
                ForEach(model.config.pressReturnChoices(openApps: openApps), id: \.self) { app in
                    Toggle(app, isOn: Binding(
                        get: { apps.contains(app) },
                        set: { _ in change { $0.togglePressReturn(inApp: app) } }
                    ))
                }
            }
            .fixedSize()
        } label: {
            Text("Press Return in")
            Text("The menu lists the apps that are open right now. To add another, open it first.")
        }
    }

    private func change(_ edit: (inout Config) -> Void) {
        var changed = model.config
        edit(&changed)
        model.changeConfig(changed)
    }
}
