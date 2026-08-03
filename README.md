# IliadBar

IliadBar porta iliadbox nella barra dei menu di macOS: stato della connessione,
download, file, dispositivi LAN, Wi-Fi e servizi avanzati in un'app nativa e
local-first.

![Platform](https://img.shields.io/badge/macOS-14%2B-111111)
![Swift](https://img.shields.io/badge/Swift-6-F05138)
![License](https://img.shields.io/badge/license-MIT-2ea44f)

> Il progetto usa le API locali di Freebox OS. È pensato per iliadbox e può
> funzionare con gateway Freebox compatibili; le funzionalità visibili dipendono
> da modello, firmware e permessi concessi durante l'associazione.

## Cosa fa

- Dashboard con stato, traffico live, IP pubblico, uptime, temperature e dischi.
- Gestione download completa: magnet, URL, torrent/NZB locali, file, priorità,
  tracker, peer e rimozione sicura.
- File manager multi-disco con upload WebSocket, download, cartelle, rinomina,
  copia, spostamento, condivisione e cancellazione confermata.
- LAN, DHCP e Wi-Fi: dispositivi, lease, radio, SSID, stazioni, WPS e QR ospiti
  quando supportati.
- NAT, accesso remoto, SMB, FTP, UPnP, parental control, VPN, chiamate, contatti
  e PVR dietro capability detection.
- Eventi live con fallback al polling, notifiche configurabili e stati
  offline/stale/permesso negato espliciti.
- Due widget WidgetKit e CLI `ibx` con JSON stabile per automazioni.
- Interfaccia italiana e inglese, scorciatoie da tastiera e diagnostica redatta.

## Installazione da sorgente

Richiede macOS 14 o successivo e Xcode Command Line Tools.

```sh
git clone https://github.com/giveme11us/IliadBar.git
cd IliadBar
swift package resolve
./Scripts/make-app.sh
cp -R build/IliadBar.app /Applications/
open /Applications/IliadBar.app
```

Al primo avvio IliadBar scopre la box tramite Bonjour. L'associazione richiede
una conferma fisica sulla iliadbox. Il token viene salvato nella configurazione
locale privata, leggibile solo dall'utente (`0600`), senza richieste del Portachiavi.

Per usare la CLI inclusa:

```sh
/Applications/IliadBar.app/Contents/MacOS/ibx discover --save
/Applications/IliadBar.app/Contents/MacOS/ibx pair
/Applications/IliadBar.app/Contents/MacOS/ibx status --json
```

Esegui `ibx` senza argomenti per l'elenco completo dei comandi.

## Architettura

| Target | Ruolo |
|---|---|
| `IliadboxKit` | client API tipizzato, autenticazione, discovery e modelli condivisi |
| `IliadBar` | app SwiftUI per la barra dei menu e finestre di gestione |
| `IliadBarWidget` | widget connessione e download, alimentati da snapshot senza segreti |
| `ibx` | CLI per associazione, ispezione e automazione |

La base URL e la versione API vengono negoziate dai metadati Bonjour, con un
fallback manuale. Le sessioni sono firmate localmente; nessun dato della box
viene inviato a un servizio IliadBar.

## Sviluppo e release

```sh
swift test
./Scripts/audit-localization.sh
./Scripts/make-app.sh
```

Consulta [Development](docs/DEVELOPMENT.md), [Security](docs/SECURITY.md),
[Privacy](docs/PRIVACY.md), [Troubleshooting](docs/TROUBLESHOOTING.md) e
[Releasing](docs/RELEASING.md). La [matrice delle capability](docs/CAPABILITIES.md)
documenta le differenze tra firmware. Il percorso verso 1.0 e le prove richieste sono
in [Roadmap](docs/ROADMAP.md).

## Stato del progetto

IliadBar è in sviluppo pre-1.0. Le build locali sono firmate ad-hoc; le release
pubbliche richiedono Developer ID, notarizzazione e firma EdDSA dell'appcast.

## Licenza

[MIT](LICENSE)
