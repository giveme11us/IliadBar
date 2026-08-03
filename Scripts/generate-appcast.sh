#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "SPARKLE_PRIVATE_KEY è obbligatoria e viene letta solo da stdin." >&2
  exit 1
fi
GENERATE_APPCAST=$(find .build/artifacts -path '*/bin/generate_appcast' -print -quit)
if [[ -z "$GENERATE_APPCAST" ]]; then
  echo "generate_appcast non trovato negli artefatti Sparkle." >&2
  exit 1
fi
mkdir -p build/updates
rm -f build/updates/IliadBar-*.zip
if command -v gh >/dev/null && [[ -n "${GH_TOKEN:-}" ]]; then
  gh release download --repo giveme11us/IliadBar \
    --pattern 'IliadBar-*.zip' --pattern appcast.xml \
    --dir build/updates --clobber >/dev/null 2>&1 || true
fi
cp build/IliadBar-*.zip build/updates/
print -rn -- "$SPARKLE_PRIVATE_KEY" | "$GENERATE_APPCAST" \
  --ed-key-file - \
  --download-url-prefix "https://github.com/giveme11us/IliadBar/releases/download/v$(sed -n 's/.*version = "\([^"]*\)".*/\1/p' Sources/IliadboxKit/BuildInfo.swift)/" \
  --link "https://github.com/giveme11us/IliadBar" \
  -o build/updates/appcast.xml \
  build/updates
cp build/updates/appcast.xml appcast.xml
echo "Appcast aggiornato: appcast.xml"
