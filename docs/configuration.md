# Settings

The Settings section of the app's window edits `~/.config/just-say-the-word/config.json`. The
file is created on first launch and re-read before every recording, so you can also edit it by
hand. Every key is optional.

| key | default | |
| --- | --- | --- |
| `hotkey` | `rightCommand` | `leftCommand`, `rightOption`, `leftOption`, `rightControl`, `leftControl`, `rightShift`, `leftShift`, `fn` |
| `tapTogglesHandsFree` | `true` | a short tap starts a hands-free recording |
| `tapThresholdMs` | `300` | how short a press counts as a tap |
| `maxSeconds` | `600` | recordings stop themselves here; never under `1` |
| `inputDevice` | `""` | part of an input device's name; empty = system default |
| `paste` | `true` | `false` only copies |
| `restoreClipboard` | `false` | put the previous clipboard back 0.6 s after pasting |
| `pressReturn` | `false` | press Return after pasting |
| `pressReturnApps` | `[]` | the apps Return is pressed in, by name or bundle identifier, e.g. `["iTerm2"]`; empty = every app |
| `indicator` | `true` | the bar at the bottom of the screen |
| `sounds` | `true` | |
| `language` | `"en"` | |
| `model` | `""` | the path of any ggml Whisper model; empty = Whisper Medium, built into the app |
| `vadModel` | `""` | the path of a ggml voice detection model; empty = Silero VAD, built into the app |
| `vocabulary` | `~/.config/just-say-the-word/vocabulary.txt` | names for Whisper to spell right, one per line |

If `vadModel` names a file that is not there, the app transcribes without voice detection, and
Whisper then turns silence into "you" or "Thank you."

## Where things are kept

- `~/Library/Application Support/Just Say the Word/history.tsv`: every transcript.
- `~/Library/Application Support/Just Say the Word/Failed Recordings`: the audio of a dictation
  that could not be transcribed, until a retry succeeds.
- `~/Library/Logs/Just Say the Word.log`: what the app did, without the transcripts.
