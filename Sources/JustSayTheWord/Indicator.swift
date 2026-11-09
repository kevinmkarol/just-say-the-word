// ABOUTME: The floating pill at the bottom of the screen: level bars while recording, a spinner while transcribing,
// ABOUTME: and a brief note when nothing was heard or something failed. It never takes focus or mouse clicks.
import Cocoa
import JustSayTheWordCore
import SwiftUI

@Observable
final class IndicatorModel {
    enum Phase: Equatable {
        /// `hint` says how to finish a hands-free recording; a held recording needs none.
        case recording(hint: String?)
        case transcribing
        case message(String, isProblem: Bool)
    }

    var phase: Phase = .transcribing
    var meter = LevelMeter()
    /// The transcript will be followed by Return in the app that has focus.
    var pressesReturn = false
}

final class Indicator {
    var isEnabled = true {
        didSet { if !isEnabled { hide() } }
    }

    private let model = IndicatorModel()
    private let panel: NSPanel
    private var hideTimer: Timer?

    init() {
        panel = Self.makePanel(showing: model)
    }

    private var isShowingRecording: Bool {
        if case .recording = model.phase { return panel.isVisible }
        return false
    }

    func showRecording(hint: String?, pressesReturn: Bool) {
        if !isShowingRecording { model.meter.reset() }
        model.pressesReturn = pressesReturn
        show(.recording(hint: hint))
    }

    func showTranscribing(pressesReturn: Bool) {
        model.pressesReturn = pressesReturn
        show(.transcribing)
    }

    /// Shows a note for a few seconds, then hides.
    func flash(_ message: String, isProblem: Bool, seconds: Double) {
        show(.message(message, isProblem: isProblem))
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.hide() }
    }

    func push(peak: Float) {
        model.meter.push(peak: peak)
    }

    func hide() {
        hideTimer?.invalidate()
        panel.orderOut(nil)
    }

    private func show(_ phase: IndicatorModel.Phase) {
        hideTimer?.invalidate()
        guard isEnabled else { return }
        model.phase = phase
        if !panel.isVisible { placeOnFocusedScreen() }
        panel.orderFrontRegardless()
    }

    /// Bottom center of the screen that has the focused window, clear of the Dock.
    private func placeOnFocusedScreen() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 24
        ))
    }

    private static func makePanel(showing model: IndicatorModel) -> NSPanel {
        // Wider than the pill ever gets and transparent, so the pill can change width without the window moving.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: IndicatorView(model: model))
        return panel
    }
}

struct IndicatorView: View {
    let model: IndicatorModel

    var body: some View {
        HStack(spacing: 10) {
            switch model.phase {
            case .recording(let hint):
                Image(nsImage: StatusIcon.mark()).renderingMode(.template)
                    .foregroundStyle(Color(nsColor: StatusIcon.liveColor))
                LevelBars(heights: model.meter.bars)
                if let hint { Text(hint).foregroundStyle(.white.opacity(0.7)) }
                if model.pressesReturn { ReturnBadge() }
            case .transcribing:
                Spinner()
                Text("Transcribing")
                if model.pressesReturn { ReturnBadge() }
            case .message(let text, let isProblem):
                Image(systemName: isProblem ? "exclamationmark.triangle.fill" : "mic.slash")
                    .foregroundStyle(isProblem ? .yellow : .white.opacity(0.7))
                Text(text).lineLimit(1).truncationMode(.tail)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 36)
        .background(.black.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15)))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Marks a dictation that will be submitted with Return, not just pasted.
private struct ReturnBadge: View {
    var body: some View {
        Image(systemName: "return")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white.opacity(0.7))
    }
}

/// A turning arc, drawn here so it is white on the dark pill whatever the system appearance.
private struct Spinner: View {
    @State private var isTurning = false

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(isTurning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isTurning)
            .onAppear { isTurning = true }
    }
}

private struct LevelBars: View {
    let heights: [Float]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .frame(width: 3, height: 4 + 18 * CGFloat(heights[index]))
            }
        }
        .frame(height: 22)
        .animation(.linear(duration: 0.08), value: heights)
    }
}
