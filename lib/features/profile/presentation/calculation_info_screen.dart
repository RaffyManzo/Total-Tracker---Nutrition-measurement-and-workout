import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/user_profile_entity.dart';
import '../../nutrition/data/entities/nutrition_tracking_entities.dart';

class CalculationInfoScreen extends ConsumerStatefulWidget {
  const CalculationInfoScreen({super.key});

  @override
  ConsumerState<CalculationInfoScreen> createState() =>
      _CalculationInfoScreenState();
}

class _CalculationInfoScreenState extends ConsumerState<CalculationInfoScreen> {
  double? _factor;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(profileSettingsRevisionProvider);
    final UserProfileEntity profile = ref
            .read(userProfileRepositoryProvider)
            .getActiveProfile() ??
        ref.read(userProfileRepositoryProvider).createDefaultProfileIfMissing();
    _factor ??= profile.rmrActivityFactor.clamp(1.10, 1.20).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Info calcolo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Coefficiente base pre-attività tracciata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Moltiplica il metabolismo a riposo prima di aggiungere '
                    'passi e allenamenti. 1,10 è una stima prudente attribuibile '
                    'principalmente alla termogenesi alimentare; valori maggiori '
                    'aggiungono una quota euristica per attività non rilevata. '
                    'Non è un PAL sedentario completo né un NEAT misurato.',
                  ),
                  Slider(
                    min: 1.10,
                    max: 1.20,
                    divisions: 10,
                    label: _factor!.toStringAsFixed(2),
                    value: _factor!,
                    onChanged: _saving
                        ? null
                        : (double value) => setState(() => _factor = value),
                  ),
                  Row(
                    children: <Widget>[
                      Text('Valore: ${_factor!.toStringAsFixed(2)}'),
                      const Spacer(),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(profile),
                        child: Text(_saving ? 'Salvataggio...' : 'Salva'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final _TheorySection section in _sections) ...<Widget>[
            Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: Icon(section.icon),
                title: Text(section.title),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final _TheoryBlock block in section.blocks) ...<Widget>[
                    Text(
                      block.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(block.body),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Bibliografia e fonti'),
              children: <Widget>[
                for (final _Source source in _sources)
                  ListTile(
                    title: Text(source.title),
                    subtitle: Text(source.note),
                    trailing: const Icon(Icons.open_in_new_rounded),
                    onTap: () => launchUrl(
                      Uri.parse(source.url),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(UserProfileEntity profile) async {
    setState(() => _saving = true);
    profile.rmrActivityFactor = _factor!.clamp(1.10, 1.20).toDouble();
    ref
        .read(userProfileRepositoryProvider)
        .saveWithDailyRecords(profile, const <DailyRecordEntity>[]);
    ref.invalidate(profileSettingsRevisionProvider);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Coefficiente salvato. Ricalcola i target per applicarlo.'),
        ),
      );
    }
  }
}

class _TheorySection {
  const _TheorySection(this.title, this.icon, this.blocks);
  final String title;
  final IconData icon;
  final List<_TheoryBlock> blocks;
}

class _TheoryBlock {
  const _TheoryBlock(this.title, this.body);
  final String title;
  final String body;
}

class _Source {
  const _Source(this.title, this.note, this.url);
  final String title;
  final String note;
  final String url;
}

const List<_TheorySection> _sections = <_TheorySection>[
  _TheorySection(
      '1. Dati e ordine temporale', Icons.dataset_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Principio generale',
      'Ogni target viene calcolato usando il profilo, i pasti, i passi, gli '
          'allenamenti completati e le misurazioni disponibili fino alla data '
          'della giornata. Un ricalcolo storico non può usare dati futuri.',
    ),
    _TheoryBlock(
      'Snapshot e UI',
      'Il risultato live viene salvato nel DailyRecord come snapshot con '
          'versione modello, data di calcolo e hash delle sorgenti. Dopo il '
          'salvataggio i provider vengono invalidati e la UI rilegge il record.',
    ),
  ]),
  _TheorySection(
      '2. Metabolismo a riposo', Icons.bedtime_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Mifflin–St Jeor',
      'Maschile: RMR = 10×peso kg + 6,25×altezza cm − 5×età + 5.\n'
          'Femminile: RMR = 10×peso kg + 6,25×altezza cm − 5×età − 161.\n'
          'Coefficiente non specificato: la costante −78 è la media aritmetica '
          'tra +5 e −161; è un’euristica, non una terza formula validata.',
    ),
    _TheoryBlock(
      'Fallback antropometrici',
      'Se mancano dati sufficienti, il fallback tecnico è '
          'defaultTargetKcal / rmrActivityFactor. Il peso tecnico di 70 kg può '
          'essere usato soltanto dove serve evitare un calcolo impossibile; non '
          'rappresenta un peso fisiologico standard.',
    ),
  ]),
  _TheorySection('3. Quota base e termogenesi',
      Icons.local_fire_department_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Formula',
      'quotaBase = RMR × coefficienteBase. Il range configurabile è 1,10–1,20. '
          'Il valore 1,10 è coerente con una stima prudente del TEF della dieta; '
          'la parte superiore del range aggiunge una quota euristica di '
          'movimento non rilevato e può sovrapporsi ai passi se usata male.',
    ),
    _TheoryBlock(
      'Cosa non significa',
      'Non è un fattore sedentario universale, non misura il NEAT individuale '
          'e non sostituisce passi o allenamenti. Il coefficiente resta una '
          'configurazione personale da verificare tramite i dati osservati.',
    ),
  ]),
  _TheorySection(
      '4. Passi e attività', Icons.directions_walk_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Energia dei passi',
      'kcalPassi = pesoKg × passi × lunghezzaPassoMetri × 0,50 / 1000. '
          'La lunghezza usa, nell’ordine, calibrazione personale, valore manuale, '
          'stima da altezza e infine il coefficiente legacy.',
    ),
    _TheoryBlock(
      'Fallback e doppio conteggio',
      'I passi reali prevalgono sempre. L’obiettivo passi configurabile viene '
          'usato solo se i passi mancano. I passi già inclusi in un allenamento '
          'con calorie attive separate devono essere esclusi dal totale giornaliero.',
    ),
    _TheoryBlock(
      'Allenamenti',
      'Il motore alimentare somma esclusivamente estimated_active_calories degli '
          'allenamenti completati. Non ricava calorie da serie, RIR, frequenza '
          'cardiaca o MET interni al modulo allenamenti.',
    ),
  ]),
  _TheorySection('5. TDEE teorico, osservato e combinato',
      Icons.monitor_heart_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'TDEE teorico',
      'TDEEteorico = RMR×coefficienteBase + attivitàMediaDiRiferimento. È una '
          'stima prospettica basata su profilo e attività tracciata.',
    ),
    _TheoryBlock(
      'TDEE osservato',
      'TDEEosservato = calorieAssunteMedie − variazioneEnergeticaCorporeaMedia. '
          'Una variazione negativa delle riserve aumenta il TDEE stimato rispetto '
          'all’introito. Il trend usa una pendenza robusta Theil–Sen.',
    ),
    _TheoryBlock(
      'Blending',
      'TDEEcombinato = confidenzaOsservata×TDEEosservato + '
          '(1−confidenzaOsservata)×TDEEteorico. Se l’osservato manca o ha bassa '
          'affidabilità, prevale il teorico.',
    ),
  ]),
  _TheorySection('6. Composizione corporea',
      Icons.accessibility_new_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Masse e candidato energetico',
      'massaGrassa = peso×grasso%/100; massaPrivaDiGrasso = peso−massaGrassa. '
          'Le pendenze separate vengono convertite usando densità energetiche '
          'differenti e producono un candidato diagnostico. Il candidato può '
          'esistere senza essere selezionato.',
    ),
    _TheoryBlock(
      'Requisiti duri',
      'Almeno 7 giorni validi, 14 giorni di copertura, intervallo massimo 10 '
          'giorni, almeno due date per il trend, acqua entro il limite, pendenze '
          'plausibili e assenza di più dispositivi noti distinti.',
    ),
    _TheoryBlock(
      'Affidabilità',
      'Punteggio = giorni×30% + copertura×25% + regolarità intervalli×20% + '
          'qualità acqua×15% + coerenza dispositivo×10%. La soglia corrente è '
          '55%. La schermata espone fattori e contributi, non solo il totale.',
    ),
    _TheoryBlock(
      'Dispositivi',
      'Due dispositivi noti distinti generano device_changed. Un unico '
          'dispositivo noto insieme a vecchie misure non specificate non genera '
          'più un blocco assoluto: applica una penalità e la nota '
          'device_metadata_incomplete.',
    ),
  ]),
  _TheorySection('7. Guardrail e target giornaliero',
      Icons.shield_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Guardrail medio',
      'Il TDEE combinato abituale viene limitato tra 1,40×RMR e 2,40×RMR. '
          'Questi valori descrivono un intervallo PAL medio sostenibile e non '
          'sono limiti fisiologici rigidi della singola giornata.',
    ),
    _TheoryBlock(
      'Target del giorno',
      'target = TDEE riferimento + (attivitàGiorno − attivitàRiferimento). '
          'Il delta attività non viene ricondotto forzatamente ai guardrail PAL: '
          'una giornata eccezionalmente attiva può superarli.',
    ),
  ]),
  _TheorySection('8. Stati, fallback e avvisi',
      Icons.warning_amber_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Effettivo, parziale e provvisorio',
      'Effettivo: componenti registrate sufficienti. Parzialmente provvisorio: '
          'solo una componente dell’attività è stimata. Provvisorio: dati '
          'fondamentali mancanti o osservato non utilizzabile.',
    ),
    _TheoryBlock(
      'Fallback principali',
      'RMR tecnico per antropometria incompleta; obiettivo passi solo se passi '
          'mancanti; stima allenamento del profilo solo se prevista; weight_only '
          'quando la composizione non supera i controlli; teorico quando '
          'l’osservato non è disponibile.',
    ),
    _TheoryBlock(
      'Avvisi',
      'Gli avvisi descrivono dati mancanti, fallback, anomalie o guardrail. '
          'Sono richiudibili e foldabili; la chiusura vale per l’apertura corrente '
          'e non elimina la condizione che li ha generati.',
    ),
  ]),
  _TheorySection('9. Importazione, esportazione e precisione',
      Icons.import_export_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Import XLS',
      'I file Excel 97–2003 BIFF8 vengono letti senza scrittura iniziale. Le '
          'intestazioni sono normalizzate e confrontate per uguaglianza, inclusione '
          'e sovrapposizione di token. Data/ora e peso sono obbligatori; gli altri '
          'campi sono facoltativi. Ogni riga valida viene mostrata e può essere '
          'selezionata o esclusa prima del salvataggio.',
    ),
    _TheoryBlock(
      'Import/export nativo',
      'L’archivio .totaltracker conserva snapshot del target, TDEE teorico, '
          'osservato e combinato, confidenza, attività, composizione, dispositivo '
          'stabile e chiavi di conferma. Il manifest registra anche la versione '
          'del modello. Gli archivi precedenti restano leggibili: i campi assenti '
          'mantengono i fallback della versione importata.',
    ),
    _TheoryBlock(
      'Arrotondamento',
      'I calcoli restano in double. L’arrotondamento è applicato soltanto in '
          'visualizzazione; i valori importati e gli snapshot mantengono la '
          'precisione disponibile.',
    ),
  ]),
  _TheorySection('10. Dettaglio affidabilità composizione',
      Icons.fact_check_outlined, <_TheoryBlock>[
    _TheoryBlock(
      'Fattore giorni · peso 30%',
      'fattoreGiorni = clamp(giorniValidi / 14, 0, 1). Il requisito duro per '
          'attivare il candidato resta 7 giorni distinti: il punteggio cresce '
          'ancora fino a 14 giorni, evitando che il minimo equivalga già alla '
          'massima affidabilità.',
    ),
    _TheoryBlock(
      'Fattore copertura · peso 25%',
      'fattoreCopertura = clamp(giorniCoperti / 28, 0, 1). Il requisito duro è '
          '14 giorni; la qualità raggiunge il massimo su una finestra completa '
          'di 28 giorni.',
    ),
    _TheoryBlock(
      'Fattore intervallo · peso 20%',
      'Intervallo massimo ≤3 giorni: 1,00; ≤5: 0,85; ≤7: 0,65; oltre 7: 0,45. '
          'Oltre 10 giorni il candidato composizione viene comunque escluso dal '
          'requisito duro, anche se il punteggio diagnostico è calcolabile.',
    ),
    _TheoryBlock(
      'Fattore acqua · peso 15%',
      'Acqua assente o disponibile in meno di metà dei giorni: 0,65. Range acqua '
          '≤2 punti percentuali: 1,00; ≤4: 0,80; oltre 4: 0,55. Un range oltre '
          '6 punti percentuali resta un motivo di esclusione duro perché può '
          'indicare variazioni di idratazione incompatibili con un trend affidabile.',
    ),
    _TheoryBlock(
      'Fattore dispositivo · peso 10%',
      'Un dispositivo noto coerente: 1,00. Un dispositivo noto insieme a misure '
          'non specificate: 0,85 e device_metadata_incomplete. Tutte le misure '
          'senza dispositivo: 0,65. Due ID noti distinti o un aggregato mixed: '
          '0,00 e device_changed, con esclusione dura.',
    ),
    _TheoryBlock(
      'Formula finale e soglia',
      'affidabilità = giorni×0,30 + copertura×0,25 + intervallo×0,20 + '
          'acqua×0,15 + dispositivo×0,10. Il candidato può essere selezionato '
          'solo se il punteggio è almeno 0,55 e tutti i requisiti duri sono '
          'superati. Il punteggio non sostituisce i controlli fisiologici.',
    ),
  ]),
  _TheorySection('11. Trend del peso e densità energetiche',
      Icons.show_chart_rounded, <_TheoryBlock>[
    _TheoryBlock(
      'Weight-only',
      'Il trend robusto del peso viene convertito con il prior convenzionale '
          '7.700 kcal/kg. È un’approssimazione media e resta il fallback quando '
          'la composizione non è selezionabile.',
    ),
    _TheoryBlock(
      'Composizione',
      'Il candidato usa 9.500 kcal/kg per la variazione di massa grassa e '
          '1.020 kcal/kg per la variazione di massa priva di grasso. Le due '
          'componenti sono sommate e divise per i giorni del trend per ottenere '
          'la variazione energetica media giornaliera.',
    ),
    _TheoryBlock(
      'Plausibilità delle pendenze',
      'Il controllo conservativo esclude pendenze assolute oltre 0,25 kg/giorno '
          'per il peso, 0,15 kg/giorno per la massa grassa o 0,15 kg/giorno per '
          'la massa priva di grasso. Sono guardrail ingegneristici non clinici.',
    ),
  ]),
  _TheorySection('12. Macronutrienti e fibra',
      Icons.pie_chart_outline_rounded, <_TheoryBlock>[
    _TheoryBlock(
      'Proteine',
      'Valore predefinito 1,8 g/kg; intervallo guidato 1,4–2,2 g/kg. In modalità '
          'personalizzata il limite tecnico è 5 g/kg. Le calorie proteiche sono '
          'grammi×4.',
    ),
    _TheoryBlock(
      'Grassi e carboidrati',
      'I grassi partono dal 25% dell’energia, con intervallo guidato 20–35%; '
          'forniscono 9 kcal/g. I carboidrati ricevono l’energia residua e '
          'forniscono 4 kcal/g. Il controllo di coerenza energetica tollera '
          'uno scarto dell’1% dovuto alla rappresentazione numerica.',
    ),
    _TheoryBlock(
      'Fibra e zuccheri',
      'Fibra minima: il maggiore tra 25 g e 14 g ogni 1.000 kcal. Gli zuccheri '
          'liberi hanno riferimento massimo del 10% dell’energia e obiettivo '
          'preferibile del 5%; gli zuccheri totali non vengono automaticamente '
          'trattati come equivalenti agli zuccheri liberi.',
    ),
  ]),
  _TheorySection(
      '13. Sincronizzazione e coerenza UI', Icons.sync_rounded, <_TheoryBlock>[
    _TheoryBlock(
      'Ricalcolo storico',
      'Le giornate vengono ordinate cronologicamente. Per ciascuna data il motore '
          'filtra sorgenti e misure fino a quella data, calcola il nuovo snapshot '
          'e lo persiste. Nessun dato futuro può migliorare retroattivamente una '
          'giornata storica.',
    ),
    _TheoryBlock(
      'Ricalcolo del giorno',
      'Il pulsante nelle impostazioni e il trascinamento verso il basso nella '
          'giornata usano lo stesso servizio. L’operazione rilegge le sorgenti, '
          'aggiorna il record, pubblica il refresh del giorno e invalida i provider '
          'prima di mostrare il messaggio di successo.',
    ),
  ]),
];

const List<_Source> _sources = <_Source>[
  _Source(
    'Mifflin et al. (1990)',
    'Equazione per la stima del dispendio energetico a riposo.',
    'https://pubmed.ncbi.nlm.nih.gov/2305711/',
  ),
  _Source(
    'Westerterp (2004)',
    'Effetto termico degli alimenti e differenze tra macronutrienti.',
    'https://pubmed.ncbi.nlm.nih.gov/15113757/',
  ),
  _Source(
    'Levine (2005)',
    'Definizione e variabilità della non-exercise activity thermogenesis.',
    'https://pubmed.ncbi.nlm.nih.gov/15102614/',
  ),
  _Source(
    'FAO/WHO/UNU Human energy requirements',
    'Classificazione PAL e sostenibilità dei livelli di attività abituali.',
    'https://www.fao.org/4/y5686e/y5686e07.htm',
  ),
  _Source(
    'Theil–Sen estimator',
    'Stimatore robusto della pendenza usato per i trend.',
    'https://doi.org/10.2307/1909587',
  ),
];
