# PRD — Prima esecuzione ed esperienza di prodotto

Stato: approvato, in esecuzione · Ambito: pre-1.0 → 1.0
Vincolo fondante, come per [PRD-UX](PRD-UX.md): **nessuna capability nuova**.
Tutto poggia su ciò che l'app già sa fare; qui si progetta *come* la persona
ci arriva. Speed test, Wake-on-LAN e simili restano fuori.

## 1. Problema

Il primo contatto con IliadBar è indistinguibile da un lancio fallito. L'app è
`LSUIElement`: chi la apre da Applicazioni non vede nessuna finestra, nessuna
icona nel Dock, solo un glifo in più in una menu bar affollata. Sette passate
di cura stanno dietro una porta di cui non diciamo dove sia la maniglia.

Chi supera il primo ostacolo ne trova altri:

- preme "Associa questo Mac" senza sapere che dovrà alzarsi e confermare
  fisicamente sulla box;
- se Bonjour è bloccato (VLAN, VPN, Mac su rete diversa) la via manuale esiste
  ma è sepolta in Impostazioni;
- ad associazione riuscita nessuno dice quali permessi sono stati concessi:
  scoprirà tra mesi che una sezione è grigia per un permesso mai dato;
- widget, CLI `ibx` e handler dei link magnet esistono e non li troverà mai.

Quando qualcosa va storto l'app è corretta ma muta: dice *cosa* è successo, non
*cosa fare*.

## 2. Decisioni portanti

**Al primo avvio IliadBar si comporta come un'app normale.** Apre la finestra
principale in primo piano, con icona nel Dock, e solo a configurazione conclusa
si ritira in menu bar. È l'unico modo di risolvere il "doppio click e non
succede niente"; il modello è quello delle utility di menu bar mature.

**L'onboarding vive nella finestra, non nel pannello.** Il pannello da 380
punti è per il colpo d'occhio quotidiano; la configurazione iniziale merita
spazio, e mostrarla nella finestra insegna che la finestra esiste.

**Si può saltare.** Chi sa cosa sta facendo preme "Salta" e si ritrova nel
prodotto. L'onboarding è ripetibile da Impostazioni, il che serve anche a chi
cambia box e a chi sviluppa.

**Gli stati vuoti insegnano.** Un'area senza contenuti è lo spazio migliore per
spiegare cosa metterci, non per constatare che è vuota.

**Ogni vicolo cieco offre l'uscita.** Dove oggi c'è un lucchetto o un errore,
ci va l'azione che lo risolve.

## 3. Il primo avvio, passo per passo

1. **Benvenuto** — cos'è IliadBar e la promessa che ne è l'identità: i dati
   restano sul Mac, nessun servizio intermedio, nessuna telemetria.
2. **Ricerca** — la scansione Bonjour parte da sola; le box trovate si
   presentano con nome, indirizzo e versione API. Via d'uscita esplicita se non
   compare nulla: inserimento manuale dell'URL, con la spiegazione dei motivi
   tipici (rete diversa, VPN, VLAN).
3. **Associazione** — il passaggio fisico raccontato prima che accada, stato in
   tempo reale durante l'attesa, gestione esplicita di rifiuto e scadenza con
   possibilità di riprovare.
4. **Permessi** — appena il token esiste si mostra cosa è stato concesso e cosa
   no, cosa smette di funzionare senza, un collegamento all'interfaccia web
   della box e un "ricontrolla" che rilegge senza riassociare.
5. **Fatto** — si atterra nella Home con il traffico in movimento (la prova che
   funziona) dopo aver mostrato le tre cose che nessuno scoprirebbe da solo:
   widget, CLI `ibx`, handler dei link magnet. Qui anche avvio al login.

## 4. Momenti di verità (dopo il primo avvio)

- **Box che si riavvia**: "la box si sta riavviando", riconnessione automatica,
  nessun rosso allarmante.
- **Token revocato sulla box**: messaggio chiaro e bottone per riassociare.
- **Permesso mancante**: ogni lucchetto porta con sé l'azione che lo risolve.
- **Nessun download / nessun disco / nessuna regola**: lo stato vuoto spiega i
  modi per popolarlo.
- **Icona in menu bar**: "richiede attenzione" deve distinguersi da "offline".

## 5. Scoperta e identità

- Menu **Aiuto**: risoluzione problemi, matrice compatibilità, "segnala un
  problema" con diagnostica redatta già allegata.
- Finestra **Informazioni**: versione, licenza, repository — vetrina del
  progetto open source.
- **Novità** dopo un aggiornamento.
- **Ripristino** che riporta l'app allo stato iniziale.
- **Notifiche con azione** ("download completato" → "Mostra nei file").
- **Magnet trascinato sull'icona** in menu bar.

## 6. Fuori ambito

Capability nuove di ogni tipo (speed test, Wake-on-LAN, notifica nuovo
dispositivo, riavvio box), rinomina del progetto, distribuzione e marketing:
vivono altrove.

## 7. Piano di esecuzione (passate)

1. **Onboarding** — apertura della finestra al primo avvio, percorso in cinque
   passi, salto e ripetizione, stato persistente.
2. **Momenti di verità** — errori che propongono l'azione, stati vuoti che
   insegnano, icona con stato "richiede attenzione".
3. **Scoperta e identità** — menu Aiuto, Informazioni, novità post-aggiornamento,
   ripristino, notifiche con azione, drop sull'icona.

## 8. Criteri di accettazione

- Un'installazione pulita porta alla prima associazione senza che l'utente
  debba cercare l'icona in menu bar né aprire la documentazione.
- Nessun percorso termina in un vicolo cieco: ogni stato bloccato espone
  l'azione che lo sblocca.
- L'onboarding è saltabile e ripetibile, e non ricompare a chi ha già una box
  configurata (aggiornamento da 0.9).
- Widget, CLI e handler magnet sono presentati almeno una volta.
- CI verde a ogni passata; revisione visiva delle superfici toccate.
