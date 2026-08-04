# PRD — Cura della user experience e finestra unica

Stato: bozza approvata da discutere per sezione · Ambito: pre-1.0 → 1.0
Vincolo fondante: **nessuna nuova funzionalità**. Si rifinisce ciò che esiste;
ogni capability nuova (speed test, Wake-on-LAN, sparkline traffico, notifiche
nuovo dispositivo) è fuori ambito e vive nella roadmap post-1.0.

## 1. Problema

IliadBar 0.9 è funzionalmente completa ma frammentata e poco curata nelle
interazioni:

- **Quattro finestre separate** (Download, File, Rete, Servizi), ognuna con il
  proprio sidebar e la propria toolbar. L'utente che gestisce la box salta tra
  finestre che si sovrappongono, ognuna con navigazione propria. La stessa
  entità (un download completato, un file, un dispositivo) non ha un percorso
  continuo tra le viste.
- **Le azioni non danno feedback fuori dal pannello**: un errore nato in una
  finestra muore nella `statusLine` del pannello menu bar.
- Incoerenze visive (due sistemi colore), vocabolario API che affiora nella UI,
  controlli che sembrano interattivi ma non lo sono, dati finti (meter tab File).

## 2. Architettura delle superfici (decisione portante)

Da quattro finestre a **due sole superfici**:

1. **Pannello menu bar** — il glance: stato connessione, download in corso,
   azioni rapide. Resta com'è nella struttura (tab leggere), viene rifinito.
2. **Finestra principale unica** — la gestione completa: una sola finestra con
   un solo sidebar e area di dettaglio, che assorbe le attuali quattro.

Struttura del sidebar unificato:

```
IliadBar (finestra unica)
├─ Home
├─ Download
├─ File
├─ RETE
│  ├─ Dispositivi
│  ├─ Wi-Fi
│  └─ DHCP
└─ SERVIZI
   ├─ Porte e NAT
   ├─ Condivisione
   ├─ Controllo parentale
   ├─ Chiamate e contatti
   └─ VPN e TV
```

**Home** è la sezione di atterraggio: l'apertura generica della finestra parte
da qui. Aggrega solo dati già esistenti — stato connessione e traffico live,
download attivi in sintesi, storage in sintesi, box attiva e **stato dei
permessi** (è il "punto unico" del requisito §3) — e ogni blocco porta alla
propria sezione. Non introduce capability nuove: dà una casa nella finestra al
quadro d'insieme che oggi vive solo nel pannello.

Requisiti:

- Ogni voce di sidebar mantiene la propria toolbar contestuale (ordina/aggiungi/
  aggiorna) nell'area di dettaglio.
- Il pannello e le scorciatoie aprono la finestra **sulla sezione giusta**
  ("Apri download manager" → finestra su Download). ⌘1…⌘4 diventano navigazione
  di sezione dentro la finestra, non apertura di finestre diverse.
- Navigazione tra entità senza cambiare finestra: doppio click su un download
  completato → sezione File nella sua cartella.
- L'app resta agente di menu bar (`LSUIElement`): quando la finestra principale
  è aperta l'app diventa temporaneamente `regular` (icona in Dock, ⌘-Tab), e
  torna `accessory` alla chiusura. Senza questo una finestra grande senza Dock
  è un corpo estraneo su macOS.
- Impostazioni resta la finestra Settings nativa macOS (convenzione di
  piattaforma, non frammentazione).
- Stato preservato: dimensione e posizione della finestra ricordate da macOS.
  La sezione non viene ricordata: l'apertura generica atterra su Home, mentre
  le azioni mirate (pannello, scorciatoie) impostano la sezione prima di
  mostrare la finestra.

## 3. Requisiti trasversali (fondamenta)

- **Feedback delle azioni**: ogni azione utente produce esito visibile nel
  contesto in cui è avvenuta — banner/toast transiente nella finestra, non solo
  `statusLine` del pannello. Errori con messaggio umano, successi silenziosi o
  discreti. Un solo componente condiviso.
- **DesignSystem unico**: palette (rosso iliad, colori di stato), tipografia e
  spaziature in un solo file; pannello, finestra e widget consumano quello.
  Audit dark/light dei colori RGB fissi.
- **Vocabolario**: nessuna stringa API cruda visibile (stati, priorità, band,
  encryption). Tutto passa dal layer di presentazione (`Presentation.swift`,
  da estendere dove serve).
- **Onestà dei controlli**: niente elementi che sembrano interattivi e non lo
  sono. Le card servizi (SMB/FTP/UPnP) si dichiarano in sola lettura; i dati
  finti si correggono (meter tab File → riempimento storage reale) o si tolgono.
- **Copy pass IT/EN**: via il developer-speak, tono coerente, entrambe le
  tabelle aggiornate insieme (regola già in DEVELOPMENT.md).

## 4. Requisiti per superficie

### Pannello menu bar
- Pairing curato: box scoperta mostrata (nome/IP) prima dell'associazione,
  stato esplicito durante l'attesa della conferma fisica, errori inline.
- Permessi mancanti raccontati in un punto solo (riepilogo stato permessi),
  non lucchetti sparsi.
- Right-click sull'icona menu bar = menu contestuale standard (apri finestra,
  aggiungi dagli appunti, impostazioni, esci); left-click = pannello.

### Sezione Download
- Doppio click su task completato → sezione File nella cartella del task.
- Vista blocchi come griglia renderizzata, non stringa monospace.
- Empty state e dettagli allineati al design system.

### Sezione File
- Breadcrumb cliccabili (oggi testo inerte).
- `Table` con colonne Nome / Dimensione / Data ordinabili al posto della lista.
- Upload lineare: un solo "Carica…"; la policy di conflitto viene chiesta solo
  quando il conflitto si verifica.
- Drag & drop dal Finder per upload; drag di `.torrent` sulla sezione Download.
  (Confermato in ambito: è il modo macOS di fare ciò che l'app già fa.)

### Sezione Rete
- DHCP e NAT: picker del dispositivo dalla lista LAN con IP/MAC precompilati,
  invece della digitazione manuale.
- Wi-Fi: help text riscritti per umani.

### Sezione Servizi
- Griglia parentale con asse orario visibile e drag per dipingere più fasce.
- Card servizi esplicitamente read-only.

### Widget
- `widgetURL`: il tap apre l'app (oggi non fa nulla).

## 5. Fuori ambito (v-next, non in questo PRD)

Speed test box-vs-Mac, sparkline traffico, notifica nuovo dispositivo,
Wake-on-LAN, verifica porta esterna, riavvio box, Quick Look remoto.

## 6. Piano di esecuzione (passate)

Ogni passata = serie di commit su `development` con CI verde; una passata
chiude tutti i dettagli della propria area, non ci si torna.

1. ✅ **Fondamenta** — feedback transiente, DesignSystem, presentazione/copy,
   fix dati finti. Prerequisito di tutto.
2. ✅ **Finestra unica** — consolidamento delle quattro finestre, sidebar
   unificato, routing dal pannello, activation policy, stato persistente.
3. ✅ **Pannello e onboarding** — pairing, permessi, right-click.
4. ✅ **Sezione Download** — ponte verso File, griglia blocchi.
5. ✅ **Sezione File** — Table, breadcrumb, upload, drag & drop.
6. ✅ **Rete e Servizi** — picker dispositivi, griglia parentale, read-only
   espliciti.
7. ✅ **Coerenza finale** — audit dark mode, VoiceOver sulle viste toccate,
   widgetURL, Settings riordinate.

Tutte le passate sono implementate e in `development` con CI verde. Resta
aperto un solo criterio di §7: la revisione visiva delle superfici toccate,
che richiede di aprire l'app su un Mac (l'automazione GUI non è disponibile
in questo ambiente di sviluppo).

## 7. Criteri di accettazione globali

- Zero finestre di gestione oltre alla principale (+ Settings nativa).
- Ogni azione utente ha un esito visibile nel proprio contesto.
- Nessuna stringa API cruda o dato finto in UI; IT/EN completi (audit verde).
- Nessun controllo dead-end: tutto ciò che si vede o agisce o si dichiara.
- CI verde (test + audit + smoke) a ogni passata; screenshot prima/dopo per
  ogni superficie toccata come evidenza di revisione.

## 8. Decisioni prese

- Drag & drop: **in ambito** come rifinitura (§4 File). — Ivan, 2026-08-04
- Apertura generica della finestra: **sezione Home** (§2). — Ivan, 2026-08-04
