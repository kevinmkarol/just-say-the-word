# Building and changing the app

Transcription is [whisper.cpp](https://github.com/ggml-org/whisper.cpp)'s `whisper-cli` with the
Whisper Medium model, both inside the app's bundle. `Sources/JustSayTheWordCore` holds the logic
and `swift test` covers it; `Sources/JustSayTheWord` is the AppKit and SwiftUI shell.

Building needs [Xcode](https://apps.apple.com/app/xcode/id497799835) and
[Homebrew](https://brew.sh).

```bash
./setup.sh     # installs cmake, fetches the models into models/, then runs install.sh
./install.sh   # after a code change: builds, copies to /Applications, restarts the app
swift test
swift make-icon.swift   # rebuilds AppIcon.icns from dock_icon.png

tail -f ~/Library/Logs/"Just Say the Word.log"
"build/Just Say the Word.app/Contents/MacOS/JustSayTheWord" --transcribe clip.wav   # the transcriber alone
```

`setup.sh` skips every step that is already done. `build.sh` checks the models against the SHA-256
Hugging Face publishes before every build. `whisper-cli.sh` builds `whisper-cli` from whisper.cpp's
source at a pinned version, as one binary that needs nothing beyond macOS; to rebuild it after
changing the script, delete `build/whisper.cpp-*`.

## Signing

`build.sh` signs ad hoc by default, which makes every rebuild a new app to macOS: grant
Accessibility and Microphone again after each `install.sh`. To keep the grants, put the name of
a code-signing certificate from your keychain (a Developer ID, or a self-signed one made in
Keychain Access) in `~/.config/just-say-the-word/signing-identity`, or pass it as
`JUST_SAY_THE_WORD_SIGN_IDENTITY`. If Accessibility looks enabled but the hotkey never starts,
run `tccutil reset Accessibility studio.crossedwires.justsaytheword` and grant it again.

## Releasing

`release.sh` makes the download: the app signed with a Developer ID certificate and notarized by
Apple, in a notarized disk image. It needs the certificate's name in `signing-identity` (above)
and an app-specific password for notarization, stored once in the keychain:

```bash
xcrun notarytool store-credentials notary --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
```

Set the version in `Info.plist`, then, with that version in place of `X.Y.Z`:

```bash
./release.sh
gh release create vX.Y.Z build/Just-Say-the-Word-X.Y.Z.dmg --title "Just Say the Word X.Y.Z" --notes-file notes.md
```

## How it behaves

- Pressing another key while holding the hotkey cancels the recording: that was a shortcut, not
  dictation. The hotkey tap only listens, so shortcuts still reach their apps.
- Each dictation runs a fresh `whisper-cli`, which loads the model (about 0.8 s) and frees its
  memory afterwards. A 20 s clip takes about 3 s end to end.
- Silence pastes nothing. A retry of a failed recording copies the transcript without pasting it.
- While **Press Return after pasting** is on, the menu-bar icon carries a small ⏎, and so does
  the bar at the bottom of the screen when the app in front is one Return will be pressed in.
