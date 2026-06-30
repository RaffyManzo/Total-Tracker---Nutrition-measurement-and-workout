# Remaining entities mock UI v1

Questa tranche aggiunge il mock Flutter per le entità ObjectBox introdotte
nello Schema V2.

## Sezioni

- diario giornaliero;
- pasti;
- ricette;
- misurazioni bilancia;
- misurazioni con metro;
- routine;
- schede allenamento;
- sessioni.

## Route principali

- `/tracking`
- `/diary`
- `/meals`
- `/recipes`
- `/measurements`
- `/routines`
- `/plans`
- `/sessions`

Sono presenti liste, dettagli e form dimostrativi.

## Stato dei dati

Tutti i dati sono mock locali. Le schermate non usano ancora ObjectBox.

Il salvataggio dei form è simulato e ritorna alla lista corrispondente.

## Obiettivo

Validare struttura, navigazione, densità informativa e coerenza grafica prima
di collegare controller Riverpod e repository ObjectBox.
