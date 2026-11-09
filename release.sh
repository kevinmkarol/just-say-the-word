#!/bin/zsh
# ABOUTME: Makes the download for a release: builds the app signed with a Developer ID certificate, has Apple notarize it,
# ABOUTME: and wraps it in a notarized disk image in build/. Needs a notarytool keychain profile named "notary".
set -euo pipefail
cd ${0:A:h}
name="Just Say the Word"
app=build/$name.app
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
dmg=build/Just-Say-the-Word-$version.dmg

notarize() {
  xcrun notarytool submit $1 --keychain-profile notary --wait
}

./build.sh --timestamp   # notarization asks for a secure timestamp
identity=$(codesign -dvv $app 2>&1 | sed -n 's/^Authority=\(Developer ID Application.*\)/\1/p')
if [[ -z $identity ]]; then
  echo "a release needs a Developer ID Application certificate (docs/development.md, Signing)" >&2
  exit 1
fi

# The app is notarized on its own first, so the ticket can be stapled to it: it then opens on a Mac that is offline.
ditto -c -k --keepParent $app build/app.zip
notarize build/app.zip
rm build/app.zip
xcrun stapler staple $app

staging=$(mktemp -d)
cp -Rc $app $staging/
ln -s /Applications $staging/Applications
rm -f $dmg
hdiutil create -quiet -volname $name -srcfolder $staging -format UDZO $dmg
rm -rf $staging
codesign --sign $identity --timestamp $dmg
notarize $dmg
xcrun stapler staple $dmg
spctl --assess --type open --context context:primary-signature --verbose $dmg
echo "release: $dmg"
