# Just Say the Word

Dictation for your Mac. Hold a key, say what you want to write, and let go: your words are typed
wherever your cursor is. It all happens on your Mac. Nothing you say is sent over the internet,
and there is no account or subscription.

## What you need

- A Mac with Apple silicon (M1 or newer) running macOS 14 or later.
- About 3 GB of free space while installing. The app itself takes 1.5 GB, most of it the speech
  model, which comes inside it.

## Install

1. Download the `.dmg` file from the
   [latest release](https://github.com/kevinmkarol/just-say-the-word/releases/latest). It is a
   large download, about 1.4 GB.
2. Open it and drag **Just Say the Word** onto the Applications folder.
3. Open **Just Say the Word** from Applications. macOS asks whether to open an app downloaded
   from the internet: choose Open. The app's icon appears in the menu bar.

Once the app is in Applications you can delete the `.dmg` file.

macOS then asks for two permissions. Allow both:

- **Microphone**, so it can hear you.
- **Accessibility**, so it can notice the key and type for you. Until you allow this one, the
  menu-bar icon has a line through it.

## Using it

- **Hold Right ⌘ and talk.** Let go, and a moment later your words appear where the cursor is.
- **Tap Right ⌘** to keep it listening without holding the key. Tap again when you are done, or
  press Esc to throw the recording away.
- While it listens, the menu-bar icon turns orange and a small bar at the bottom of the screen
  moves with your voice.
- What you said is also on the clipboard, so if it landed in the wrong window you can paste it
  again with ⌘V.

Click the menu-bar icon to copy one of your last five dictations again. Open the app from
Applications to see everything you have dictated, change the settings, or check what went wrong.

### Sending a message by voice

Turn on **Press Return after pasting** in Settings, and choose the apps it applies to. In those
apps your words are typed and then sent, as if you had pressed Return yourself.

## Your privacy

The app never connects to the internet. It keeps three things, all on your Mac:

- a list of everything you have dictated, so nothing is lost;
- the audio of a dictation it could not turn into text, until you retry it;
- a log of what it did, which does not include your words.

All three are in `~/Library/Application Support/Just Say the Word` and `~/Library/Logs`. To
forget what you have dictated, delete the files there; the app makes new, empty ones.

## Updating and removing

The app does not check for updates. To update, download the new `.dmg` from the
[latest release](https://github.com/kevinmkarol/just-say-the-word/releases/latest) and drag the
app onto Applications again, replacing the old one. Your settings and history are kept.

To remove the app, quit it and drag it from Applications to the Trash. To remove everything it
kept as well, also delete the folders above and `~/.config/just-say-the-word`.

## Good to know

- Quitting the app (⌘Q) stops dictation. To keep it running, close its window instead (⌘W).
- To start it whenever you log in, turn on **Open at login** in Settings.
- If nothing happens when you hold the key, open Settings in the app and check that both
  permissions say Granted.
- If a dictation fails, the recording is kept. Choose **Retry** in the menu or in History.
- If the icon vanishes while you talk, your menu bar is full: macOS adds its own orange
  microphone while any app records, and that pushes the leftmost icon out of sight. Hold ⌘ and
  drag the app's icon to the right.

## More

- [Every setting](docs/configuration.md), including changing the key and the microphone.
- [Building and changing the app](docs/development.md).
- [MIT license](LICENSE), and the [licenses of what the app contains](THIRD-PARTY-LICENSES.md).
