#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
  echo "CODE_SIGN_IDENTITY (Developer ID Application: …) è obbligatoria." >&2
  exit 1
fi
if [[ -z "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  echo "SPARKLE_PUBLIC_KEY è obbligatoria." >&2
  exit 1
fi
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  echo "NOTARY_PROFILE è obbligatorio: una release non notarizzata non è pubblicabile." >&2
  exit 1
fi

./Scripts/audit-localization.sh
swift test
./Scripts/make-app.sh

EXPECTED_APP_GROUP="${DEVELOPMENT_TEAM}.it.ivansposato.iliadbar"
APP_GROUP=$(/usr/libexec/PlistBuddy -c 'Print :IliadBarAppGroup' build/IliadBar.app/Contents/Info.plist)
WIDGET_GROUP=$(/usr/libexec/PlistBuddy -c 'Print :IliadBarAppGroup' build/IliadBar.app/Contents/PlugIns/IliadBarWidget.appex/Contents/Info.plist)
if [[ "$APP_GROUP" != "$EXPECTED_APP_GROUP" || "$WIDGET_GROUP" != "$EXPECTED_APP_GROUP" ]]; then
  echo "App Group non coerente con DEVELOPMENT_TEAM." >&2
  exit 1
fi

VERSION=$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' Sources/IliadboxKit/BuildInfo.swift)
ARCHIVE="build/IliadBar-$VERSION.zip"
rm -f "$ARCHIVE" "$ARCHIVE.sha256"
ditto -c -k --keepParent --sequesterRsrc build/IliadBar.app "$ARCHIVE"

xcrun notarytool submit "$ARCHIVE" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple build/IliadBar.app
rm -f "$ARCHIVE"
ditto -c -k --keepParent --sequesterRsrc build/IliadBar.app "$ARCHIVE"

spctl --assess --type execute --verbose=4 build/IliadBar.app
codesign --verify --deep --strict --verbose=2 build/IliadBar.app
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
echo "Release pronta: $ARCHIVE"
