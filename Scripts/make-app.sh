#!/bin/zsh
# Costruisce MagnetBox.app da zero: SPM non produce bundle .app,
# quindi lo assembliamo a mano (binario + Info.plist + firma ad-hoc).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product MagnetBox

APP="build/MagnetBox.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MagnetBox "$APP/Contents/MacOS/MagnetBox"
cp Scripts/Info.plist "$APP/Contents/Info.plist"

# Firma ad-hoc: basta per girare in locale e per i permessi TCC (rete locale, notifiche)
codesign --force -s - "$APP"

echo "OK: $APP"
echo "Per installarla:  cp -R $APP /Applications/  &&  open /Applications/MagnetBox.app"
