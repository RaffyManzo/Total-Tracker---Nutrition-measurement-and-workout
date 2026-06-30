# Total Tracker â€” Full mock UI integration v1

Questa tranche porta dentro Flutter tutte le schermate previste dal mock
definitivo per Ingredienti ed Esercizi.

## Home provvisoria

La route `/` mostra una home semplice con collegamenti a:

- Ingredienti;
- Esercizi;
- anteprima UI.

## Ingredienti

Route implementate:

- `/ingredients`
- `/ingredients/new`
- `/ingredients/new/manual`
- `/ingredients/new/barcode`
- `/ingredients/new/review`
- `/ingredients/search-online`
- `/ingredients/:id`

Flussi presenti:

- lista e filtri;
- dettaglio completo;
- scelta modalitÃ  di inserimento;
- form manuale con tutti i campi;
- scanner barcode simulato;
- ricerca Open Food Facts simulata;
- revisione obbligatoria;
- modifica e archiviazione simulate.

## Esercizi

Route implementate:

- `/exercises`
- `/exercises/new`
- `/exercises/:id`

Flussi presenti:

- lista, ricerca e filtri;
- dettaglio;
- form completo;
- modalitÃ  gym/activity/treadmill;
- selezione muscoli principali e secondari;
- media, recupero, note;
- modifica e archiviazione simulate.

## Limiti intenzionali

Questa integrazione non modifica ObjectBox e non aggiunge dipendenze.

Restano simulati:

- persistenza;
- scansione fotocamera;
- Open Food Facts;
- Free Exercise DB;
- wger;
- download delle immagini;
- gestione licenze dei media.

La tranche successiva collegherÃ  prima Ingredienti a ObjectBox, mantenendo
invariata la UI.