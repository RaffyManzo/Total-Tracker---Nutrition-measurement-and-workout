# Protocollo di validazione su telefono — 0.1.0-07 refinement

Stato iniziale: `PENDING_USER_PHONE_TEST`.

La patch non dichiara risolti freeze, lifecycle Android o vantaggi pub/sub sulla sola base dei test locali. Servono due sessioni diagnostiche separate, eseguite sul branch finale con la stessa build debug o profile.

## Preparazione comune

1. Aprire Android Studio sulla repository finale.
2. Verificare il branch `fix/0.1.0-07-stability-performance-lifecycle-r2` e annotare il commit.
3. Avviare l'app da Android Studio, lasciando che ricostruisca il progetto dopo il `flutter clean` finale del launcher.
4. Aprire la sezione diagnostica, cancellare i log precedenti e avviare una nuova sessione.
5. Usare soltanto dati di prova: nessun nome personale, nota libera, valore corporeo reale, carico o ripetizione reale.
6. Annotare in un file separato: data, ora, modello Android, versione Android, modalità build, commit e risultato percepito. Non inserire il nome dell'utente.
7. Terminare ed esportare ogni sessione prima di iniziare la successiva.

## Log 1 — Stabilità e lifecycle

Eseguire nell'ordine:

1. Chiudere completamente l'app e fare un avvio a freddo.
2. Attendere la dashboard utilizzabile.
3. Aprire una giornata e il dettaglio di un pasto.
4. Aprire il picker ingredienti dalla card `Ingrediente`.
5. Cercare e selezionare un alimento di prova.
6. Comprimere il picker mantenendo la selezione, poi riespanderlo.
7. Ripetere ricerca, selezione, compressione ed espansione per **10 cicli**, senza confermare due volte e senza aprire due picker contemporaneamente.
8. Con una selezione attiva, eseguire il back/pop: il picker deve restare compresso e la selezione deve restare disponibile; quindi chiuderlo esplicitamente.
9. Aprire la creazione di un dispositivo di misurazione, compilare parzialmente e tornare indietro.
10. Ripetere apertura, compilazione parziale e back per **5 cicli**; al quinto ciclo riaprire e completare il salvataggio.
11. Eliminare una misurazione di prova e verificare che dialog, overlay e schermata si chiudano correttamente.
12. Dalla dashboard eseguire il doppio back previsto dall'app.
13. Riavviare l'app se il doppio back l'ha chiusa, poi eseguire **10 cicli background/resume**. Includere almeno un ciclo con il picker aperto e uno con un dialog aperto.
14. In uno dei cicli lasciare l'app in background per almeno **30 secondi**.
15. Riaprire l'app dal task manager Android.
16. Tornare alla dashboard e verificare che dati, overlay e navigazione siano coerenti.
17. Chiudere l'app e terminare la sessione diagnostica.

Controllare nel log:

- stati `inactive`, `paused`, `resumed`, `detached` distinti e `hidden` quando emesso dalla versione Flutter/Android;
- transizioni duplicate coalesciate;
- timestamp di background non sovrascritto;
- massimo un `lifecycle.resume.started` e un `lifecycle.resume.completed` per generazione;
- una sola pipeline di riconciliazione attiva; gli eventuali pass coalesciati devono essere seriali e contati;
- conteggi reali di subscriber e coda, senza contatori fissi per timer/overlay;
- assenza di `setState() after dispose`, controller usato dopo dispose, `No Scaffold widget found`, GlobalKey duplicate, build scope errato, assertion o dialog residui;
- assenza di bootstrap, listener, reminder, seed o job duplicati.

Nome file consigliato:

`DEVICE_LOG_1_STABILITY_LIFECYCLE_YYYYMMDD.txt`

## Log 2 — Prestazioni, pub/sub e transfer

Avviare una nuova sessione diagnostica e svolgere nell'ordine:

1. Avvio a freddo e attesa della dashboard utilizzabile.
2. Eseguire **10 aggiunte alimento** complete, usando operationId separati.
3. Distribuire le aggiunte su **3 pasti**.
4. Modificare la quantità di una voce.
5. Rimuovere una voce.
6. Tornare alla dashboard.
7. Aprire e scorrere **4 settimane** differenti.
8. Aprire la schermata insight.
9. Eseguire una ricerca locale.
10. Eseguire una ricerca esterna.
11. Aprire una pagina ingrediente.
12. Esportare un archivio `.totaltracker` di prova.
13. Importare in modo controllato lo stesso archivio o una copia nota, verificando analisi, conflitti e risultato. Non usare dati reali.
14. Aprire la sezione misurazioni ed eseguire una lettura/azione di prova non sensibile.
15. Tornare alla dashboard, attendere la stabilizzazione e terminare la sessione.

Per ogni operazione rilevante correlare, quando presenti:

`operationId → eventId → DB write → publish → queue wait → coalescenza → subscriber → invalidazione → target/TDEE → UI refresh → loading → completamento percepito`.

Raccogliere e confrontare:

- durata totale e timestamp di inizio/fine;
- tempo scrittura DB, publish, attesa coda, ricalcolo, observed TDEE e refresh UI;
- `subscriberCount`, `publishedEvents`, `queueDepth`, callback in corso/completate/scartate e `coalescedEventCount`;
- richieste/esecuzioni ricalcolo e richieste/esecuzioni refresh UI;
- eventi loading oltre 200 ms e durata visibile minima;
- eventi export/import, conflitti, rifiuto corruzione e rollback quando esercitati;
- frame bloccati percepiti, errori Flutter e assertion.

Non dedurre un miglioramento p50/p95 da una sola sessione. Il confronto con la baseline deve usare la stessa sequenza, dispositivo e modalità build.

Nome file consigliato:

`DEVICE_LOG_2_PERFORMANCE_PUBSUB_TRANSFER_YYYYMMDD.txt`

## Esportazione e consegna

1. Terminare la sessione dalla sezione diagnostica.
2. Usare l'azione di esportazione log dell'app.
3. Verificare che il file non contenga dati personali, note, query reali, percorsi completi, valori corporei, carichi o ripetizioni.
4. Allegare i due file separati e una nota sintetica con esito di ogni ciclo, commit, dispositivo e modalità build.

Fino alla verifica dei due log mantenere:

- `FREEZE_ADD_FOOD=NOT_VERIFIED`
- `LIFECYCLE_RUNTIME=NOT_VERIFIED`
- `PUBSUB_RUNTIME_BENEFIT=NOT_VERIFIED_PENDING_DEVICE_LOGS`
