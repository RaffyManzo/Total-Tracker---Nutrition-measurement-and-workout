# Play Console declaration worksheet - Total Tracker

Documento operativo da completare sul build Android firmato destinato alla pubblicazione. Non costituisce consulenza legale.

## 1. Health Apps declaration

Dichiarare tutte le funzioni realmente presenti, in particolare:

- registrazione di alimentazione e nutrienti;
- gestione del peso e delle misure corporee;
- tracciamento o stima dell'attività fisica;
- obiettivi calorici e nutrizionali;
- eventuali future integrazioni con Health Connect o dispositivi.

Non dichiarare funzioni diagnostiche, terapeutiche o mediche se l'app non le offre. Conservare nell'app e nella scheda store un disclaimer che qualifica valori e stime come informativi.

## 2. Data Safety

Compilare le risposte solo dopo avere controllato il build di release e tutte le dipendenze. Verificare separatamente:

- dati nutrizionali, pasti e ricette;
- peso, misure corporee e attività;
- identificatori del dispositivo o dell'app;
- diagnostica, crash report e analytics;
- backup, sincronizzazione e servizi cloud;
- pubblicità e SDK di terzi;
- trasmissione, cifratura, conservazione e cancellazione.

Il download del catalogo OpenNutrition riceve un dataset pubblico e lo salva localmente. Non usare questo fatto per concludere automaticamente che l'intera app non raccolga dati: la dichiarazione dipende anche dagli SDK, dalle future sincronizzazioni e dal comportamento reale del build distribuito.

## 3. Privacy policy

Prima dell'invio deve esistere una pagina:

- pubblica, attiva, non geolocalizzata e non solo PDF;
- denominata chiaramente Privacy Policy;
- collegata nella Play Console e all'interno dell'app;
- riferita esplicitamente a Total Tracker e allo sviluppatore indicato nello store;
- contenente contatto privacy, dati trattati, finalità, destinatari, sicurezza, conservazione e cancellazione;
- coerente con Data Safety e con gli SDK effettivamente inclusi.

La bozza `PRIVACY_POLICY_DRAFT.md` contiene campi obbligatori ancora da completare e non deve essere pubblicata senza audit.

## 4. Attribuzione OpenNutrition

Inserire nella scheda Google Play:

> Questa app può scaricare opzionalmente il catalogo alimentare OpenNutrition per la ricerca offline. Dati forniti da OpenNutrition (database ODbL; contenuti con versione modificata della DbCL). Alcuni record includono dati di © Open Food Facts contributors.

Verificare inoltre:

- collegamento a OpenNutrition in ogni schermata che mostra il catalogo;
- collegamento e attribuzione Open Food Facts quando la provenienza è indicata;
- sezione legale/informazioni nell'app;
- attribuzione sul sito ufficiale dell'app;
- conservazione di versione, ID sorgente e licenza nelle copie personali;
- riesame Share-Alike prima di distribuire un database derivato o un export del catalogo.

## 5. Permessi e rete

Il prototipo aggiunge il permesso Internet per il download opzionale. Prima della pubblicazione:

- rimuovere permessi non utilizzati;
- verificare il manifest risultante del bundle firmato;
- spiegare chiaramente che il download è opzionale;
- verificare che la ricerca avvenga offline dopo l'importazione;
- documentare dominio, versione e checksum del dataset distribuito.

## 6. Evidenze da conservare per la release

- hash del bundle AAB e versione dell'app;
- elenco dipendenze e SDK;
- versione OpenNutrition e SHA-256;
- screenshot delle attribuzioni;
- copia dei testi Play Store e privacy policy;
- esportazione delle risposte Data Safety e Health Apps;
- risultati di installazione, importazione, annullamento, aggiornamento e rimozione;
- verifica che gli ingredienti personali restino disponibili dopo la rimozione del catalogo.
