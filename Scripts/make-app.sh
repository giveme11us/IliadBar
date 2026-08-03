#!/bin/zsh
# Costruisce IliadBar.app da zero: SPM non produce bundle .app,
# quindi lo assembliamo a mano (binario + Info.plist + firma ad-hoc).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product IliadBar
swift build -c release --product ibx
swift build -c release --product IliadBarWidget

VERSION=$(sed -n 's/.*static let version = "\([^"]*\)".*/\1/p' Sources/IliadboxKit/BuildInfo.swift)
if [[ -z "$VERSION" ]]; then
  echo "Errore: versione non trovata in BuildInfo.swift" >&2
  exit 1
fi

APP="build/IliadBar.app"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
APP_GROUP="group.it.ivansposato.iliadbar"
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
    echo "Errore: DEVELOPMENT_TEAM è obbligatorio per una build Developer ID." >&2
    exit 1
  fi
  if [[ -z "${SPARKLE_PUBLIC_KEY:-}" ]]; then
    echo "Errore: SPARKLE_PUBLIC_KEY è obbligatoria per una build Developer ID." >&2
    exit 1
  fi
  APP_GROUP="${DEVELOPMENT_TEAM}.it.ivansposato.iliadbar"
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks" "$APP/Contents/PlugIns/IliadBarWidget.appex/Contents/MacOS" "$APP/Contents/PlugIns/IliadBarWidget.appex/Contents/Resources"
cp .build/release/IliadBar "$APP/Contents/MacOS/IliadBar"
cp .build/release/ibx "$APP/Contents/MacOS/ibx"
cp .build/release/IliadBarWidget "$APP/Contents/PlugIns/IliadBarWidget.appex/Contents/MacOS/IliadBarWidget"
if ! otool -l "$APP/Contents/MacOS/IliadBar" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/IliadBar"
fi
sed -e "s/__ILIADBAR_VERSION__/$VERSION/g" -e "s/__ILIADBAR_APP_GROUP__/$APP_GROUP/g" Scripts/Info.plist > "$APP/Contents/Info.plist"
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$APP/Contents/Info.plist"
fi
sed -e "s/__ILIADBAR_VERSION__/$VERSION/g" -e "s/__ILIADBAR_APP_GROUP__/$APP_GROUP/g" Scripts/WidgetInfo.plist > "$APP/Contents/PlugIns/IliadBarWidget.appex/Contents/Info.plist"
sed "s/__ILIADBAR_APP_GROUP__/$APP_GROUP/g" Scripts/IliadBar.entitlements > build/IliadBar.generated.entitlements
sed "s/__ILIADBAR_APP_GROUP__/$APP_GROUP/g" Scripts/Widget.entitlements > build/Widget.generated.entitlements

# Genera l'icona multi-risoluzione dalla sorgente unica versionata.
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
  sips -z "$SIZE" "$SIZE" Resources/AppIcon-1024.png --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
  DOUBLE=$((SIZE * 2))
  sips -z "$DOUBLE" "$DOUBLE" Resources/AppIcon-1024.png --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/Localization/en.lproj Resources/Localization/it.lproj "$APP/Contents/Resources/"
cp -R Resources/Localization/en.lproj Resources/Localization/it.lproj "$APP/Contents/PlugIns/IliadBarWidget.appex/Contents/Resources/"

SPARKLE_FRAMEWORK=$(find .build/artifacts -path '*/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework' -print -quit)
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "Errore: Sparkle.framework non trovato. Esegui 'swift package resolve'." >&2
  exit 1
fi
ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"

# Firma il tool annidato con un identificatore stabile, poi il bundle.
SIGN_OPTIONS=()
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_OPTIONS=(--options runtime --timestamp)
fi
SPARKLE_VERSION="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" "$SPARKLE_VERSION/XPCServices/Installer.xpc"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" --preserve-metadata=entitlements "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" "$SPARKLE_VERSION/Autoupdate"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" "$SPARKLE_VERSION/Updater.app"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" --identifier it.ivansposato.iliadbar.ibx "$APP/Contents/MacOS/ibx"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" --entitlements build/Widget.generated.entitlements "$APP/Contents/PlugIns/IliadBarWidget.appex"
codesign --force -s "$SIGN_IDENTITY" "${SIGN_OPTIONS[@]}" --entitlements build/IliadBar.generated.entitlements "$APP"

echo "OK: $APP"
echo "Per installarla:  cp -R $APP /Applications/  &&  open /Applications/IliadBar.app"
