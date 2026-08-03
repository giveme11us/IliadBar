# Matrice delle capability

IliadBar non deduce il supporto dal nome commerciale della box: prova endpoint
tipizzati, interpreta i permessi di sessione e nasconde o rende read-only ciò
che il firmware non espone.

| Area | Lettura | Mutazioni | Permesso/capability |
|---|---:|---:|---|
| Connessione e sistema | sì | accesso remoto, se supportato | `settings` per le modifiche |
| Download | sì | aggiungi, pausa, riprendi, retry, rimuovi | `downloader` |
| File e dischi | sì | upload streaming, copy/move, share/revoke, delete/cancel | `explorer` |
| LAN | sì | rename dispositivo | `settings` |
| DHCP | config e lease | campi supportati e lease statici | `settings` |
| Wi-Fi | AP, BSS, stazioni | radio/BSS, guest, WPS | endpoint presente + `settings` |
| NAT | regole e range assegnato | crea/aggiorna/elimina | `settings` e porte nel range |
| SMB/FTP/UPnP | sì | sola lettura nella UI 0.9 | endpoint presente |
| Parental control | profili e planning | crea/elimina profili e modifica fasce | `parental` |
| VPN client/server | stato e configurazioni | sola lettura nella UI 0.9 | endpoint presente |
| Chiamate/contatti/PVR | sì | sola lettura nella UI 0.9 | endpoint presente |

Gli eventi LAN usano WebSocket quando la box accetta la registrazione; il
polling configurabile rimane sempre il fallback. Varianti di payload note sono
coperte da fixture, ma un nuovo firmware può richiedere un decoder aggiuntivo.

Una sessione con `settings: false` è deliberatamente sicura e read-only: IliadBar
non tenta di aggirare il permesso.
