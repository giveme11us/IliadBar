# IliadBar

**Your iliadbox in the macOS menu bar.** 100% native Swift, zero dependencies.

Click a magnet link and it downloads **on your box, not your Mac**. Watch live
download progress, browse the box's files, and keep an eye on your connection —
all from a compact menu bar panel.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

> 🇮🇹 IliadBar parla con l'**iliadbox** di Iliad Italia. Being Freebox-based,
> it should also work with a **Freebox** (Freebox OS API) — reports welcome.

## Features

**⬇️ Downloads**
- Set IliadBar as the system handler for `magnet:` links — one click in the
  browser and the torrent starts on the box
- Live task list: progress, speed, ETA — pause, resume or remove on hover
- Aggregate download percentage right in the menu bar
- Native notifications when a download starts or fails

**📁 Files**
- Browse the box's download folder from the panel
- Copy any file to your Mac's `~/Downloads` with one click
- Open the box's SMB share in Finder

**📊 Box**
- Connection state and public IP
- Live throughput with bandwidth usage bars (down/up)
- Model, firmware, uptime, temperature

**⌨️ `ibx` CLI**
```
ibx pair              # pair with the box (physical confirmation)
ibx add "magnet:..."  # start a download
ibx list              # list download tasks
ibx box               # connection + system stats
ibx ls [path]         # browse the box filesystem
```

## Install (from source)

Requires macOS 14+ and Xcode command line tools.

```sh
git clone https://github.com/giveme11us/IliadBar.git
cd IliadBar
swift build
.build/debug/ibx pair          # go to the box and confirm the pairing request

Scripts/make-app.sh            # builds build/IliadBar.app
cp -R build/IliadBar.app /Applications/
open /Applications/IliadBar.app
```

Then, from the panel: **"Usa IliadBar per i link magnet"** to make it the
system-wide magnet handler.

## How it works

IliadBar speaks the [Freebox OS API](https://dev.freebox.fr/sdk/os/) (v15) that
the iliadbox exposes on the LAN:

- **Pairing**: `login/authorize/` issues a permanent `app_token`, granted by
  physically confirming on the box. Stored with `0600` permissions in
  `~/Library/Application Support/IliadBar/config.json`.
- **Sessions**: each session signs the box's challenge with
  `HMAC-SHA1(app_token, challenge)` (CryptoKit) to obtain a `session_token`.
- **Everything is native**: `URLSession` for HTTP, `Codable` for the API
  envelope, SwiftUI `MenuBarExtra` for the UI. No third-party packages.

### Architecture

| Target | What it is |
|---|---|
| `IliadboxKit` | API client library: auth, downloads, filesystem, system/connection |
| `IliadBar` | SwiftUI menu bar app |
| `ibx` | CLI companion (pairing, scripting, debugging) |

## Roadmap

- [ ] Wi-Fi toggle and guest network
- [ ] Connected LAN devices list
- [ ] Notification when a download completes
- [ ] English localization
- [ ] App icon, screenshots, releases with Sparkle

## License

[MIT](LICENSE)
