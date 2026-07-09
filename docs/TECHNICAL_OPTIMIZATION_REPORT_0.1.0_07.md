# Rapporto tecnico — refinement stabilità/prestazioni 0.1.0-07

Base obbligatoria: `75a0a4c277774471843815acea5fddebd6fa7dcd`.

Destinazione: `fix/0.1.0-07-stability-performance-lifecycle-r2`.

## Interventi

### Transfer

È aggiunto un test end-to-end che apre due store ObjectBox distinti, esporta un archivio `.totaltracker` schema 2, analizza e applica l’import sul secondo store, confronta una rappresentazione canonica e ripete l’import. Una fixture binaria schema 1 esercita il percorso checksum legacy FNV-1a. Un archivio troncato viene rifiutato prima di ogni transazione e lo store destinazione viene confrontato prima/dopo. Un secondo test forza un errore dentro la stessa primitiva `Store.runInTransaction(TxMode.write)` usata da `applyImport` e verifica l’annullamento delle scritture parziali.

Il test verifica inoltre l’esclusione di un ingrediente soft-deleted e la conservazione del riferimento media. La matrice completa delle entità resta documentata in `TRANSFER_COVERAGE_AUDIT.md`; le aree non seedate dal test smoke continuano a essere coperte dalla suite di trasferimento esistente.

### Lifecycle

Gli stati Android sono trattati separatamente. `inactive` non avvia il conteggio del background; `hidden`/`paused` impostano il timestamp una sola volta; duplicati e resume concorrenti vengono coalesciuti; una sola pipeline di reconcile è attiva per generazione e gli eventuali pass aggiuntivi restano seriali; `detached` e dispose impediscono callback tardivi. I log non fingono conteggi di timer o overlay: vengono emesse soltanto metriche realmente disponibili.

### Pub/sub

`hasListener ? 1 : 0` è rimosso come misura. I bus espongono:

- numero reale di sottoscrizioni;
- consegne pendenti;
- callback in corso/completate/scartate;
- eventi coalesciati;
- richieste ed esecuzioni del ricalcolo;
- richieste ed esecuzioni del refresh UI.

La patch rende il flusso misurabile. Non dimostra un vantaggio runtime sul telefono.

### Loading

L’indicatore:

- non appare prima di 200 ms;
- viene cancellato se il lavoro termina prima;
- resta visibile per il minimo configurato dopo la comparsa;
- annulla timer su dispose e su completamento/cancellazione.

### Privacy

Un confine centrale sanitizza mappe, errori e stack prima della scrittura. Le stringhe sono negate per impostazione predefinita e preservate soltanto per una allowlist di identificatori tecnici e codici controllati. I test impediscono regressioni sui campi vietati e sui campi testuali non classificati.

## Stato conclusioni

- test locali/launcher: da eseguire sulla macchina utente;
- freeze aggiunta alimento: `PENDING_USER_PHONE_TEST`;
- lifecycle Android reale: `PENDING_USER_PHONE_TEST`;
- beneficio prestazionale pub/sub: `NOT_VERIFIED_PENDING_DEVICE_LOGS`;
- preparazione Android Studio: completata dal launcher soltanto dopo probe, validazione reale, commit e push.
