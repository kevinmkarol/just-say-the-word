// ABOUTME: The menu-bar image: the app's mark (a sound wave in a rounded square) drawn for what the app is doing, in
// ABOUTME: color while the microphone is live, with a small Return mark beside it while dictations are submitted.
import Cocoa

enum StatusIcon {
    /// What the icon says the app is doing.
    enum State {
        case ready, unavailable, recording, transcribing, problem
    }

    /// The color of the mark wherever it shows the microphone is live: orange, as macOS marks a microphone in use.
    static let liveColor = NSColor.systemOrange

    static func image(_ state: State, returnBadge: Bool) -> NSImage? {
        let plain: NSImage?
        switch state {
        case .ready, .recording: plain = mark()
        case .unavailable: plain = struckOut(mark())
        case .transcribing: plain = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        case .problem: plain = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
        }
        guard let plain else { return nil }
        let isLive = state == .recording
        let shape = returnBadge ? marked(plain) : plain
        // A template image takes the menu bar's own color; the live one keeps its own.
        let image = isLive ? filled(shape, with: liveColor) : shape
        image.isTemplate = !isLive
        image.accessibilityDescription = AppInfo.name + (isLive ? ", recording" : "")
            + (returnBadge ? ", pressing Return after pasting" : "")
        return image
    }

    /// The heights of the mark's six bars, left to right, on its 17-point grid.
    private static let barHeights: [CGFloat] = [3, 6, 9, 5, 7, 3]

    /// The app's mark as a template image `side` points square. It is laid out on a 17-point grid, one point to
    /// each line and each gap, so that at that size every vertical edge falls on a whole pixel.
    static func mark(side: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            NSGraphicsContext.current?.cgContext.scaleBy(x: side / 17, y: side / 17)
            NSColor.black.set()
            let outline = NSBezierPath(roundedRect: NSRect(x: 0.5, y: 0.5, width: 16, height: 16), xRadius: 1.5, yRadius: 1.5)
            outline.lineWidth = 1
            outline.stroke()
            for (index, height) in barHeights.enumerated() {
                let bar = NSRect(x: 3 + 2 * CGFloat(index), y: (17 - height) / 2, width: 1, height: height)
                NSBezierPath(roundedRect: bar, xRadius: 0.5, yRadius: 0.5).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The shape with a line struck through it from corner to corner, and a little of the shape cleared along the
    /// line so the line stands out.
    private static func struckOut(_ shape: NSImage) -> NSImage {
        NSImage(size: shape.size, flipped: false) { rect in
            shape.draw(in: rect)
            let line = NSBezierPath()
            line.move(to: NSPoint(x: rect.minX + 1, y: rect.maxY - 1))
            line.line(to: NSPoint(x: rect.maxX - 1, y: rect.minY + 1))
            line.lineCapStyle = .round
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            line.lineWidth = 3.5
            line.stroke()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            line.lineWidth = 1.25
            line.stroke()
            return true
        }
    }

    /// The shape with a Return mark to its lower right.
    private static func marked(_ shape: NSImage) -> NSImage {
        let mark = NSImage(systemSymbolName: "return", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 6, weight: .black))
        guard let mark else { return shape }
        let size = NSSize(width: shape.size.width + 1 + mark.size.width, height: shape.size.height)
        return NSImage(size: size, flipped: false) { _ in
            shape.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            mark.draw(at: NSPoint(x: size.width - mark.size.width, y: 0), from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
    }

    private static func filled(_ shape: NSImage, with color: NSColor) -> NSImage {
        NSImage(size: shape.size, flipped: false) { rect in
            shape.draw(in: rect)
            color.set()
            rect.fill(using: .sourceIn)
            return true
        }
    }
}
