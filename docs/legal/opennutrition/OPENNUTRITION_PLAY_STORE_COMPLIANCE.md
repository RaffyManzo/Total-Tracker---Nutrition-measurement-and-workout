# OpenNutrition e pubblicazione Google Play

Questa checklist accompagna l'integrazione tecnica. Non sostituisce una consulenza legale.

## Licenza del dataset

OpenNutrition distribuisce il database con ODbL e i contenuti con una versione modificata della DbCL.
La distribuzione ufficiale richiede attribuzione:

- in ogni interfaccia che mostra dati OpenNutrition;
- nella scheda Google Play;
- nel sito o pagina ufficiale del prodotto;
- nella sezione legale/informazioni dell'app;
- con attribuzione aggiuntiva a `© Open Food Facts contributors` quando indicato dalla provenienza del record.

L'integrazione conserva per ogni copia personale:

- ID esterno;
- versione dataset;
- licenza;
- attribuzione;
- indicatore di modifica da parte dell'utente.

Il catalogo completo rimane in uno store separato e non viene incluso nel backup personale.
Qualsiasi distribuzione di un database derivato deve essere riesaminata rispetto allo Share-Alike ODbL.

## Testo minimo per la scheda Google Play

> Questa app può scaricare opzionalmente il catalogo alimentare OpenNutrition per consentire ricerche offline. Dati forniti da OpenNutrition (database ODbL; contenuti con versione modificata della DbCL). Alcuni record includono dati di © Open Food Facts contributors. Il catalogo viene salvato localmente sul dispositivo e può essere rimosso dalle impostazioni.

## Data Safety

La sola ricezione del dataset pubblico e il suo trattamento locale non implica automaticamente la raccolta di dati utente. La dichiarazione finale dipende però dall'intera app e da tutti gli SDK inclusi.

Prima della pubblicazione verificare:

- se dati nutrizionali, peso, misure, attività o identificatori lasciano il dispositivo;
- se analytics, crash reporting, pubblicità, backup cloud o servizi di terzi trasmettono dati;
- se i dati sono cifrati in transito;
- possibilità e procedura di cancellazione;
- finalità, conservazione e condivisione;
- coerenza tra comportamento reale, Data Safety e privacy policy.

Se l'app resta interamente locale e non integra SDK che trasmettono dati, la privacy policy deve dichiararlo con precisione, senza promettere più di quanto sia verificato nel codice di release.

## Privacy policy

Google Play richiede una privacy policy pubblica anche per app che non raccolgono dati. Deve essere:

- raggiungibile tramite URL pubblico, attivo e non geolocalizzato;
- non ospitata soltanto come PDF;
- collegata nella Play Console e dentro l'app;
- identificata chiaramente come privacy policy;
- comprensiva di contatto del titolare/sviluppatore;
- comprensiva di dati accessibili, raccolti, utilizzati e condivisi;
- comprensiva di misure di sicurezza, conservazione e cancellazione.

## Health Apps declaration

Total Tracker tratta nutrizione, peso, misure e attività fisica, quindi rientra nell'ambito delle funzionalità salute/fitness. Nella Play Console occorre:

- completare la Health Apps declaration;
- indicare le funzioni salute/fitness realmente offerte;
- evitare dichiarazioni diagnostiche o terapeutiche;
- mostrare un disclaimer se le stime possono essere interpretate come indicazioni mediche;
- richiedere soltanto permessi necessari;
- se verrà aggiunto Health Connect, dichiarare ogni tipo di dato richiesto e motivarne l'uso visibile all'utente.

## Disclaimer consigliato

> Total Tracker fornisce strumenti di registrazione e stime informative relative ad alimentazione e attività fisica. I valori possono essere incompleti o stimati e non costituiscono diagnosi, prescrizioni o consigli medici. Per decisioni sanitarie rivolgersi a un professionista qualificato.

## Controlli prima della release

1. Congelare la versione OpenNutrition e il relativo checksum.
2. Verificare licenze e attribuzioni della versione effettivamente distribuita.
3. Testare installazione, annullamento, aggiornamento e rimozione catalogo.
4. Verificare che le copie personali sopravvivano alla rimozione del catalogo.
5. Verificare che non vengano mostrati più di 25 risultati per pagina.
6. Verificare che l'attribuzione appaia in ogni risultato esterno e nel dettaglio.
7. Eseguire audit di dipendenze e SDK per Data Safety.
8. Pubblicare privacy policy e pagina attribuzioni sul sito.
9. Compilare Health Apps declaration e Data Safety in modo coerente.
10. Conservare screenshot e versione dei testi dichiarati per ogni release.
