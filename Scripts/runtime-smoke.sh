#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
APP_BIN="${1:-build/IliadBar.app/Contents/MacOS/IliadBar}"
if [[ ! -x "$APP_BIN" ]]; then
  echo "Binario IliadBar non trovato: $APP_BIN" >&2
  exit 1
fi

SMOKE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/iliadbar-runtime-smoke.XXXXXX")
APP_PID=""
SERVER_PID=""
UPGRADE_ID="ci-legacy-upgrade-$$"
REVOKED_ID="ci-revoked-token-$$"
cleanup() {
  [[ -z "$APP_PID" ]] || kill "$APP_PID" 2>/dev/null || true
  [[ -z "$SERVER_PID" ]] || kill "$SERVER_PID" 2>/dev/null || true
  if [[ "${KEEP_SMOKE_ROOT:-0}" == "1" ]]; then
    echo "Ambiente smoke conservato: $SMOKE_ROOT" >&2
  else
    rm -rf "$SMOKE_ROOT"
  fi
}
trap cleanup EXIT INT TERM

run_app() {
  local scenario="$1"
  local config_directory="$2"
  mkdir -p "$config_directory"
  ILIADBAR_CONFIG_DIRECTORY="$config_directory" "$APP_BIN" \
    >"$SMOKE_ROOT/$scenario.stdout" 2>"$SMOKE_ROOT/$scenario.stderr" &
  APP_PID=$!
  sleep 6
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "Scenario runtime non riuscito: $scenario" >&2
    sed -n '1,120p' "$SMOKE_ROOT/$scenario.stderr" >&2
    return 1
  fi
  kill "$APP_PID"
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""
  echo "✓ $scenario"
}

# Installazione pulita: nessuna configurazione e nessuna credenziale.
run_app clean-install "$SMOKE_ROOT/clean-config"

# Upgrade da schema legacy con token: l'app deve restare viva, migrare allo
# schema corrente e conservare il token nel file privato anche se la box è offline.
UPGRADE_DIRECTORY="$SMOKE_ROOT/upgrade-config"
UPGRADE_CONFIG="$UPGRADE_DIRECTORY/config.json"
mkdir -p "$UPGRADE_DIRECTORY"
printf '{"boxID":"%s","baseURL":"http://127.0.0.1:9/api/v15/","appToken":"ci-fake-upgrade-token"}\n' \
  "$UPGRADE_ID" \
  > "$UPGRADE_CONFIG"
run_app upgrade-offline "$UPGRADE_DIRECTORY"
test "$(plutil -extract schemaVersion raw -- "$UPGRADE_CONFIG")" = "3"
grep -q 'ci-fake-upgrade-token' "$UPGRADE_CONFIG"
test "$(stat -f '%Lp' "$UPGRADE_CONFIG")" = "600"

# Due profili salvati con selezione esplicita devono avviarsi senza fallback o
# crash anche quando non sono ancora associati.
MULTIBOX_DIRECTORY="$SMOKE_ROOT/multibox-config"
MULTIBOX_CONFIG="$MULTIBOX_DIRECTORY/config.json"
mkdir -p "$MULTIBOX_DIRECTORY"
printf '%s\n' \
  '{"schemaVersion":3,"activeBoxID":"ci-box-b","boxes":[{"id":"ci-box-a","name":"A","baseURL":"http://127.0.0.1:9/api/v15/"},{"id":"ci-box-b","name":"B","baseURL":"http://127.0.0.1:9/api/v15/"}],"preferences":{"idleRefreshSeconds":20,"activeRefreshSeconds":3,"notificationsEnabled":false}}' \
  > "$MULTIBOX_CONFIG"
run_app multi-box "$MULTIBOX_DIRECTORY"

# Token revocato: il server fixture completa la challenge e rifiuta la sessione;
# IliadBar deve degradare allo stato di autenticazione fallita senza terminare.
REVOKED_DIRECTORY="$SMOKE_ROOT/revoked-config"
REVOKED_CONFIG="$REVOKED_DIRECTORY/config.json"
mkdir -p "$REVOKED_DIRECTORY"
REVOKED_REQUESTS="$SMOKE_ROOT/revoked-token.requests"
REVOKED_PORT_FILE="$SMOKE_ROOT/revoked-token.port"
FIXTURE_LOG="$SMOKE_ROOT/revoked-token.server.log"
/usr/bin/env python3 Scripts/Fixtures/revoked-token-server.py 0 "$REVOKED_REQUESTS" \
  "$REVOKED_PORT_FILE" > "$FIXTURE_LOG" 2>&1 &
SERVER_PID=$!
# Attesa generosa: il cold start di python3 sul runner CI può superare i 5s.
# Se il processo muore prima di scrivere la porta, usciamo subito col suo log.
for _ in {1..300}; do
  [[ -s "$REVOKED_PORT_FILE" ]] && break
  kill -0 "$SERVER_PID" 2>/dev/null || break
  sleep 0.1
done
if [[ ! -s "$REVOKED_PORT_FILE" ]]; then
  echo "Il server fixture del token revocato non si è avviato" >&2
  [[ -s "$FIXTURE_LOG" ]] && cat "$FIXTURE_LOG" >&2
  exit 1
fi
REVOKED_PORT=$(<"$REVOKED_PORT_FILE")
printf '{"boxID":"%s","baseURL":"http://127.0.0.1:%s/api/v15/","appToken":"ci-revoked-token-value"}\n' \
  "$REVOKED_ID" "$REVOKED_PORT" > "$REVOKED_CONFIG"
run_app revoked-token "$REVOKED_DIRECTORY"
grep -q 'GET /api/v15/login/' "$REVOKED_REQUESTS"
grep -q 'POST /api/v15/login/session/' "$REVOKED_REQUESTS"
kill "$SERVER_PID"
wait "$SERVER_PID" 2>/dev/null || true
SERVER_PID=""

echo "Runtime smoke OK"
