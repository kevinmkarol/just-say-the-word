#!/bin/zsh
# ABOUTME: Builds Just Say the Word, copies it to /Applications and (re)starts it there. Re-run after a code change.
# ABOUTME: Ad hoc signed, every rebuild needs the TCC grants again; a signing certificate (see build.sh) keeps them.
set -euo pipefail
here=${0:A:h}
bundle=studio.crossedwires.justsaytheword
name="Just Say the Word"
built=$here/build/$name.app
app=/Applications/$name.app

# Rebuild only when a source changed since the last build: every new ad hoc build is a new identity
# to TCC, so an unchanged build keeps the Accessibility and Microphone grants.
if [[ ! -x $built/Contents/MacOS/JustSayTheWord ]] \
   || [[ -n $(find $here/Sources $here/Info.plist $here/AppIcon.icns $here/Package.swift $here/JustSayTheWord.entitlements \
               $here/whisper-cli.sh $here/models -newer $built/Contents/MacOS/JustSayTheWord) ]]; then
  $here/build.sh
else
  echo "build/$name.app is up to date"
fi

pkill -x JustSayTheWord 2>/dev/null || true
for _ in {1..20}; do pgrep -xq JustSayTheWord || break; sleep 0.5; done
# The seal lists everything in the bundle but the app's own executable.
same() { cmp -s $built/Contents/$1 $app/Contents/$1 }
if ! same MacOS/JustSayTheWord || ! same _CodeSignature/CodeResources; then
  rm -rf $app
  cp -Rc $built $app   # APFS clone: the models take no extra space
  if [[ $(codesign -dv $app 2>&1) == *Signature=adhoc* ]]; then
    # An ad hoc build is a new identity to TCC. Its previous Accessibility entry would still show as enabled in
    # System Settings without applying to this build, so remove it and let macOS ask afresh.
    tccutil reset Accessibility $bundle >/dev/null
    echo "installed $app (ad hoc signed: grant Accessibility + Microphone again when asked)"
  else
    echo "installed $app"
  fi
fi
# In the background: an install should not put the window in front of whatever is being worked on.
open -g $app --args --background
sleep 1
if pgrep -xq JustSayTheWord; then
  echo "$name is running: look for its icon in the menu bar, or open it from Applications for its window."
else
  echo "$name did not start; see ~/Library/Logs/$name.log" >&2
  exit 1
fi
