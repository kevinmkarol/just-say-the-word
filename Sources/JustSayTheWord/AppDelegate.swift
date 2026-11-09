// ABOUTME: The menu-bar app: wires the hotkey tap through the push-to-talk machine to the recorder, whisper-cli and
// ABOUTME: the paster, and shows the state in the status item, the floating indicator and the main window.
import AVFoundation
import Cocoa
import JustSayTheWordCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    /// False when the app was started in the background (`--background`), which opens no window.
    var opensWindowAtLaunch = true

    private var config = Config()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let indicator = Indicator()
    private let pushToTalk = PushToTalk()
    private var tap: HotkeyTap!
    private let recorder = Recorder()
    private let transcriber = Transcriber()
    private let failedRecordings = FailedRecordings(
        directory: History.url.deletingLastPathComponent().appendingPathComponent("Failed Recordings")
    )
    private lazy var model = AppModel(recordings: failedRecordings)
    private lazy var mainWindow = MainWindow(model: model)
    private var maxTimer: Timer?
    private var levelTimer: Timer?
    private var idleTimer: Timer?
    private var inputName = "system default"
    private var isTranscribing = false
    private var iconState = StatusIcon.State.ready

    private let stateItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "Grant Accessibility Permission…", action: #selector(openAccessibility), keyEquivalent: ""
    )
    private let retryItem = NSMenuItem(title: "Retry Failed Recording", action: #selector(retryFailedRecording), keyEquivalent: "")
    private let returnItem = NSMenuItem(title: "Press Return After Pasting", action: #selector(togglePressReturn), keyEquivalent: "")
    private let recentSeparator = NSMenuItem.separator()
    private let recentHeader = NSMenuItem.sectionHeader(title: "Copy a Recent Transcript")
    private var recentItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfig()
        try? Vocabulary.createFile(at: URL(fileURLWithPath: Config.expand(config.vocabulary)))
        // A run that ended mid-dictation leaves its recording behind; no other run of the app is going at launch.
        try? TempFiles.removeLeftovers(in: FileManager.default.temporaryDirectory, prefix: TempFiles.prefix)
        buildMenu()
        setIcon(.ready)
        NSApp.mainMenu = MainMenu.make(appName: AppInfo.name, settings: #selector(showSettings), target: self)
        model.changeConfig = { [weak self] changed in self?.change(changed) }
        model.retry = { [weak self] clip in self?.retry(clip) }
        Log.write("\(AppInfo.name) started; hotkey \(config.hotkey.label); config \(Config.url.path)")
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                Log.write("microphone access granted")
            } else {
                Log.problem("microphone access denied")
            }
        }
        tap = HotkeyTap(hotkey: config.hotkey)
        tap.onHotkeyDown = { [weak self] in self?.act(.hotkeyDown(at: Date().timeIntervalSinceReferenceDate)) }
        tap.onHotkeyUp = { [weak self] in self?.act(.hotkeyUp(at: Date().timeIntervalSinceReferenceDate)) }
        tap.onOtherKeyDown = { [weak self] in self?.act(.otherKeyDown) }
        tap.onEscape = { [weak self] in self?.act(.escape) }
        startTapWhenTrusted()
        if opensWindowAtLaunch && !LoginItem.startedThisLaunch { mainWindow.show() }
    }

    /// Opening the app again while it runs (from Finder, Spotlight or the Dock) shows its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        mainWindow.show()
        return false
    }

    // MARK: - Setup

    private func loadConfig() {
        do {
            config = try Config.load()
        } catch {
            Log.problem("config error, keeping the previous settings: \(error.localizedDescription)")
        }
        applyConfig()
    }

    /// Takes a change to the settings, from the menu or the window: saves it and puts it into effect.
    private func change(_ changed: Config) {
        config = changed
        do { try config.save() } catch { Log.problem("could not save config: \(error.localizedDescription)") }
        applyConfig()
    }

    /// Pushes the settings into everything that depends on them.
    private func applyConfig() {
        pushToTalk.tapThreshold = Double(config.tapThresholdMs) / 1000
        pushToTalk.tapTogglesHandsFree = config.tapTogglesHandsFree
        tap?.hotkey = config.hotkey
        returnItem.state = config.pressReturn ? .on : .off
        returnItem.isEnabled = config.paste
        let apps = config.pressReturnApps.joined(separator: ", ")
        returnItem.title = "Press Return After Pasting" + (apps.isEmpty ? "" : " in \(apps)")
        indicator.isEnabled = config.indicator
        setIcon(iconState)
        model.config = config
    }

    private func startTapWhenTrusted() {
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(prompt), startTap() { return }
        setState("Needs Accessibility permission", icon: .unavailable)
        Log.problem("waiting for Accessibility: System Settings → Privacy & Security → Accessibility → \(AppInfo.name)")
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] timer in
            if AXIsProcessTrusted(), self?.startTap() == true { timer.invalidate() }
        }
    }

    private func startTap() -> Bool {
        guard tap.start() else { return false }
        Log.write("hotkey tap running")
        showIdle()
        return true
    }

    /// The menu holds what is wanted without opening the window: the state and what it calls for, the Return
    /// toggle, and the latest transcripts to copy again. Everything else is in the window.
    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        accessibilityItem.target = self
        accessibilityItem.image = Self.menuSymbol("exclamationmark.triangle")
        menu.addItem(accessibilityItem)
        retryItem.target = self
        retryItem.image = Self.menuSymbol("arrow.clockwise")
        menu.addItem(retryItem)
        menu.addItem(.separator())
        returnItem.target = self
        returnItem.image = Self.menuSymbol("return")
        menu.addItem(returnItem)
        menu.addItem(recentSeparator)
        menu.addItem(recentHeader)
        menu.addItem(.separator())
        let openItem = NSMenuItem(title: "Open \(AppInfo.name)", action: #selector(showWindow), keyEquivalent: "")
        openItem.target = self
        openItem.image = Self.menuSymbol("macwindow")
        menu.addItem(openItem)
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        statusItem.menu = menu
    }

    private static func menuSymbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loadConfig()
        accessibilityItem.isHidden = AXIsProcessTrusted()
        let kept = failedRecordings.all().count
        retryItem.isHidden = kept == 0
        retryItem.title = "Retry Failed Recording" + (kept > 1 ? " (\(kept) kept)" : "")
        showRecentTranscripts(in: menu)
    }

    /// The last few transcripts under their heading, each copied to the clipboard when clicked.
    private func showRecentTranscripts(in menu: NSMenu) {
        recentItems.forEach(menu.removeItem)
        recentItems = History.recent(limit: 5).map { transcript in
            let text = transcript.text
            let item = NSMenuItem(
                title: text.count > 50 ? "\(text.prefix(50))…" : text, action: #selector(copyTranscript(_:)), keyEquivalent: ""
            )
            item.target = self
            item.representedObject = text
            item.toolTip = "\(transcript.time)\n\(text)"
            return item
        }
        recentSeparator.isHidden = recentItems.isEmpty
        recentHeader.isHidden = recentItems.isEmpty
        let first = menu.index(of: recentHeader) + 1
        for (offset, item) in recentItems.enumerated() {
            menu.insertItem(item, at: first + offset)
        }
    }

    // MARK: - Push to talk

    private func act(_ event: PushToTalkEvent) {
        switch pushToTalk.handle(event) {
        case .start: startRecording()
        case .stop: stopRecording()
        case .cancel: cancelRecording()
        case .none:
            if pushToTalk.state == .handsFree {
                setState("Recording hands-free · tap \(config.hotkey.label) to finish, Esc to cancel", icon: .recording)
                indicator.showRecording(
                    hint: "tap \(config.hotkey.label) to finish", pressesReturn: pressesReturnInFrontmostApp(config)
                )
            }
        }
    }

    private func startRecording() {
        loadConfig()
        var device: AudioDevice?
        if !config.inputDevice.isEmpty {
            device = AudioDevices.find(config.inputDevice)
            if device == nil { Log.problem("no input device matching '\(config.inputDevice)', using the default") }
        }
        inputName = device?.name ?? AudioDevices.defaultInput()?.name ?? "default"
        do {
            try recorder.start(device: device)
        } catch {
            fail("Can't record: \(error.localizedDescription)")
            return
        }
        if config.sounds { Sounds.play(Sounds.start) }
        setState("Recording · release \(config.hotkey.label) to transcribe", icon: .recording)
        indicator.showRecording(hint: nil, pressesReturn: pressesReturnInFrontmostApp(config))
        endRecordingTimers()
        maxTimer = Timer.scheduledTimer(withTimeInterval: Double(config.maxSeconds), repeats: false) { [weak self] _ in
            self?.act(.timeout)
        }
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.indicator.push(peak: self.recorder.level)
        }
    }

    private func endRecordingTimers() {
        maxTimer?.invalidate()
        levelTimer?.invalidate()
    }

    private func stopRecording() {
        endRecordingTimers()
        guard let clip = recorder.stop() else {
            indicator.hide()
            showIdle()
            return
        }
        if config.sounds { Sounds.play(Sounds.stop) }
        Log.write(String(format: "recorded %.1f s: %@, peak %.0f dBFS", clip.seconds, inputName, clip.peakDb))
        guard clip.seconds >= 0.3 else {
            try? FileManager.default.removeItem(at: clip.url)
            indicator.hide()
            showIdle()
            return
        }
        transcribe(clip.url, seconds: clip.seconds, isRetry: false)
    }

    /// Transcribes a clip and delivers the text. A clip whose transcription fails is kept so it can be retried
    /// from the menu or the window; one that succeeds is deleted. A retry (`isRetry`) is of a clip already kept,
    /// and its text is only copied: by then there is no telling what has focus.
    private func transcribe(_ clip: URL, seconds: Double, isRetry: Bool) {
        setState("Transcribing…", icon: .transcribing)
        let config = self.config
        indicator.showTranscribing(pressesReturn: !isRetry && pressesReturnInFrontmostApp(config))
        isTranscribing = true
        transcriber.transcribe(clip, config: config, clipSeconds: seconds) { [weak self] result in
            guard let self else { return }
            self.isTranscribing = false
            switch result {
            case .failure(let error):
                let kept = isRetry || self.keepFailedRecording(clip)
                self.fail("Transcription failed\(kept ? ", recording kept" : ""): \(error.localizedDescription)")
            case .success(let text):
                try? FileManager.default.removeItem(at: clip)
                self.deliver(text, seconds: seconds, config: config, pastes: config.paste && !isRetry)
            }
        }
    }

    private func keepFailedRecording(_ clip: URL) -> Bool {
        do {
            let kept = try failedRecordings.keep(clip, recordedAt: Date())
            Log.write("kept the recording: Retry in the menu or in History transcribes it again; \(kept.path)")
            return true
        } catch {
            Log.problem("could not keep the recording: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: clip)
            return false
        }
    }

    /// Whether a paste into the app that has focus right now would be followed by Return.
    private func pressesReturnInFrontmostApp(_ config: Config) -> Bool {
        guard config.paste else { return false }
        let frontmost = NSWorkspace.shared.frontmostApplication
        return config.pressesReturn(inAppNamed: frontmost?.localizedName, bundleIdentifier: frontmost?.bundleIdentifier)
    }

    /// Hands a transcript over: into the app in front when `pastes`, otherwise onto the clipboard only.
    private func deliver(_ text: String, seconds: Double, config: Config, pastes: Bool) {
        defer { refreshWindow() }
        guard !text.isEmpty else {
            setState("Heard nothing", icon: .ready)
            indicator.flash("Heard nothing", isProblem: false, seconds: 2)
            showIdle(after: 3)
            return
        }
        indicator.hide()
        History.append(text: text, seconds: seconds)
        if pastes {
            let pressReturn = pressesReturnInFrontmostApp(config)
            Paster.paste(text, restoreClipboard: config.restoreClipboard, pressReturn: pressReturn)
            setState("\(pressReturn ? "Submitted" : "Pasted"): \(text.prefix(50))", icon: .ready)
        } else {
            Paster.copy(text)
            setState("Copied: \(text.prefix(50))", icon: .ready)
        }
        showIdle(after: 6)
    }

    private func cancelRecording() {
        endRecordingTimers()
        recorder.cancel()
        indicator.hide()
        Log.write("recording cancelled")
        showIdle()
    }

    private func fail(_ message: String) {
        Log.problem(message)
        if config.sounds { Sounds.play(Sounds.error) }
        setState(message, icon: .problem)
        indicator.flash(message, isProblem: true, seconds: 4)
        showIdle(after: 8)
        refreshWindow()
    }

    /// Brings the window up to date with what just happened, when it is open to show it.
    private func refreshWindow() {
        if mainWindow.isVisible { model.refresh() }
    }

    // MARK: - Status item

    private func setState(_ title: String, icon: StatusIcon.State) {
        idleTimer?.invalidate()
        showStatus(title)
        setIcon(icon)
    }

    private func showStatus(_ title: String) {
        stateItem.title = title
        model.status = title
    }

    private func showIdle(after seconds: Double = 0) {
        idleTimer?.invalidate()
        let show = { [weak self] in
            guard let self, !self.recorder.isRecording else { return }
            self.showStatus("Idle · hold \(self.config.hotkey.label) to dictate")
            self.setIcon(self.tap.isRunning ? .ready : .unavailable)
        }
        if seconds > 0 {
            idleTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in show() }
        } else {
            show()
        }
    }

    private func setIcon(_ state: StatusIcon.State) {
        iconState = state
        statusItem.button?.image = StatusIcon.image(state, returnBadge: config.paste && config.pressReturn)
    }

    // MARK: - Menu actions

    @objc private func togglePressReturn() {
        var changed = config
        changed.pressReturn.toggle()
        change(changed)
    }

    @objc private func copyTranscript(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        Paster.copy(text)
    }

    @objc private func retryFailedRecording() {
        if let clip = failedRecordings.latest { retry(clip) }
    }

    /// Transcribes a kept clip again, unless a dictation is under way: a second retry of the same clip would find
    /// it gone once the first succeeds.
    private func retry(_ clip: URL) {
        guard !recorder.isRecording, !isTranscribing else { return }
        do {
            transcribe(clip, seconds: try Transcriber.seconds(of: clip), isRetry: true)
        } catch {
            fail("Can't read the kept recording: \(error.localizedDescription)")
        }
    }

    @objc private func showWindow() {
        mainWindow.show()
    }

    @objc private func showSettings() {
        mainWindow.show(.settings)
    }

    @objc private func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
