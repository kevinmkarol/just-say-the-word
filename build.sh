#!/bin/zsh
# ABOUTME: Builds "Just Say the Word.app" (release) into build/ with whisper-cli and the models inside, and signs it. Ad hoc by
# ABOUTME: default; a certificate named in JUST_SAY_THE_WORD_SIGN_IDENTITY or ~/.config/just-say-the-word/signing-identity keeps TCC grants.
set -euo pipefail
cd ${0:A:h}
models=(ggml-medium.bin ggml-silero-v5.1.2.bin)
for model in $models; do
  if [[ ! -s models/$model ]]; then
    echo "models/$model is missing: run ./setup.sh" >&2
    exit 1
  fi
done
# The SHA-256 Hugging Face publishes for each model, so the app is built with exactly those files.
if ! (cd models && shasum -a 256 -c - <<'SUMS'
6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208  ggml-medium.bin
29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf  ggml-silero-v5.1.2.bin
SUMS
); then
  echo "a model in models/ is not the file it should be: delete it and run ./setup.sh" >&2
  exit 1
fi
swift build -c release --product JustSayTheWord
app="build/Just Say the Word.app"
rm -rf $app
trap 'rm -rf $app' ZERR   # a failed build leaves no half-made app for install.sh to copy
mkdir -p $app/Contents/MacOS
cp .build/release/JustSayTheWord $app/Contents/MacOS/JustSayTheWord
./whisper-cli.sh $app/Contents/MacOS/whisper-cli
cp Info.plist $app/Contents/Info.plist
mkdir -p $app/Contents/Resources
cp AppIcon.icns THIRD-PARTY-LICENSES.md $app/Contents/Resources/
for model in $models; do
  cp -c models/$model $app/Contents/Resources/$model   # APFS clone: instant, no extra space
done
# The certificate's name is read from this Mac, never from the repository, so a clone signs ad hoc.
identity=${JUST_SAY_THE_WORD_SIGN_IDENTITY:-$(cat ~/.config/just-say-the-word/signing-identity 2>/dev/null || true)}
# The hardened runtime keeps other code out of the app's process, and so away from its Microphone and
# Accessibility grants. Any arguments go to codesign: release.sh passes --timestamp.
sign=(codesign --force --options runtime --sign "${identity:--}" "$@")
$sign --identifier studio.crossedwires.justsaytheword.whisper-cli $app/Contents/MacOS/whisper-cli
$sign --entitlements JustSayTheWord.entitlements $app
echo "built $app (signed: ${identity:-ad hoc})"
