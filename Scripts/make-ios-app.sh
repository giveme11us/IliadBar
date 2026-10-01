#!/bin/zsh
# Build dell'app iOS da terminale: rigenera il progetto XcodeGen, compila e
# (con --sim) installa e lancia su un simulatore.
#   ./Scripts/make-ios-app.sh              → build simulator (Debug)
#   ./Scripts/make-ios-app.sh --sim        → build + install + launch
#   ./Scripts/make-ios-app.sh --device     → build per dispositivo fisico
#                                            (serve DEVELOPMENT_TEAM impostato)
# Nota: CoreSimulator a volte non vede i path del repo: l'install passa da
# una copia in una cartella temporanea.
set -euo pipefail
cd "$(dirname "$0")/.."

DESTINATION_SIM="platform=iOS Simulator,name=iPhone 17"
DERIVED="build/ios"

command -v xcodegen >/dev/null || { echo "Errore: xcodegen non installato." >&2; exit 1; }
xcodegen generate

MODE="${1:-}"
if [[ "$MODE" == "--device" ]]; then
  if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
    echo "Errore: DEVELOPMENT_TEAM è obbligatorio per il device." >&2
    exit 1
  fi
  UDID="${DEVICE_UDID:-}"
  DEST="generic/platform=iOS"
  if [[ -n "$UDID" ]]; then DEST="id=$UDID"; fi
  SIGN_ARGS=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" -allowProvisioningUpdates
    -allowProvisioningDeviceRegistration)

  # Primo tentativo con App Group (richiede account a pagamento e il gruppo
  # registrato nel portale). Se il profilo generato non lo include, si ricade
  # sugli entitlements minimi: il widget perde solo lo snapshot condiviso.
  if ! xcodebuild -project IliadBariOS.xcodeproj -scheme IliadBariOS \
    -destination "$DEST" -configuration Debug -derivedDataPath "$DERIVED" \
    "${SIGN_ARGS[@]}" build >/dev/null 2>&1; then
    echo "App Group non disponibile nel profilo: build senza gruppo condiviso." >&2
    xcodebuild -project IliadBariOS.xcodeproj -scheme IliadBariOS \
      -destination "$DEST" -configuration Debug -derivedDataPath "$DERIVED" \
      "${SIGN_ARGS[@]}" \
      CODE_SIGN_ENTITLEMENTS=Sources/IliadBariOS/Support/App-NoGroup.entitlements \
      build
  fi
  echo "OK: $DERIVED/Build/Products/Debug-iphoneos/IliadBariOS.app"
  exit 0
fi

xcodebuild -project IliadBariOS.xcodeproj -scheme IliadBariOS \
  -destination "$DESTINATION_SIM" -configuration Debug \
  -derivedDataPath "$DERIVED" build

APP="$DERIVED/Build/Products/Debug-iphonsimulator/IliadBariOS.app"
echo "OK: $APP"

if [[ "$MODE" == "--sim" ]]; then
  STAGE="$(mktemp -d)/IliadBariOS.app"
  ditto "$APP" "$STAGE"
  xcrun simctl install booted "$STAGE"
  xcrun simctl launch booted it.ivansposato.iliadbar.ios
  echo "Lanciata sul simulatore attivo."
fi
