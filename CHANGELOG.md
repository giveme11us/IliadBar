# Changelog

Il progetto segue [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) e il
versionamento semantico.

## Unreleased

### Added

- Discovery Bonjour, profili multi-box, negoziazione API e token nel file di
  configurazione privato (0600), con migrazione una tantum dal Portachiavi
  legacy.
- Dashboard, download manager, file manager, LAN/DHCP/Wi-Fi e servizi avanzati.
- Widget connessione/download, CLI JSON, diagnostica redatta e localizzazione
  italiana/inglese.
- Icona IliadBar custom, aggiornamenti Sparkle e pipeline di distribuzione.
- Ordinamento dei download; stati e priorità dei task tradotti ovunque tramite
  un layer di presentazione condiviso.
- Notifiche download configurabili per evento (avvio, completamento, errore).
- Scorciatoie da tastiera: ⌫ rimuove nel download manager; ⌘N, ⌫ e Invio nel
  file manager.

### Changed

- Una sola finestra di gestione con sidebar unificato (Home, Download, File,
  Rete, Servizi) al posto delle quattro finestre separate; il pannello e le
  scorciatoie ⌘1-5 la portano sulla sezione richiesta.
- Esito delle azioni mostrato nella finestra in cui l'azione è nata.
- Associazione guidata: le box trovate sulla rete si scelgono dal pannello e
  l'attesa della conferma sulla box è spiegata.
- Menu contestuale con il tasto destro sull'icona nella menu bar.
- Sezione File con tabella ordinabile, briciole cliccabili, un solo comando di
  caricamento e trascinamento dal Finder; i download portano alla loro cartella.
- Pianificazione parentale con asse delle ore e selezione a trascinamento;
  prenotazioni DHCP e regole NAT scelgono un dispositivo dalla rete.
- Palette adattiva a tema chiaro e scuro, condivisa da app e widget; i widget
  aprono l'app sulla sezione corrispondente.
