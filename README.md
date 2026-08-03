# MagnetBox

Client macOS 100% nativo (zero dipendenze) per il download manager della iliadbox:
clicchi un link `magnet:` e il download parte sulla box, non sul Mac.

- **IliadboxKit** — libreria: auth Freebox OS (app_token + HMAC-SHA1 challenge → session_token) e API `downloads/`
- **ibx** — CLI: pairing, status, add/list/rm
- **MagnetBox** — app menu bar, handler dello schema `magnet:`

Stack: URLSession + CryptoKit + SwiftUI. API iliadbox v15 su `http://192.168.1.254`.

## Setup

```sh
swift build                      # compila tutto
.build/debug/ibx pair            # associa il Mac alla box (conferma fisica sulla box)
.build/debug/ibx add "magnet:?xt=urn:btih:..."   # test dal terminale

Scripts/make-app.sh              # costruisce build/MagnetBox.app
cp -R build/MagnetBox.app /Applications/
open /Applications/MagnetBox.app
```

Dal menu di MagnetBox: **"Usa MagnetBox per i link magnet"** per farla diventare
l'handler di sistema. Da lì in poi ogni magnet cliccato nel browser parte sulla box.

## Note

- Il token vive in `~/Library/Application Support/MagnetBox/config.json` (0600).
  Config condivisa tra CLI e app.
- Se il permesso `downloader` non è attivo: iliadbox OS → Impostazioni →
  Gestione accessi → Applicazioni → MagnetBox.
- La cartella di destinazione dei download è quella configurata nell'app
  Download della box (impostala sull'SSD).
