// ABOUTME: Entry point. `JustSayTheWord --transcribe clip.wav` runs the transcriber alone and prints the text (no permissions
// ABOUTME: needed, handy for checking the model); otherwise this is the app, and `--background` starts it without its window.
import Cocoa
import JustSayTheWordCore

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: "--transcribe"), index + 1 < arguments.count {
    let config = (try? Config.load()) ?? Config()
    do {
        let clip = URL(fileURLWithPath: arguments[index + 1])
        print(try Transcriber().run(clip, config: config, clipSeconds: try Transcriber.seconds(of: clip)))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
delegate.opensWindowAtLaunch = !arguments.contains("--background")
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
