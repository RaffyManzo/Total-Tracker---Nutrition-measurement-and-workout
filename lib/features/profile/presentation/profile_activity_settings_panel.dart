import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../data/entities/user_profile_entity.dart';
import '../domain/profile_activity_estimator.dart';
import '../domain/profile_nutrition_calculator.dart';

class ProfileTargetActivityBanner extends StatelessWidget {
  const ProfileTargetActivityBanner({
    super.key,
    required this.profile,
    required this.targets,
    required this.currentWeightKg,
    required this.onEditTarget,
  });

  final UserProfileEntity profile;
  final ProfileNutritionTargets targets;
  final double currentWeightKg;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    final ProfileActivityConfig config = ProfileActivityConfig.fromJsonString(
      profile.activityProfileJson,
      legacyWorkoutTypeCode: profile.workoutActivityTypeCode,
      legacyDurationMinutes: profile.averageWorkoutDurationMinutes,
      legacySessionsPerWeek: profile.averageWorkoutsPerWeek,
    );
    final ProfileActivityEstimate activity = ProfileActivityEstimator.estimate(
      config: config,
      weightKg: currentWeightKg,
    );
    final double beforeLimits =
        targets.sedentaryKcal + targets.stepDailyKcal + activity.dailyKcal;
    final double targetAdjustment = targets.targetKcal - beforeLimits;
    final List<ActivityParameterAudit> usedParameters = activity.parameters
        .where((ActivityParameterAudit item) => item.usedInEstimate)
        .toList(growable: false);
    final List<ActivityParameterAudit> inactiveParameters = activity.parameters
        .where((ActivityParameterAudit item) => !item.usedInEstimate)
        .toList(growable: false);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Target e attività',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Riepilogo completo e verificabile: nessun parametro '
                      'usato dal calcolo viene nascosto.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Modifica target e passi',
                onPressed: onEditTarget,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _MetricChip(
                label: 'Target',
                value: '${targets.targetKcal.round()} kcal',
                icon: Icons.flag_outlined,
              ),
              _MetricChip(
                label: 'Base',
                value: '${targets.sedentaryKcal.round()} kcal',
                icon: Icons.bedtime_outlined,
              ),
              _MetricChip(
                label: 'Passi',
                value: '${targets.stepDailyKcal.round()} kcal',
                icon: Icons.directions_walk_rounded,
              ),
              _MetricChip(
                label: 'Allenamenti',
                value: '${activity.dailyKcal.round()} kcal/g',
                icon: Icons.fitness_center_rounded,
              ),
              _MetricChip(
                label: 'Affidabilità',
                value:
                    '${activity.confidenceLabel} ${activity.confidenceScore}/100',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${activity.perSessionKcal.round()} kcal attive per sessione',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Intervallo indicativo '
                  '${activity.lowEstimateKcal.round()}–${activity.highEstimateKcal.round()} kcal · '
                  '${config.sessionsPerWeek.toStringAsFixed(1)} sessioni/settimana · '
                  '${activity.weeklyKcal.round()} kcal/settimana.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_search_rounded),
              title: const Text('Mostra il dettaglio completo del calcolo'),
              subtitle: Text(
                '${activity.segments.length} segmenti · '
                '${usedParameters.length} parametri usati · '
                '${activity.impacts.length} analisi di variazione',
              ),
              children: <Widget>[
                _BreakdownSection(
                  icon: Icons.bedtime_outlined,
                  title: '1. Base sedentaria',
                  subtitle: '${targets.sedentaryKcal.round()} kcal',
                  children: <Widget>[
                    _DetailRow(
                      label: 'RMR usato',
                      value: '${targets.rmrKcal.toStringAsFixed(2)} kcal',
                      detail:
                          'Valore prodotto dal calcolatore metabolico del profilo.',
                    ),
                    _DetailRow(
                      label: 'Moltiplicatore sedentario',
                      value: targets.sedentaryMultiplier.toStringAsFixed(3),
                      detail:
                          'Include la base sedentaria; passi e allenamenti vengono aggiunti solo come calorie attive.',
                    ),
                    _DetailRow(
                      label: 'Formula',
                      value:
                          '${targets.rmrKcal.toStringAsFixed(2)} × ${targets.sedentaryMultiplier.toStringAsFixed(3)}',
                      detail:
                          '= ${targets.sedentaryKcal.toStringAsFixed(2)} kcal.',
                    ),
                    _DetailRow(
                      label: 'Variazione locale: +1 kcal RMR',
                      value:
                          '+${targets.sedentaryMultiplier.toStringAsFixed(3)} kcal target',
                      detail:
                          'Il RMR viene moltiplicato per il fattore sedentario.',
                    ),
                    _DetailRow(
                      label: 'Variazione locale: +0,01 fattore',
                      value:
                          '+${(targets.rmrKcal * 0.01).toStringAsFixed(2)} kcal target',
                      detail: 'Con RMR invariato.',
                    ),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.directions_walk_rounded,
                  title: '2. Passi attivi',
                  subtitle: '${targets.stepDailyKcal.round()} kcal/giorno',
                  children: <Widget>[
                    _DetailRow(
                      label: 'Passi del profilo',
                      value: '${profile.defaultStepGoal}',
                      detail:
                          'Valore medio/obiettivo usato nella previsione del profilo.',
                    ),
                    _DetailRow(
                      label: 'Coefficiente attivo per passo',
                      value:
                          '${profile.stepKcalCoefficient.toStringAsFixed(4)} kcal/passo',
                      detail: 'Non contiene la quota di riposo.',
                    ),
                    _DetailRow(
                      label: 'Formula',
                      value:
                          '${profile.defaultStepGoal} × ${profile.stepKcalCoefficient.toStringAsFixed(4)}',
                      detail:
                          '= ${targets.stepDailyKcal.toStringAsFixed(2)} kcal attive.',
                    ),
                    _DetailRow(
                      label: 'Variazione locale: +1.000 passi',
                      value:
                          '+${(1000 * profile.stepKcalCoefficient).toStringAsFixed(2)} kcal',
                      detail: 'Con coefficiente invariato.',
                    ),
                    _DetailRow(
                      label: 'Variazione locale: +0,001 kcal/passo',
                      value:
                          '+${(profile.defaultStepGoal * 0.001).toStringAsFixed(2)} kcal',
                      detail: 'Con numero di passi invariato.',
                    ),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.timeline_rounded,
                  title: '3. Segmenti della sessione',
                  subtitle:
                      '${activity.perSessionKcal.toStringAsFixed(1)} kcal attive',
                  children: <Widget>[
                    for (final ActivityEstimateSegment segment
                        in activity.segments)
                      _SegmentAuditCard(segment: segment),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.fact_check_outlined,
                  title: '4. Parametri effettivamente usati',
                  subtitle:
                      '${usedParameters.length} parametri e valori derivati',
                  children: <Widget>[
                    for (final ActivityParameterAudit parameter
                        in usedParameters)
                      _ParameterAuditCard(parameter: parameter),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.visibility_off_outlined,
                  title: '5. Parametri memorizzati ma non attivi',
                  subtitle:
                      '${inactiveParameters.length} parametri senza effetto nel preset corrente',
                  children: <Widget>[
                    if (inactiveParameters.isEmpty)
                      const _InfoBox(
                        text:
                            'Tutti i parametri memorizzati sono usati dal preset corrente.',
                      )
                    else
                      for (final ActivityParameterAudit parameter
                          in inactiveParameters)
                        _ParameterAuditCard(parameter: parameter),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.tune_rounded,
                  title: '6. Come cambia il risultato',
                  subtitle:
                      '${activity.impacts.length} parametri analizzati uno alla volta',
                  children: <Widget>[
                    const _InfoBox(
                      text:
                          'Ogni scenario modifica un solo parametro e lascia invariati gli altri. '
                          'Le variazioni non vanno sommate tra loro: il modello è in parte non lineare e applica limiti temporali.',
                    ),
                    for (final ActivityParameterImpact impact
                        in activity.impacts)
                      _ImpactAuditCard(impact: impact),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.functions_rounded,
                  title: '7. Formule eseguite',
                  subtitle: '${activity.calculationLines.length} passaggi',
                  children: <Widget>[
                    for (final ActivityCalculationLine line
                        in activity.calculationLines)
                      _FormulaCard(line: line),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.verified_user_outlined,
                  title: '8. Costruzione dell’affidabilità',
                  subtitle:
                      '${activity.confidenceScore}/100 · ${activity.confidenceLabel}',
                  children: <Widget>[
                    for (final ActivityConfidenceEntry entry
                        in activity.confidenceEntries)
                      _ConfidenceRow(entry: entry),
                    _DetailRow(
                      label: 'Intervallo associato',
                      value:
                          '${activity.lowEstimateKcal.round()}–${activity.highEstimateKcal.round()} kcal',
                      detail:
                          'Intervallo prudenziale derivato dal livello di confidenza; non è una misura clinica.',
                    ),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.info_outline_rounded,
                  title: '9. Assunzioni, fallback e dati mancanti',
                  subtitle: '${activity.assumptions.length} elementi',
                  children: <Widget>[
                    if (activity.assumptions.isEmpty)
                      const _InfoBox(
                        text:
                            'Nessun fallback aggiuntivo segnalato dal modello.',
                      )
                    else
                      for (final String item in activity.assumptions)
                        _BulletText(text: item),
                  ],
                ),
                _BreakdownSection(
                  icon: Icons.calculate_outlined,
                  title: '10. Somma finale del target',
                  subtitle: '${targets.targetKcal.round()} kcal',
                  children: <Widget>[
                    _DetailRow(
                      label: 'Base sedentaria',
                      value: '${targets.sedentaryKcal.toStringAsFixed(2)} kcal',
                      detail: 'RMR × moltiplicatore sedentario.',
                    ),
                    _DetailRow(
                      label: '+ passi attivi',
                      value: '${targets.stepDailyKcal.toStringAsFixed(2)} kcal',
                      detail: 'Passi × coefficiente attivo per passo.',
                    ),
                    _DetailRow(
                      label: '+ allenamenti attivi',
                      value: '${activity.dailyKcal.toStringAsFixed(2)} kcal',
                      detail: 'Sessione × frequenza settimanale ÷ 7.',
                    ),
                    _DetailRow(
                      label: 'Totale prima di limiti/arrotondamenti',
                      value: '${beforeLimits.toStringAsFixed(2)} kcal',
                      detail: 'Somma aritmetica delle tre componenti.',
                    ),
                    _DetailRow(
                      label: 'Correzione finale applicata',
                      value: '${_signed(targetAdjustment)} kcal',
                      detail: targetAdjustment.abs() < 0.01
                          ? 'Nessuna correzione ulteriore.'
                          : 'Differenza dovuta ai limiti o alle regole del calcolatore target.',
                    ),
                    _DetailRow(
                      label: 'Target mostrato',
                      value: '${targets.targetKcal.toStringAsFixed(2)} kcal',
                      detail: 'Valore finale usato dall’app.',
                    ),
                    const _DetailRow(
                      label: 'Versione motore attività',
                      value: '2',
                      detail:
                          'Calorie attive, segmentazione e audit completo dei parametri.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileActivitySettingsPanel extends StatefulWidget {
  const ProfileActivitySettingsPanel({
    super.key,
    required this.profile,
    required this.weightKg,
    required this.onSave,
  });

  final UserProfileEntity profile;
  final double weightKg;
  final Future<void> Function(ProfileActivityConfig config) onSave;

  @override
  State<ProfileActivitySettingsPanel> createState() =>
      _ProfileActivitySettingsPanelState();
}

class _ProfileActivitySettingsPanelState
    extends State<ProfileActivitySettingsPanel> {
  late ProfileActivityConfig _config;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfileActivitySettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activityProfileJson !=
        widget.profile.activityProfileJson) {
      _load();
    }
  }

  void _load() {
    _config = ProfileActivityConfig.fromJsonString(
      widget.profile.activityProfileJson,
      legacyWorkoutTypeCode: widget.profile.workoutActivityTypeCode,
      legacyDurationMinutes: widget.profile.averageWorkoutDurationMinutes,
      legacySessionsPerWeek: widget.profile.averageWorkoutsPerWeek,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileActivityEstimate estimate = ProfileActivityEstimator.estimate(
      config: _config,
      weightKg: widget.weightKg,
    );
    final int estimatedInputs = estimate.parameters
        .where(
          (ActivityParameterAudit item) =>
              item.usedInEstimate &&
              item.sourceCode == ActivityInputSourceCodes.defaultValue,
        )
        .length;
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profilo allenamenti',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      activityPresetLabel(_config.presetCode),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _edit,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Configura'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _MetricChip(
                label: 'Sessione',
                value: '${estimate.perSessionKcal.round()} kcal',
                icon: Icons.bolt_rounded,
              ),
              _MetricChip(
                label: 'Settimana',
                value: '${estimate.weeklyKcal.round()} kcal',
                icon: Icons.calendar_view_week_rounded,
              ),
              _MetricChip(
                label: 'Confidenza',
                value:
                    '${estimate.confidenceLabel} ${estimate.confidenceScore}/100',
                icon: Icons.analytics_outlined,
              ),
              _MetricChip(
                label: 'Intervallo',
                value:
                    '${estimate.lowEstimateKcal.round()}–${estimate.highEstimateKcal.round()} kcal',
                icon: Icons.straighten_rounded,
              ),
              _MetricChip(
                label: 'Input stimati',
                value: '$estimatedInputs',
                icon: Icons.auto_awesome_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tutti i campi sono facoltativi. I dati mancanti vengono '
            'stimati e riportati nelle assunzioni del calcolo.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final ProfileActivityConfig? result =
        await showModalBottomSheet<ProfileActivityConfig>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => _ActivityEditorSheet(initial: _config),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(result);
      if (!mounted) return;
      setState(() => _config = result);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ActivityEditorSheet extends StatefulWidget {
  const _ActivityEditorSheet({required this.initial});

  final ProfileActivityConfig initial;

  @override
  State<_ActivityEditorSheet> createState() => _ActivityEditorSheetState();
}

class _ActivityEditorSheetState extends State<_ActivityEditorSheet> {
  late String _preset;
  late String _organization;
  late String _machine;
  late String _intensity;
  late String _freeIntensity;
  late int _rir;
  late final Map<String, TextEditingController> _c;
  final Set<String> _touchedFields = <String>{};

  @override
  void initState() {
    super.initState();
    final ProfileActivityConfig i = widget.initial;
    _preset = i.presetCode;
    _organization = i.weightsOrganizationCode;
    _machine = i.cardioMachineCode;
    _intensity = i.cardioIntensityCode;
    _freeIntensity = i.freeIntensityCode;
    _rir = i.averageRir;
    _c = <String, TextEditingController>{
      'sessions': _controller(i.sessionsPerWeek),
      'weightsDuration': _controller(i.weightsDurationMinutes),
      'sets': _controller(i.weightSets),
      'rest': _controller(i.restSeconds),
      'setDuration': _controller(i.setDurationSeconds),
      'weightsHr': _controllerOptional(i.weightsAvgHeartRate),
      'inactive': _controllerOptional(i.inactiveMinutes),
      'cardioDuration': _controller(i.cardioDurationMinutes),
      'cardioHr': _controllerOptional(i.cardioAvgHeartRate),
      'cardioPause': _controllerOptional(i.cardioPauseMinutes),
      'speed': _controllerOptional(i.cardioSpeedKmh),
      'incline': _controllerOptional(i.cardioInclinePercent),
      'watts': _controllerOptional(i.cardioWatts),
      'intervals': _controller(i.intervalCount),
      'activeInterval': _controller(i.activeIntervalSeconds),
      'recoveryInterval': _controller(i.recoveryIntervalSeconds),
      'mixedDuration': _controller(i.mixedDurationMinutes),
      'mixedRounds': _controller(i.mixedRounds),
      'mixedWeight': _controller(i.mixedWeightPhaseSeconds),
      'mixedCardio': _controller(i.mixedCardioPhaseSeconds),
      'mixedRest': _controller(i.mixedRestSeconds),
      'mixedWeightsHr': _controllerOptional(i.mixedWeightsAvgHeartRate),
      'mixedCardioHr': _controllerOptional(i.mixedCardioAvgHeartRate),
      'freeDuration': _controller(i.freeDurationMinutes),
      'freePause': _controllerOptional(i.freePauseMinutes),
      'freeHr': _controllerOptional(i.freeAvgHeartRate),
    };
  }

  TextEditingController _controller(num value) =>
      TextEditingController(text: '$value');

  TextEditingController _controllerOptional(num value) =>
      TextEditingController(text: value == 0 ? '' : '$value');

  @override
  void dispose() {
    for (final TextEditingController controller in _c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _hasWeights =>
      _preset == ActivityPresetCodes.weights ||
      _preset == ActivityPresetCodes.weightsCardio;

  bool get _hasCardio =>
      _preset == ActivityPresetCodes.cardioContinuous ||
      _preset == ActivityPresetCodes.cardioIntervals ||
      _preset == ActivityPresetCodes.weightsCardio;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.96,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Configura attività del profilo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _preset,
                  decoration: const InputDecoration(
                    labelText: 'Tipo di sessione',
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final String code in ActivityPresetCodes.values)
                      DropdownMenuItem<String>(
                        value: code,
                        child: Text(activityPresetLabel(code)),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) {
                      _touchedFields.add(ActivityFieldKeys.presetCode);
                      setState(() => _preset = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _numberField('sessions', 'Sessioni medie a settimana'),
                if (_hasWeights) ...<Widget>[
                  _sectionTitle('Blocco pesi'),
                  _numberField('weightsDuration', 'Durata pesi (min)'),
                  _numberField('sets', 'Serie totali per sessione'),
                  _numberField('rest', 'Recupero medio tra le serie (sec)'),
                  _numberField(
                    'setDuration',
                    'Durata media di una serie (sec)',
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: _rir,
                    decoration: const InputDecoration(
                      labelText: 'Vicinanza media al cedimento',
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(
                        value: 5,
                        child: Text('RIR 4+ · lontano'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('RIR 2–3 · moderato'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('RIR 0–1 · vicino'),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Cedimento frequente'),
                      ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        _touchedFields.add(ActivityFieldKeys.averageRir);
                        setState(() => _rir = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _organization,
                    decoration: const InputDecoration(
                      labelText: 'Organizzazione delle serie',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.traditional,
                        child: Text('Serie tradizionali'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.supersets,
                        child: Text('Superserie'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.giantSets,
                        child: Text('Giant set'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.circuit,
                        child: Text('Circuito'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(
                          ActivityFieldKeys.weightsOrganizationCode,
                        );
                        setState(() => _organization = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _numberField(
                    'weightsHr',
                    'Battito medio pesi (opzionale)',
                    optional: true,
                  ),
                  _numberField(
                    'inactive',
                    'Minuti inattivi da escludere (opzionale)',
                    optional: true,
                  ),
                ],
                if (_hasCardio) ...<Widget>[
                  _sectionTitle('Blocco cardio / aerobico'),
                  _numberField('cardioDuration', 'Durata cardio (min)'),
                  DropdownButtonFormField<String>(
                    initialValue: _machine,
                    decoration: const InputDecoration(labelText: 'Tipo cardio'),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in CardioMachineCodes.values)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(cardioMachineLabel(code)),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(ActivityFieldKeys.cardioMachineCode);
                        setState(() => _machine = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _intensity,
                    decoration: const InputDecoration(
                      labelText: 'Intensità cardio',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in ActivityIntensityCodes.values)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(activityIntensityLabel(code)),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(
                          ActivityFieldKeys.cardioIntensityCode,
                        );
                        setState(() => _intensity = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _numberField(
                    'cardioHr',
                    'Battito medio cardio (opzionale)',
                    optional: true,
                  ),
                  _numberField(
                    'cardioPause',
                    'Pause complessive cardio (min, opzionale)',
                    optional: true,
                  ),
                  if (_machine == CardioMachineCodes.treadmill) ...<Widget>[
                    _numberField(
                      'speed',
                      'Velocità media (km/h, opzionale)',
                      optional: true,
                      decimal: true,
                    ),
                    _numberField(
                      'incline',
                      'Pendenza media (%, opzionale)',
                      optional: true,
                      decimal: true,
                    ),
                  ],
                  if (_machine == CardioMachineCodes.bike ||
                      _machine == CardioMachineCodes.elliptical ||
                      _machine == CardioMachineCodes.rower)
                    _numberField(
                      'watts',
                      'Potenza media (watt, opzionale)',
                      optional: true,
                    ),
                  if (_preset ==
                      ActivityPresetCodes.cardioIntervals) ...<Widget>[
                    _numberField('intervals', 'Numero intervalli'),
                    _numberField('activeInterval', 'Durata fase attiva (sec)'),
                    _numberField('recoveryInterval', 'Durata recupero (sec)'),
                  ],
                ],
                if (_preset == ActivityPresetCodes.mixedCircuit) ...<Widget>[
                  _sectionTitle('Circuito misto integrato'),
                  _numberField('mixedDuration', 'Durata totale circuito (min)'),
                  _numberField('mixedRounds', 'Numero round'),
                  _numberField('mixedWeight', 'Fase pesi per round (sec)'),
                  _numberField('mixedCardio', 'Fase aerobica per round (sec)'),
                  _numberField('mixedRest', 'Recupero per round (sec)'),
                  DropdownButtonFormField<int>(
                    initialValue: _rir,
                    decoration: const InputDecoration(
                      labelText: 'Vicinanza al cedimento nelle fasi pesi',
                    ),
                    items: const <DropdownMenuItem<int>>[
                      DropdownMenuItem(
                        value: 5,
                        child: Text('RIR 4+ · lontano'),
                      ),
                      DropdownMenuItem(
                        value: 3,
                        child: Text('RIR 2–3 · moderato'),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text('RIR 0–1 · vicino'),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text('Cedimento frequente'),
                      ),
                    ],
                    onChanged: (int? value) {
                      if (value != null) {
                        _touchedFields.add(ActivityFieldKeys.averageRir);
                        setState(() => _rir = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _machine,
                    decoration: const InputDecoration(
                      labelText: 'Componente aerobica',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in CardioMachineCodes.values)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(cardioMachineLabel(code)),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(ActivityFieldKeys.cardioMachineCode);
                        setState(() => _machine = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _intensity,
                    decoration: const InputDecoration(
                      labelText: 'Intensità componente aerobica',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in ActivityIntensityCodes.values)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(activityIntensityLabel(code)),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(
                          ActivityFieldKeys.cardioIntensityCode,
                        );
                        setState(() => _intensity = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: _organization,
                    decoration: const InputDecoration(
                      labelText: 'Organizzazione delle fasi pesi',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.traditional,
                        child: Text('Serie tradizionali'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.supersets,
                        child: Text('Superserie'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.giantSets,
                        child: Text('Giant set'),
                      ),
                      DropdownMenuItem(
                        value: WeightOrganizationCodes.circuit,
                        child: Text('Circuito'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(
                          ActivityFieldKeys.weightsOrganizationCode,
                        );
                        setState(() => _organization = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_machine == CardioMachineCodes.treadmill) ...<Widget>[
                    _numberField(
                      'speed',
                      'Velocità media fase cardio (km/h, opzionale)',
                      optional: true,
                      decimal: true,
                    ),
                    _numberField(
                      'incline',
                      'Pendenza media fase cardio (%, opzionale)',
                      optional: true,
                      decimal: true,
                    ),
                  ],
                  if (_machine == CardioMachineCodes.bike ||
                      _machine == CardioMachineCodes.elliptical ||
                      _machine == CardioMachineCodes.rower)
                    _numberField(
                      'watts',
                      'Potenza media fase cardio (watt, opzionale)',
                      optional: true,
                    ),
                  _numberField(
                    'mixedWeightsHr',
                    'Battito medio fasi pesi (opzionale)',
                    optional: true,
                  ),
                  _numberField(
                    'mixedCardioHr',
                    'Battito medio fasi cardio (opzionale)',
                    optional: true,
                  ),
                ],
                if (_preset == ActivityPresetCodes.freeActivity) ...<Widget>[
                  _sectionTitle('Attività libera'),
                  _numberField('freeDuration', 'Durata attività (min)'),
                  DropdownButtonFormField<String>(
                    initialValue: _freeIntensity,
                    decoration: const InputDecoration(
                      labelText: 'Intensità percepita',
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final String code in ActivityIntensityCodes.values)
                        DropdownMenuItem<String>(
                          value: code,
                          child: Text(activityIntensityLabel(code)),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        _touchedFields.add(ActivityFieldKeys.freeIntensityCode);
                        setState(() => _freeIntensity = value);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _numberField(
                    'freePause',
                    'Pause complessive (min, opzionale)',
                    optional: true,
                  ),
                  _numberField(
                    'freeHr',
                    'Battito medio (opzionale)',
                    optional: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const TtAppCard(
                  child: Text(
                    'La stima restituisce calorie attive: il MET di riposo '
                    'viene sottratto. Il battito applica soltanto una correzione '
                    'limitata e non sostituisce durata, pause e dati macchina.',
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annulla'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_buildConfig()),
                      child: const Text('Salva configurazione'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      );

  Widget _numberField(
    String key,
    String label, {
    bool optional = false,
    bool decimal = false,
  }) {
    final String configKey = _configKeyForController(key);
    final String source = widget.initial.sourceFor(configKey);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: _c[key],
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        onChanged: (_) => _touchedFields.add(configKey),
        decoration: InputDecoration(
          labelText: label,
          helperText: optional
              ? 'Facoltativo · ${_inputSourceLabel(source)} · vuoto = fallback'
              : 'Origine attuale: ${_inputSourceLabel(source)}',
        ),
      ),
    );
  }

  String _configKeyForController(String key) => switch (key) {
        'sessions' => ActivityFieldKeys.sessionsPerWeek,
        'weightsDuration' => ActivityFieldKeys.weightsDurationMinutes,
        'sets' => ActivityFieldKeys.weightSets,
        'rest' => ActivityFieldKeys.restSeconds,
        'setDuration' => ActivityFieldKeys.setDurationSeconds,
        'weightsHr' => ActivityFieldKeys.weightsAvgHeartRate,
        'inactive' => ActivityFieldKeys.inactiveMinutes,
        'cardioDuration' => ActivityFieldKeys.cardioDurationMinutes,
        'cardioHr' => ActivityFieldKeys.cardioAvgHeartRate,
        'cardioPause' => ActivityFieldKeys.cardioPauseMinutes,
        'speed' => ActivityFieldKeys.cardioSpeedKmh,
        'incline' => ActivityFieldKeys.cardioInclinePercent,
        'watts' => ActivityFieldKeys.cardioWatts,
        'intervals' => ActivityFieldKeys.intervalCount,
        'activeInterval' => ActivityFieldKeys.activeIntervalSeconds,
        'recoveryInterval' => ActivityFieldKeys.recoveryIntervalSeconds,
        'mixedDuration' => ActivityFieldKeys.mixedDurationMinutes,
        'mixedRounds' => ActivityFieldKeys.mixedRounds,
        'mixedWeight' => ActivityFieldKeys.mixedWeightPhaseSeconds,
        'mixedCardio' => ActivityFieldKeys.mixedCardioPhaseSeconds,
        'mixedRest' => ActivityFieldKeys.mixedRestSeconds,
        'mixedWeightsHr' => ActivityFieldKeys.mixedWeightsAvgHeartRate,
        'mixedCardioHr' => ActivityFieldKeys.mixedCardioAvgHeartRate,
        'freeDuration' => ActivityFieldKeys.freeDurationMinutes,
        'freePause' => ActivityFieldKeys.freePauseMinutes,
        'freeHr' => ActivityFieldKeys.freeAvgHeartRate,
        _ => key,
      };

  int _int(String key, int fallback) =>
      int.tryParse(_c[key]!.text.trim()) ?? fallback;

  double _double(String key, double fallback) =>
      double.tryParse(_c[key]!.text.trim().replaceAll(',', '.')) ?? fallback;

  ProfileActivityConfig _buildConfig() {
    final Map<String, String> sources = Map<String, String>.from(
      widget.initial.fieldSources,
    );
    for (final String key in _touchedFields) {
      sources[key] = ActivityInputSourceCodes.user;
    }
    for (final MapEntry<String, TextEditingController> entry in _c.entries) {
      final String configKey = _configKeyForController(entry.key);
      if (_touchedFields.contains(configKey) &&
          entry.value.text.trim().isEmpty) {
        sources[configKey] = ActivityInputSourceCodes.defaultValue;
      }
    }
    return widget.initial.copyWith(
      presetCode: _preset,
      sessionsPerWeek: _double('sessions', 3).clamp(0, 14).toDouble(),
      weightsDurationMinutes: _int('weightsDuration', 60).clamp(0, 300).toInt(),
      weightSets: _int('sets', 16).clamp(0, 80).toInt(),
      restSeconds: _int('rest', 150).clamp(15, 600).toInt(),
      setDurationSeconds: _int('setDuration', 40).clamp(15, 120).toInt(),
      averageRir: _rir,
      weightsAvgHeartRate: _int('weightsHr', 0).clamp(0, 240).toInt(),
      inactiveMinutes: _int('inactive', 0).clamp(0, 240).toInt(),
      weightsOrganizationCode: _organization,
      cardioDurationMinutes: _int('cardioDuration', 25).clamp(0, 300).toInt(),
      cardioMachineCode: _machine,
      cardioIntensityCode: _intensity,
      cardioAvgHeartRate: _int('cardioHr', 0).clamp(0, 240).toInt(),
      cardioPauseMinutes: _int('cardioPause', 0).clamp(0, 240).toInt(),
      cardioSpeedKmh: _double('speed', 0).clamp(0, 30).toDouble(),
      cardioInclinePercent: _double('incline', 0).clamp(0, 30).toDouble(),
      cardioWatts: _int('watts', 0).clamp(0, 1500).toInt(),
      intervalCount: _int('intervals', 8).clamp(1, 80).toInt(),
      activeIntervalSeconds: _int('activeInterval', 60).clamp(10, 900).toInt(),
      recoveryIntervalSeconds: _int(
        'recoveryInterval',
        90,
      ).clamp(10, 900).toInt(),
      mixedDurationMinutes: _int('mixedDuration', 45).clamp(0, 300).toInt(),
      mixedRounds: _int('mixedRounds', 8).clamp(1, 60).toInt(),
      mixedWeightPhaseSeconds: _int('mixedWeight', 90).clamp(10, 900).toInt(),
      mixedCardioPhaseSeconds: _int('mixedCardio', 90).clamp(10, 900).toInt(),
      mixedRestSeconds: _int('mixedRest', 60).clamp(0, 600).toInt(),
      mixedWeightsAvgHeartRate: _int('mixedWeightsHr', 0).clamp(0, 240).toInt(),
      mixedCardioAvgHeartRate: _int('mixedCardioHr', 0).clamp(0, 240).toInt(),
      freeDurationMinutes: _int('freeDuration', 45).clamp(0, 300).toInt(),
      freePauseMinutes: _int('freePause', 0).clamp(0, 240).toInt(),
      freeAvgHeartRate: _int('freeHr', 0).clamp(0, 240).toInt(),
      freeIntensityCode: _freeIntensity,
      fieldSources: Map<String, String>.unmodifiable(sources),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Text('$label · $value'),
        ],
      ),
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      children: children,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SegmentAuditCard extends StatelessWidget {
  const _SegmentAuditCard({required this.segment});

  final ActivityEstimateSegment segment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    segment.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Text(
                  '${segment.activeKcal.toStringAsFixed(2)} kcal',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Durata usata',
              value: '${segment.minutes.toStringAsFixed(2)} min',
              detail: segment.source,
            ),
            _DetailRow(
              label: 'MET lordo → netto',
              value:
                  '${segment.grossMet.toStringAsFixed(2)} → ${segment.netMet.toStringAsFixed(2)}',
              detail: 'È sottratto 1 MET per rimuovere la quota di riposo.',
            ),
            _DetailRow(
              label: 'Peso',
              value: '${segment.weightKg.toStringAsFixed(1)} kg',
              detail: 'Scala linearmente la componente MET.',
            ),
            _DetailRow(
              label: 'Prima della correzione cardiaca',
              value: '${segment.baseActiveKcal.toStringAsFixed(2)} kcal',
              detail: 'MET netto × peso × minuti ÷ 60.',
            ),
            _DetailRow(
              label: 'Fattore cardiaco',
              value: segment.heartRateFactor.toStringAsFixed(3),
              detail:
                  'Effetto ${_signed(segment.heartRateAdjustmentKcal)} kcal sul segmento.',
            ),
            _DetailRow(
              label: 'Formula completa',
              value: segment.formula,
              detail: '= ${segment.activeKcal.toStringAsFixed(2)} kcal attive.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ParameterAuditCard extends StatelessWidget {
  const _ParameterAuditCard({required this.parameter});

  final ActivityParameterAudit parameter;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color border = parameter.usedInEstimate
        ? scheme.primary.withValues(alpha: 0.34)
        : scheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        parameter.label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        parameter.section,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _SmallBadge(
                  text: parameter.usedInEstimate ? 'Usato' : 'Non attivo',
                  emphasized: parameter.usedInEstimate,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _DetailRow(
              label: 'Valore ricevuto',
              value: parameter.rawValue,
              detail: parameter.sourceLabel,
            ),
            _DetailRow(
              label: 'Valore effettivamente usato',
              value: parameter.usedValue,
              detail: parameter.usedInEstimate
                  ? parameter.role
                  : 'Il preset corrente non legge questo parametro.',
            ),
            _DetailRow(
              label: 'Regola / formula',
              value: parameter.formula,
              detail: parameter.effect,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactAuditCard extends StatelessWidget {
  const _ImpactAuditCard({required this.impact});

  final ActivityParameterImpact impact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              impact.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Valore attuale: ${impact.currentValue}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(impact.note, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            for (final ActivityImpactScenario scenario in impact.scenarios)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        scenario.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${scenario.resultPerSessionKcal.toStringAsFixed(1)} kcal/sessione '
                        '(${_signed(scenario.deltaPerSessionKcal)}) · '
                        '${scenario.resultDailyKcal.toStringAsFixed(1)} kcal/giorno '
                        '(${_signed(scenario.deltaDailyKcal)})',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FormulaCard extends StatelessWidget {
  const _FormulaCard({required this.line});

  final ActivityCalculationLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              line.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xxs),
            SelectableText(line.expression),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              line.result,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceRow extends StatelessWidget {
  const _ConfidenceRow({required this.entry});

  final ActivityConfidenceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 54,
            child: Text(
              entry.points >= 0 ? '+${entry.points}' : '${entry.points}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  entry.reason,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('• '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.text, required this.emphasized});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _signed(double value) {
  if (value.abs() < 0.005) return '±0,00';
  final String prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(2)}';
}

String _inputSourceLabel(String code) => switch (code) {
      ActivityInputSourceCodes.user => 'inserito dall’utente',
      ActivityInputSourceCodes.legacy => 'profilo precedente',
      ActivityInputSourceCodes.profile => 'profilo',
      ActivityInputSourceCodes.derived => 'derivato',
      _ => 'stimato / predefinito',
    };

String activityPresetLabel(String code) => switch (code) {
      ActivityPresetCodes.weights => 'Pesi',
      ActivityPresetCodes.cardioContinuous => 'Cardio continuo',
      ActivityPresetCodes.cardioIntervals => 'Cardio intervallato',
      ActivityPresetCodes.weightsCardio => 'Pesi + sessione cardio',
      ActivityPresetCodes.mixedCircuit => 'Misto · circuito integrato',
      ActivityPresetCodes.freeActivity => 'Sport o attività libera',
      _ => 'Attività',
    };

String cardioMachineLabel(String code) => switch (code) {
      CardioMachineCodes.treadmill => 'Tapis roulant',
      CardioMachineCodes.bike => 'Cyclette',
      CardioMachineCodes.elliptical => 'Ellittica',
      CardioMachineCodes.rower => 'Vogatore',
      CardioMachineCodes.stairClimber => 'Stair climber',
      CardioMachineCodes.outdoorWalk => 'Camminata esterna',
      CardioMachineCodes.outdoorRun => 'Corsa esterna',
      _ => 'Cardio generico',
    };

String activityIntensityLabel(String code) => switch (code) {
      ActivityIntensityCodes.light => 'Leggera',
      ActivityIntensityCodes.vigorous => 'Elevata',
      _ => 'Moderata',
    };
