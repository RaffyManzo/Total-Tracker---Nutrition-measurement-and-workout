# Target model 0.1.0 theo.5 — sincronizzazione, affidabilità e import XLS

## Ambito

Questa revisione rende espliciti e verificabili i calcoli già introdotti, aggiunge la sincronizzazione manuale degli snapshot, un catalogo stabile dei dispositivi bilancia, l'importazione di file Excel 97–2003 e una schermata teorica consultabile dall'app.

## RMR

Mifflin–St Jeor:

- coefficiente maschile: `10×peso + 6,25×altezza − 5×età + 5`;
- coefficiente femminile: `10×peso + 6,25×altezza − 5×età − 161`;
- coefficiente non specificato: costante euristica `−78`, media delle due costanti validate.

I calcoli restano in `double`; l'arrotondamento è soltanto grafico. Il fallback `defaultTargetKcal / rmrActivityFactor` è compatibilità, non Mifflin.

## Quota base pre-attività

`quotaBase = RMR × coefficienteBase`.

Il parametro è configurabile tra 1,10 e 1,20. Il valore 1,10 è una stima prudente attribuibile soprattutto al TEF per una dieta mista; l'intervallo superiore aggiunge una quota euristica per attività non rilevata. Non è un PAL sedentario completo e non misura il NEAT personale.

## TDEE

- teorico: `RMR×coefficienteBase + attivitàMedia`;
- osservato: `introitoMedio − variazioneEnergeticaCorporeaMedia`;
- combinato: `confidenza×osservato + (1−confidenza)×teorico`.

Il guardrail PAL 1,40–2,40×RMR si applica al TDEE medio di riferimento. Il target finale del singolo giorno aggiunge il delta di attività senza essere nuovamente compresso nel PAL abituale.

## Composizione corporea

Massa grassa e massa priva di grasso vengono stimate per ogni giornata valida. Le pendenze robuste Theil–Sen sono convertite con densità energetiche distinte. Il candidato può essere calcolato e mostrato senza essere selezionato.

### Affidabilità

Il punteggio è:

- giorni validi: 30%;
- copertura temporale: 25%;
- regolarità/intervallo massimo: 20%;
- stabilità e disponibilità dell'acqua: 15%;
- coerenza dispositivo: 10%.

La UI espone fattori, contributi pesati, totale, soglia minima, stato acqua, stato dispositivo e ragione di eventuale esclusione dura. Un range acqua oltre 6 punti percentuali resta `water_variation_too_large`. Due identificatori noti distinti restano un conflitto duro. Un solo dispositivo noto insieme a misure storiche non specificate riceve una penalità, ma non produce automaticamente `device_changed`.

## Dispositivi

Ogni dispositivo configurato ha UUID stabile e nome visuale. Le misurazioni salvano un token contenente UUID e snapshot del nome. La rinomina non simula un cambio bilancia. Una migrazione guidata può associare le vecchie misure prive di dispositivo.

## Sincronizzazione

Il ricalcolo storico procede cronologicamente e ogni data usa soltanto dati disponibili fino a quella data. Gli obiettivi passi già salvati nella singola giornata non vengono sovrascritti dal valore predefinito del profilo. Il ricalcolo giornaliero, il pull-to-refresh e il comando delle impostazioni devono usare lo stesso servizio, persistere lo snapshot e invalidare i provider UI.

## Import XLS

Sono supportati file BIFF8 `.xls`. Data/ora e peso sono obbligatori. Le intestazioni vengono normalizzate e confrontate per uguaglianza, inclusione e sovrapposizione di token. Prima dell'importazione sono mostrati mapping, avvisi e tutte le misurazioni. I duplicati data/ora sono ignorati. I campi non modellati sono preservati nelle note.

## Prestazioni ricerca ingredienti

I selettori di pasto e ricetta non costruiscono la libreria illustrata a query vuota. Dopo l'uso della barra di ricerca vengono mostrati al massimo dieci risultati e solo per tali risultati sono richieste/renderizzate le immagini.

## Fonti

1. Mifflin MD et al. A new predictive equation for resting energy expenditure in healthy individuals. *Am J Clin Nutr*. 1990.
2. Westerterp KR. Diet induced thermogenesis. *Nutr Metab*. 2004; e riferimenti sui range del TEF per macronutriente.
3. Levine JA. Non-exercise activity thermogenesis (NEAT). *Best Pract Res Clin Endocrinol Metab*. 2002/2004.
4. FAO/WHO/UNU. Human energy requirements. PAL sedentario 1,40–1,69 e limite abitualmente sostenibile circa 2,40.
5. Sen PK / Theil H. Stimatore robusto della pendenza mediana.
