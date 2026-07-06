import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:objectbox/objectbox.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../core/services/app_info_service.dart';
import '../../../core/preferences/target_model_preferences.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../../nutrition/data/entities/ingredient_entity.dart';
import '../../nutrition/data/entities/nutrition_tracking_entities.dart';
import '../../nutrition/data/services/food_analytics_service.dart';
import '../../nutrition/domain/meal_target_settings.dart';
import '../../nutrition/domain/target_model_constants.dart';
import '../../nutrition/presentation/food_v01_screens.dart';
import '../../nutrition/presentation/measurement_screens.dart';
import '../data/entities/user_profile_entity.dart';
import '../domain/profile_codes.dart';
import '../domain/profile_nutrition_calculator.dart';
import '../domain/profile_activity_estimator.dart';
import 'profile_activity_settings_panel.dart';
import 'widgets/diagnostics_settings_card.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key, this.sectionCode});

  final String? sectionCode;

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _initialWeight = TextEditingController();
  final TextEditingController _height = TextEditingController();
  final TextEditingController _stepGoal = TextEditingController();
  final TextEditingController _targetKcal = TextEditingController();
  final TextEditingController _adaptiveReferenceDays = TextEditingController();
  final TextEditingController _sedentaryBase = TextEditingController();
  final TextEditingController _workoutsPerWeek = TextEditingController();
  final TextEditingController _workoutDuration = TextEditingController();
  final TextEditingController _proteinKg = TextEditingController();
  final TextEditingController _fatKg = TextEditingController();
  final TextEditingController _fiberKg = TextEditingController();
  final TextEditingController _carbsKg = TextEditingController();
  final TextEditingController _sugarCarbsPercent = TextEditingController();
  bool _loaded = false;
  String _sex = BiologicalSexCodes.unspecified;
  String _targetMode = TargetModeCodes.adaptiveWeekly;
  String _workoutType = WorkoutActivityTypeCodes.weights;
  String _activityFallbackMode =
      ActivityFallbackModeCodes.recordedWithProfileFallback;
  String _macroMode = MacroModeCodes.defaultByWeight;
  String _themeMode = ThemePreferenceCodes.system;
  String _language = 'it';
  bool _stepsPolicyBannerVisible = true;
  final TargetModelPreferences _targetModelPreferences =
      TargetModelPreferences();
  bool _isApplying = false;
  double? _applyProgress;
  String _applyMessage = 'Preparazione aggiornamento...';
  @override
  void initState() {
    super.initState();
    _refreshStepsPolicyBanner();
  }

  Future<void> _refreshStepsPolicyBanner() async {
    final bool visible =
        await _targetModelPreferences.isStepsExclusionBannerVisible();
    if (!mounted) return;
    setState(() => _stepsPolicyBannerVisible = visible);
  }

  Future<void> _dismissStepsPolicyBanner() async {
    await _targetModelPreferences.dismissStepsExclusionBanner();
    if (!mounted) return;
    setState(() => _stepsPolicyBannerVisible = false);
  }

  Future<void> _resetInformationalWarnings() async {
    await _targetModelPreferences.resetInformationalWarnings();
    if (!mounted) return;
    setState(() => _stepsPolicyBannerVisible = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avvisi informativi ripristinati.')),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _initialWeight.dispose();
    _height.dispose();
    _stepGoal.dispose();
    _targetKcal.dispose();
    _adaptiveReferenceDays.dispose();
    _sedentaryBase.dispose();
    _workoutsPerWeek.dispose();
    _workoutDuration.dispose();
    _proteinKg.dispose();
    _fatKg.dispose();
    _fiberKg.dispose();
    _carbsKg.dispose();
    _sugarCarbsPercent.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileRepository = ref.watch(userProfileRepositoryProvider);
    final UserProfileEntity profile = profileRepository.getActiveProfile() ??
        profileRepository.createDefaultProfileIfMissing();
    _load(profile);
    final ScaleMeasurementEntity? latestScale =
        ref.watch(measurementRepositoryProvider).latestScale();
    final double? currentWeight =
        latestScale?.weightKg ?? profile.initialWeightKg;
    final ProfileNutritionTargets estimate =
        const ProfileNutritionCalculator().calculateFixedTargets(
      profile,
      currentWeightKg: currentWeight,
    );
    final String dataPath =
        ref.watch(objectBoxDatabaseProvider).directory ?? 'Store non aperto';
    final MealTargetSettings mealTargetSettings =
        MealTargetSettings.fromProfile(profile);
    final AsyncValue<AppInfoSnapshot> appInfo = ref.watch(appInfoProvider);

    return PopScope(
      canPop: !_isApplying,
      child: Scaffold(
        appBar: AppBar(title: Text(_settingsSectionTitle(widget.sectionCode))),
        bottomNavigationBar:
            const TtFoodBottomNavBar(activeItem: TtFoodNavItem.settings),
        body: Stack(
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl,
              ),
              children: _buildSettingsSectionChildren(
                profile: profile,
                estimate: estimate,
                currentWeight: currentWeight,
                hasScaleMeasurement: latestScale != null,
                dataPath: dataPath,
                mealTargetSettings: mealTargetSettings,
                appInfo: appInfo,
              ),
            ),
            if (_isApplying)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context)
                      .colorScheme
                      .scrim
                      .withValues(alpha: 0.42),
                  child: Center(
                    child: TtAppCard(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          LinearProgressIndicator(value: _applyProgress),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            _applyMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Non chiudere questa pagina e non tornare indietro: '
                            'profilo e target vengono salvati insieme soltanto '
                            'al termine del ricalcolo.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _settingsSectionTitle(String? sectionCode) {
    return switch (sectionCode) {
      'personal' => 'Dati personali',
      'target_activity' => 'Target e attivit\u00E0',
      'meals' => 'Pasti e macro',
      'app' => 'App e dati',
      _ => 'Profilo e impostazioni',
    };
  }

  List<Widget> _buildSettingsSectionChildren({
    required UserProfileEntity profile,
    required ProfileNutritionTargets estimate,
    required double? currentWeight,
    required bool hasScaleMeasurement,
    required String dataPath,
    required MealTargetSettings mealTargetSettings,
    required AsyncValue<AppInfoSnapshot> appInfo,
  }) {
    final String? sectionCode = widget.sectionCode;

    if (sectionCode == 'personal') {
      return <Widget>[
        const TtSectionHeader(title: 'Dati personali'),
        const SizedBox(height: AppSpacing.md),
        _SummaryCard(
          title: 'Dati personali',
          icon: Icons.person_outline_rounded,
          onEdit: () => _showProfileSheet(profile, currentWeight),
          rows: <_SettingRowData>[
            _SettingRowData(
              'Nome',
              profile.displayName.isEmpty
                  ? 'Non impostato'
                  : profile.displayName,
            ),
            _SettingRowData('Et\u00E0', _age.text.isEmpty ? 'n/d' : _age.text),
            _SettingRowData('Sesso', _sexLabel(profile.biologicalSexCode)),
            _SettingRowData(
              'Peso iniziale',
              profile.initialWeightKg == null
                  ? 'n/d'
                  : '${_num(profile.initialWeightKg)} kg',
            ),
            _SettingRowData(
              'Altezza',
              profile.heightCm == null ? 'n/d' : '${_num(profile.heightCm)} cm',
            ),
          ],
        ),
      ];
    }

    if (sectionCode == 'target_activity') {
      final double weightKg = currentWeight ?? profile.initialWeightKg ?? 70.0;
      return <Widget>[
        if (_stepsPolicyBannerVisible) ...<Widget>[
          _StepsExclusionPolicyBanner(
            onDismiss: _dismissStepsPolicyBanner,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        ProfileTargetActivityBanner(
          profile: profile,
          targets: estimate,
          currentWeightKg: weightKg,
          onEditTarget: () => _showTargetSheet(profile, estimate),
        ),
        const SizedBox(height: AppSpacing.md),
        ProfileActivitySettingsPanel(
          profile: profile,
          weightKg: weightKg,
          onSave: (ProfileActivityConfig config) async {
            profile.activityProfileJson = config.toJsonString();
            _workoutsPerWeek.text = config.sessionsPerWeek.round().toString();
            _workoutDuration.text = config.totalDurationMinutes.toString();
            _workoutType = config.legacyWorkoutTypeCode;
            await _save(profile);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        _TargetModelSourcesCard(
          profile: profile,
          targets: estimate,
          onResetWarnings: _resetInformationalWarnings,
        ),
      ];
    }

    if (sectionCode == 'meals') {
      return <Widget>[
        const TtSectionHeader(title: 'Pasti e macro'),
        const SizedBox(height: AppSpacing.md),
        _SummaryCard(
          title: 'Macronutrienti',
          icon: Icons.pie_chart_outline_rounded,
          onEdit: () => _showMacroSheet(profile),
          rows: <_SettingRowData>[
            _SettingRowData(
                'Modalit\u00E0', _macroModeLabel(profile.macroModeCode)),
            _SettingRowData('Proteine', '${estimate.proteinGrams.round()} g'),
            _SettingRowData('Grassi', '${estimate.fatGrams.round()} g'),
            _SettingRowData('Fibre', '${estimate.fiberGrams.round()} g'),
            _SettingRowData('Carboidrati', '${estimate.carbsGrams.round()} g'),
            _SettingRowData(
              'Zuccheri liberi',
              'limite ${estimate.freeSugarLimitGrams.round()} g · preferibile ${estimate.freeSugarPreferredGrams.round()} g',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SummaryCard(
          title: 'Target per pasto',
          icon: Icons.lunch_dining_outlined,
          onEdit: () => _showMealTargetsSheet(profile),
          rows: <_SettingRowData>[
            _SettingRowData(
              'Modalit\u00E0',
              _mealTargetModeLabel(mealTargetSettings.modeCode),
            ),
            _SettingRowData(
              'Configurazione',
              _mealTargetSettingsSummary(mealTargetSettings),
            ),
          ],
        ),
      ];
    }

    if (sectionCode == 'app') {
      return <Widget>[
        const TtSectionHeader(title: 'App e dati'),
        const SizedBox(height: AppSpacing.md),
        _SummaryCard(
          title: 'Preferenze',
          icon: Icons.settings_outlined,
          onEdit: () => _showAppSheet(profile),
          rows: <_SettingRowData>[
            _SettingRowData('Tema', _themeLabel(profile.themeModeCode)),
            _SettingRowData(
              'Lingua',
              profile.languageCode == 'en' ? 'English' : 'Italiano',
            ),
            const _SettingRowData(
                'Dashboard iniziale', 'Configura in Navigazione'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _AppInformationCard(
          appInfo: appInfo,
          onRefresh: () => ref.invalidate(appInfoProvider),
        ),
        const SizedBox(height: AppSpacing.md),
        const DiagnosticsSettingsCard(),
        const SizedBox(height: AppSpacing.md),
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.storage_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Dati locali',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(dataPath, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onPressed: () => _showDeleteDataSheet(dataPath),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Cancella dati'),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return <Widget>[
      _SummaryCard(
        title: 'Target app',
        icon: Icons.local_fire_department_outlined,
        onTap: () => _showTargetExplanationSheet(
          profile: profile,
          estimate: estimate,
          currentWeight: currentWeight,
          hasScaleMeasurement: hasScaleMeasurement,
        ),
        rows: <_SettingRowData>[
          _SettingRowData('RMR', '${estimate.rmrKcal.round()} kcal'),
          _SettingRowData('Quota base provvisoria',
              'x${estimate.sedentaryMultiplier.toStringAsFixed(2)}'),
          _SettingRowData(
              'Base sedentaria', '${estimate.sedentaryKcal.round()} kcal'),
          _SettingRowData('Fallback allenamenti mancanti',
              '${estimate.workoutDailyKcal.round()} kcal/giorno'),
          _SettingRowData(
              'Target calcolato', '${estimate.targetKcal.round()} kcal'),
          _SettingRowData(
            'Peso attuale',
            currentWeight == null
                ? 'n/d'
                : '${currentWeight.toStringAsFixed(1)} kg',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      const TtSectionHeader(title: 'Profilo'),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Dati personali',
        icon: Icons.person_outline_rounded,
        onEdit: () => _showProfileSheet(profile, currentWeight),
        rows: <_SettingRowData>[
          _SettingRowData(
              'Nome',
              profile.displayName.isEmpty
                  ? 'Non impostato'
                  : profile.displayName),
          _SettingRowData('Eta', _age.text.isEmpty ? 'n/d' : _age.text),
          _SettingRowData('Sesso', _sexLabel(profile.biologicalSexCode)),
          _SettingRowData(
              'Peso iniziale',
              profile.initialWeightKg == null
                  ? 'n/d'
                  : '${_num(profile.initialWeightKg)} kg'),
          _SettingRowData(
              'Altezza',
              profile.heightCm == null
                  ? 'n/d'
                  : '${_num(profile.heightCm)} cm'),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Target e attivita',
        icon: Icons.tune_rounded,
        onEdit: () => _showTargetSheet(profile, estimate),
        rows: <_SettingRowData>[
          _SettingRowData(
              'Modalita target', _targetModeLabel(profile.targetModeCode)),
          _SettingRowData('Target fisso', '${profile.defaultTargetKcal} kcal'),
          _SettingRowData('Target passi', '${profile.defaultStepGoal} passi'),
          _SettingRowData(
            'Kcal per passo',
            '${estimate.stepEstimate.effectiveKcalPerStep.toStringAsFixed(5)} · ${estimate.stepEstimate.coefficientSourceCode}',
          ),
          _SettingRowData(
            'Allenamenti',
            '${profile.averageWorkoutsPerWeek}/settimana, ${profile.averageWorkoutDurationMinutes} min',
          ),
          _SettingRowData('Tipo allenamento',
              _workoutLabel(profile.workoutActivityTypeCode)),
          const _SettingRowData('Prior peso', '7700 kcal/kg'),
          _SettingRowData(
            'Finestra adattiva',
            '${profile.adaptiveReferenceDays} giorni',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Macro nutrienti',
        icon: Icons.pie_chart_outline_rounded,
        onEdit: () => _showMacroSheet(profile),
        rows: <_SettingRowData>[
          _SettingRowData('Modalita', _macroModeLabel(profile.macroModeCode)),
          _SettingRowData('Proteine', '${estimate.proteinGrams.round()} g'),
          _SettingRowData('Grassi', '${estimate.fatGrams.round()} g'),
          _SettingRowData('Fibre', '${estimate.fiberGrams.round()} g'),
          _SettingRowData('Carboidrati', '${estimate.carbsGrams.round()} g'),
          _SettingRowData(
            'Zuccheri liberi',
            'limite ${estimate.freeSugarLimitGrams.round()} g · preferibile ${estimate.freeSugarPreferredGrams.round()} g',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Target per pasto',
        icon: Icons.lunch_dining_outlined,
        onEdit: () => _showMealTargetsSheet(profile),
        rows: <_SettingRowData>[
          _SettingRowData(
            'Modalita',
            _mealTargetModeLabel(mealTargetSettings.modeCode),
          ),
          _SettingRowData(
            'Configurazione',
            _mealTargetSettingsSummary(mealTargetSettings),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sectionGap),
      const TtSectionHeader(title: 'App e dati'),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Preferenze',
        icon: Icons.settings_outlined,
        onEdit: () => _showAppSheet(profile),
        rows: <_SettingRowData>[
          _SettingRowData('Tema', _themeLabel(profile.themeModeCode)),
          _SettingRowData(
              'Lingua', profile.languageCode == 'en' ? 'English' : 'Italiano'),
          const _SettingRowData(
            'Dashboard iniziale',
            'Configura in Navigazione',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _AppInformationCard(
        appInfo: appInfo,
        onRefresh: () => ref.invalidate(appInfoProvider),
      ),
      const SizedBox(height: AppSpacing.md),
      const DiagnosticsSettingsCard(),
      const SizedBox(height: AppSpacing.md),
      _SummaryCard(
        title: 'Import / Export',
        icon: Icons.import_export_rounded,
        onEdit: () => context.push('/settings/transfer'),
        rows: <_SettingRowData>[
          _SettingRowData(
            'Export Folder',
            profile.exportFolderPath.trim().isEmpty
                ? 'Download/Total Tracker (predefinita)'
                : profile.exportFolderPath,
          ),
          const _SettingRowData(
            'Formato',
            '.totaltracker portabile',
          ),
          const _SettingRowData(
            'Importazione',
            'Analisi, conflitti e conferma pagina per pagina',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.storage_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Dati locali',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              dataPath,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onPressed: () => _showDeleteDataSheet(dataPath),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Cancella dati'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _load(UserProfileEntity profile) {
    if (_loaded) {
      return;
    }
    _copyProfileToControllers(profile);
    _loaded = true;
  }

  void _copyProfileToControllers(UserProfileEntity profile) {
    _name.text = profile.displayName;
    _age.text = _ageFromEpochDay(profile.birthDateEpochDay)?.toString() ?? '';
    _initialWeight.text = _num(profile.initialWeightKg);
    _height.text = _num(profile.heightCm);
    _stepGoal.text = profile.defaultStepGoal.toString();
    _targetKcal.text = profile.defaultTargetKcal.toString();
    _adaptiveReferenceDays.text = profile.adaptiveReferenceDays.toString();
    _sedentaryBase.text =
        profile.sedentaryBaseKcal == 0 ? '' : _num(profile.sedentaryBaseKcal);
    _workoutsPerWeek.text = profile.averageWorkoutsPerWeek.toString();
    _workoutDuration.text = profile.averageWorkoutDurationMinutes.toString();
    _proteinKg.text = _num(
      profile.macroModeCode == MacroModeCodes.defaultByWeight
          ? TargetModelConstants.proteinDefaultGramsPerKg
          : profile.proteinGramsPerKg,
    );
    _fatKg.text = _num(
      profile.macroModeCode == MacroModeCodes.defaultByWeight
          ? TargetModelConstants.fatDefaultEnergyPercent
          : profile.fatGramsPerKg,
    );
    _fiberKg.text = _num(profile.fiberGramsPerKg);
    _carbsKg.text = _num(profile.carbsGramsPerKg);
    _sugarCarbsPercent.text = _num(profile.sugarCarbsPercent);
    _sex = _safeCode(
      profile.biologicalSexCode,
      BiologicalSexCodes.values,
      BiologicalSexCodes.unspecified,
    );
    _targetMode = _safeCode(
      profile.targetModeCode,
      TargetModeCodes.values,
      TargetModeCodes.adaptiveWeekly,
    );
    _workoutType = _safeCode(
      profile.workoutActivityTypeCode,
      WorkoutActivityTypeCodes.values,
      WorkoutActivityTypeCodes.weights,
    );
    _activityFallbackMode = profile.activityFallbackModeCode ==
            ActivityFallbackModeCodes.recordedOnly
        ? ActivityFallbackModeCodes.recordedOnly
        : ActivityFallbackModeCodes.recordedWithProfileFallback;
    _macroMode = _safeCode(
      profile.macroModeCode,
      MacroModeCodes.values,
      MacroModeCodes.defaultByWeight,
    );
    _themeMode = _safeCode(
      profile.themeModeCode,
      ThemePreferenceCodes.values,
      ThemePreferenceCodes.system,
    );
    _language =
        _safeCode(profile.languageCode, const <String>{'it', 'en'}, 'it');
  }

  Future<void> _showTargetExplanationSheet({
    required UserProfileEntity profile,
    required ProfileNutritionTargets estimate,
    required double? currentWeight,
    required bool hasScaleMeasurement,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.86,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Come viene calcolato il target',
                      style: Theme.of(sheetContext).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileExplanationCard(
                title: 'Peso usato',
                body: hasScaleMeasurement
                    ? 'Il peso arriva dall’ultima misurazione di bilancia.'
                    : 'Non ci sono misurazioni di bilancia: viene usato il '
                        'peso iniziale del profilo.',
                rows: <_SettingRowData>[
                  _SettingRowData(
                    'Peso',
                    currentWeight == null ? 'n/d' : '${_num(currentWeight)} kg',
                  ),
                  _SettingRowData(
                    'Finestra adattiva',
                    '${profile.adaptiveReferenceDays} giorni',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileExplanationCard(
                title: 'Base sedentaria',
                body:
                    'L’app stima il metabolismo a riposo con Mifflin–St Jeor. '
                    'Il risultato resta in double e viene moltiplicato per la '
                    'quota base provvisoria 1,10, parametro IN STALLO.',
                rows: <_SettingRowData>[
                  _SettingRowData('Modello', TargetModelConstants.modelVersion),
                  _SettingRowData('Equazione', estimate.rmrEquationCode),
                  _SettingRowData(
                    'Coefficiente fisiologico',
                    estimate.rmrPhysiologicalCoefficientCode,
                  ),
                  _SettingRowData('RMR', '${estimate.rmrKcal.round()} kcal'),
                  _SettingRowData('Moltiplicatore',
                      'x${estimate.sedentaryMultiplier.toStringAsFixed(2)}'),
                  _SettingRowData('Base sedentaria',
                      '${estimate.sedentaryKcal.round()} kcal'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileExplanationCard(
                title: 'Attivita e fallback',
                body: _activityFallbackDescription(_activityFallbackMode),
                rows: <_SettingRowData>[
                  _SettingRowData(
                    'Modalita',
                    _activityFallbackModeLabel(_activityFallbackMode),
                  ),
                  _SettingRowData(
                    'Passi target',
                    '${profile.defaultStepGoal} · ${estimate.stepDailyKcal.round()} kcal',
                  ),
                  _SettingRowData(
                    'Lunghezza passo',
                    estimate.stepEstimate.stepLengthMeters == null
                        ? 'fallback legacy'
                        : '${estimate.stepEstimate.stepLengthMeters!.toStringAsFixed(3)} m (${estimate.stepEstimate.stepLengthSourceCode})',
                  ),
                  _SettingRowData(
                    'Coefficiente effettivo',
                    '${estimate.stepEstimate.effectiveKcalPerStep.toStringAsFixed(5)} kcal/passo',
                  ),
                  _SettingRowData(
                    'Allenamenti',
                    '${profile.averageWorkoutsPerWeek}/settimana · '
                        '${profile.averageWorkoutDurationMinutes} min',
                  ),
                  _SettingRowData(
                    'Quota profilo',
                    '${estimate.profileActivityDailyKcal.round()} kcal/giorno',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileExplanationCard(
                title: 'Modalita target',
                body: profile.targetModeCode == TargetModeCodes.fixedUser
                    ? 'Usa sempre il target fisso impostato dall’utente.'
                    : profile.targetModeCode ==
                            TargetModeCodes.appCalculatedFixed
                        ? 'Usa il target calcolato dal profilo e lo mantiene '
                            'stabile nei giorni.'
                        : 'Ogni settimana usa una finestra storica per '
                            'stimare il TDEE osservato e adattare il target.',
                rows: <_SettingRowData>[
                  _SettingRowData(
                    'Modalita',
                    _targetModeLabel(profile.targetModeCode),
                  ),
                  _SettingRowData('Target calcolato',
                      '${estimate.targetKcal.round()} kcal'),
                  const _SettingRowData(
                    'Prior energetico peso',
                    '7700 kcal/kg · euristica approvata',
                  ),
                  _SettingRowData(
                    'Guardrail',
                    estimate.guardrailApplied
                        ? 'Applicato: ${estimate.guardrailReasonCode}'
                        : 'Non applicato',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showProfileSheet(
    UserProfileEntity profile,
    double? currentWeight,
  ) async {
    final bool saved = await _showEditorSheet(
      title: 'Dati personali',
      childBuilder: (BuildContext context, StateSetter setSheetState) {
        return <Widget>[
          _field(_name, 'Nome'),
          _field(_age, 'Eta', keyboardType: TextInputType.number),
          DropdownButtonFormField<String>(
            initialValue: _sex,
            decoration: const InputDecoration(labelText: 'Sesso'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: BiologicalSexCodes.unspecified,
                child: Text('Non specificato'),
              ),
              DropdownMenuItem<String>(
                value: BiologicalSexCodes.female,
                child: Text('Donna'),
              ),
              DropdownMenuItem<String>(
                value: BiologicalSexCodes.male,
                child: Text('Uomo'),
              ),
              DropdownMenuItem<String>(
                value: BiologicalSexCodes.other,
                child: Text('Altro'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _sex = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            _initialWeight,
            'Peso iniziale kg',
            keyboardType: TextInputType.number,
          ),
          TextFormField(
            initialValue:
                currentWeight == null ? 'n/d' : '${_num(currentWeight)} kg',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Peso attuale',
              helperText: 'Letto dalle misurazioni bilancia',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_height, 'Altezza cm', keyboardType: TextInputType.number),
        ];
      },
    );
    _finishSheet(profile, saved);
  }

  Future<void> _showTargetSheet(
    UserProfileEntity profile,
    ProfileNutritionTargets estimate,
  ) async {
    final bool saved = await _showEditorSheet(
      title: 'Target e attivita',
      childBuilder: (BuildContext context, StateSetter setSheetState) {
        return <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _targetMode,
            decoration:
                const InputDecoration(labelText: 'Modalita target kcal'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: TargetModeCodes.fixedUser,
                child: Text('Fisso impostato da me'),
              ),
              DropdownMenuItem<String>(
                value: TargetModeCodes.appCalculatedFixed,
                child: Text('Calcolato e fisso'),
              ),
              DropdownMenuItem<String>(
                value: TargetModeCodes.adaptiveWeekly,
                child: Text('Adattivo settimanale'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _targetMode = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (_targetMode == TargetModeCodes.fixedUser) ...<Widget>[
            _field(
              _targetKcal,
              'Target fisso kcal',
              keyboardType: TextInputType.number,
            ),
          ],
          if (_targetMode == TargetModeCodes.adaptiveWeekly) ...<Widget>[
            _field(
              _adaptiveReferenceDays,
              'Finestra adattiva giorni',
              keyboardType: TextInputType.number,
            ),
            Text(
              'Default 28 giorni. I giorni con dati parziali o non affidabili '
              'non vengono conteggiati nel TDEE osservato.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            initialValue: '${estimate.rmrKcal.round()} kcal',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Metabolismo basale',
              helperText:
                  'Mifflin–St Jeor; fallback −78 se coefficiente non specificato',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: 'x${estimate.sedentaryMultiplier.toStringAsFixed(2)}',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Quota base provvisoria',
              helperText:
                  '1,10 · parametro interno IN STALLO, non fattore personale',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: '${estimate.sedentaryKcal.round()} kcal',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Base sedentaria stimata',
              helperText: 'Metabolismo basale moltiplicato per 1.10',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _activityFallbackMode,
            decoration: const InputDecoration(
              labelText: 'Uso dei dati di attivit\u00E0',
              helperText:
                  'Ogni componente registrata prevale; il fallback copre solo ciò che manca',
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: ActivityFallbackModeCodes.recordedWithProfileFallback,
                child: Text('Dati registrati con fallback per componente'),
              ),
              DropdownMenuItem<String>(
                value: ActivityFallbackModeCodes.recordedOnly,
                child: Text('Solo dati registrati'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _activityFallbackMode = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_stepGoal, 'Target passi giornaliero',
              keyboardType: TextInputType.number),
          TextFormField(
            initialValue:
                estimate.stepEstimate.effectiveKcalPerStep.toStringAsFixed(5),
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Kcal attive effettive per passo',
              helperText: estimate.stepEstimate.usedLegacyFallback
                  ? 'Fallback legacy 0,020: altezza non disponibile'
                  : 'peso × lunghezza passo × 0,50 / 1000',
            ),
          ),
          const TtAppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.fitness_center_rounded),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Frequenza, durata, serie, recuperi, battiti e cardio '
                    'si configurano nel pannello Profilo allenamenti della pagina.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TtAppCard(
            child: Text(
              'Il prior della variazione di peso è fissato a 7700 kcal/kg. '
              'La risposta percepita alla perdita di peso non modifica più '
              'automaticamente il modello.',
            ),
          ),
        ];
      },
    );
    _finishSheet(profile, saved);
  }

  Future<void> _showMacroSheet(UserProfileEntity profile) async {
    final double weightKg =
        ref.read(measurementRepositoryProvider).latestScale()?.weightKg ??
            profile.initialWeightKg ??
            70;
    final double targetKcal = const ProfileNutritionCalculator()
        .calculateFixedTargets(profile, currentWeightKg: weightKg)
        .targetKcal;

    void loadSuggestedDefaults() {
      final double proteinPerKg = TargetModelConstants.proteinDefaultGramsPerKg;
      final double proteinKcal =
          proteinPerKg * weightKg * TargetModelConstants.proteinKcalPerGram;
      final double fatGrams = targetKcal *
          TargetModelConstants.fatDefaultEnergyPercent /
          100 /
          TargetModelConstants.fatKcalPerGram;
      final double carbsGrams = (targetKcal -
                  proteinKcal -
                  fatGrams * TargetModelConstants.fatKcalPerGram)
              .clamp(0, double.infinity)
              .toDouble() /
          TargetModelConstants.carbohydrateKcalPerGram;
      _proteinKg.text = _num(proteinPerKg);
      _fatKg.text = _num(fatGrams / weightKg);
      _carbsKg.text = _num(carbsGrams / weightKg);
    }

    final bool saved = await _showEditorSheet(
      title: 'Macro nutrienti',
      childBuilder: (BuildContext context, StateSetter setSheetState) {
        final bool custom = _macroMode == MacroModeCodes.customGramsPerKg;
        final double proteinPerKg = _toDouble(_proteinKg.text) ?? 0;
        final double fatPerKg = _toDouble(_fatKg.text) ?? 0;
        final double carbsPerKg = _toDouble(_carbsKg.text) ?? 0;
        final double calculatedKcal = weightKg *
            (proteinPerKg * TargetModelConstants.proteinKcalPerGram +
                carbsPerKg * TargetModelConstants.carbohydrateKcalPerGram +
                fatPerKg * TargetModelConstants.fatKcalPerGram);
        final double correction =
            calculatedKcal <= 0 ? 1 : targetKcal / calculatedKcal;

        return <Widget>[
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: MacroModeCodes.defaultByWeight,
                label: Text('Default'),
              ),
              ButtonSegment<String>(
                value: MacroModeCodes.customGramsPerKg,
                label: Text('Personalizzato'),
              ),
              ButtonSegment<String>(
                value: MacroModeCodes.customTheo2,
                label: Text('Legacy 0.1.0'),
              ),
              ButtonSegment<String>(
                value: MacroModeCodes.custom,
                label: Text('Legacy storico'),
              ),
            ],
            selected: <String>{_macroMode},
            onSelectionChanged: (Set<String> value) {
              final String nextMode = value.first;
              setSheetState(() {
                if (nextMode == MacroModeCodes.customGramsPerKg &&
                    _macroMode != MacroModeCodes.customGramsPerKg) {
                  loadSuggestedDefaults();
                }
                _macroMode = nextMode;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            _proteinKg,
            custom ? 'Proteine g/kg' : 'Proteine',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: custom,
            onChanged: (_) => setSheetState(() {}),
          ),
          _field(
            _fatKg,
            custom ? 'Grassi g/kg' : 'Grassi',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: custom,
            onChanged: (_) => setSheetState(() {}),
          ),
          _field(
            _carbsKg,
            custom ? 'Carboidrati g/kg' : 'Carboidrati',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            enabled: custom,
            onChanged: (_) => setSheetState(() {}),
          ),
          if (_macroMode == MacroModeCodes.defaultByWeight)
            const TtAppCard(
              child: Text(
                'Il profilo default resta invariato: proteine 1,8 g/kg, '
                'grassi al 25% dell’energia e carboidrati calcolati dalle '
                'calorie residue.',
              ),
            ),
          if (custom)
            _MacroCalorieBanner(
              targetKcal: targetKcal,
              calculatedKcal: calculatedKcal,
              suggestedProteinPerKg: proteinPerKg * correction,
              suggestedFatPerKg: fatPerKg * correction,
              suggestedCarbsPerKg: carbsPerKg * correction,
            ),
          if (_macroMode == MacroModeCodes.customTheo2 ||
              _macroMode == MacroModeCodes.custom)
            const TtAppCard(
              child: Text(
                'Configurazione legacy conservata senza conversione '
                'silenziosa. Seleziona Personalizzato per passare al nuovo '
                'modello in cui proteine, grassi e carboidrati sono tutti '
                'espressi in g/kg.',
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: 'max(25 g, 14 g ogni 1000 kcal)',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Fibre — calcolo automatico',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: '10% limite · 5% obiettivo prudente',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Zuccheri liberi — calcolo automatico',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TtAppCard(
            child: Text(
              'Il suggerimento proporzionale mantiene la distribuzione '
              'relativa inserita dall’utente e scala insieme i tre macro '
              'finché le calorie 4/4/9 coincidono con il target.',
            ),
          ),
        ];
      },
    );
    _finishSheet(profile, saved);
  }

  Future<void> _showMealTargetsSheet(UserProfileEntity profile) async {
    final MealTargetSettings? settings =
        await showModalBottomSheet<MealTargetSettings>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return _MealTargetEditorSheet(
          initial: MealTargetSettings.fromProfile(profile),
        );
      },
    );
    if (settings == null) {
      return;
    }
    profile.mealTargetModeCode = settings.modeCode;
    profile.mealTargetsJson = settings.toJsonString();
    await _save(profile);
  }

  Future<void> _showAppSheet(UserProfileEntity profile) async {
    final bool saved = await _showEditorSheet(
      title: 'Preferenze app',
      childBuilder: (BuildContext context, StateSetter setSheetState) {
        return <Widget>[
          DropdownButtonFormField<String>(
            initialValue: _themeMode,
            decoration: const InputDecoration(labelText: 'Tema'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: ThemePreferenceCodes.system,
                child: Text('Sistema'),
              ),
              DropdownMenuItem<String>(
                value: ThemePreferenceCodes.light,
                child: Text('Chiaro'),
              ),
              DropdownMenuItem<String>(
                value: ThemePreferenceCodes.dark,
                child: Text('Scuro'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _themeMode = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _language,
            decoration: const InputDecoration(labelText: 'Lingua'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'it', child: Text('Italiano')),
              DropdownMenuItem<String>(
                value: 'en',
                child: Text('English'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _language = value);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: 'food',
            decoration: const InputDecoration(
              labelText: 'Dashboard iniziale',
              helperText:
                  'La dashboard allenamenti sara disponibile nella prossima fase.',
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'food',
                child: Text('Food Plan'),
              ),
              DropdownMenuItem<String>(
                value: 'workout',
                enabled: false,
                child: Text('Allenamenti - prossimamente'),
              ),
            ],
            onChanged: null,
          ),
        ];
      },
    );
    _finishSheet(profile, saved);
  }

  Future<bool> _showEditorSheet({
    required String title,
    required List<Widget> Function(BuildContext, StateSetter) childBuilder,
  }) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Chiudi',
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
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
                          AppSpacing.md,
                        ),
                        children: childBuilder(context, setSheetState),
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
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(false),
                                child: const Text('Annulla'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(true),
                                child: const Text('Salva'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    return saved == true;
  }

  Future<void> _finishSheet(UserProfileEntity profile, bool saved) async {
    if (saved) {
      await _save(profile);
    } else {
      _copyProfileToControllers(profile);
      setState(() {});
    }
  }

  Future<void> _showDeleteDataSheet(String dataPath) async {
    final Set<_DataGroup> selected = <_DataGroup>{};
    bool confirm = false;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FractionallySizedBox(
              heightFactor: 0.9,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.sm,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            confirm
                                ? 'Conferma eliminazione'
                                : 'Cancella dati locali',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Chiudi',
                          onPressed: () => Navigator.of(sheetContext).pop(),
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
                        AppSpacing.md,
                      ),
                      children: <Widget>[
                        TtAppCard(
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  dataPath,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copia percorso',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: dataPath),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Percorso copiato.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        if (!confirm)
                          for (final _DataGroup group in _DataGroup.values)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: selected.contains(group),
                              title: Text(group.label),
                              subtitle: Text(group.subtitle),
                              onChanged: (bool? value) {
                                setSheetState(() {
                                  if (value ?? false) {
                                    selected.add(group);
                                  } else {
                                    selected.remove(group);
                                  }
                                });
                              },
                            )
                        else
                          TtAppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Questi dati verranno eliminati dallo store locale ObjectBox.',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                for (final _DataGroup group in selected)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.xs,
                                    ),
                                    child: Text('- ${group.label}'),
                                  ),
                              ],
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
                              onPressed: () {
                                if (confirm) {
                                  setSheetState(() => confirm = false);
                                } else {
                                  Navigator.of(sheetContext).pop();
                                }
                              },
                              child: Text(confirm ? 'Indietro' : 'Chiudi'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: FilledButton(
                              style: confirm
                                  ? FilledButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                      foregroundColor:
                                          Theme.of(context).colorScheme.onError,
                                    )
                                  : null,
                              onPressed: selected.isEmpty
                                  ? null
                                  : () {
                                      if (!confirm) {
                                        setSheetState(() => confirm = true);
                                        return;
                                      }
                                      _deleteSelectedData(selected);
                                      Navigator.of(sheetContext).pop();
                                    },
                              child: Text(confirm ? 'Elimina' : 'Continua'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteSelectedData(Set<_DataGroup> groups) {
    final store = ref.read(objectBoxStoreProvider);
    store.runInTransaction(TxMode.write, () {
      if (groups.contains(_DataGroup.food)) {
        _removeAll<MealItemEntity>(store);
        _removeAll<MealEntity>(store);
        _removeAll<DailyRecordEntity>(store);
      }
      if (groups.contains(_DataGroup.ingredients)) {
        _removeAll<IngredientEntity>(store);
      }
      if (groups.contains(_DataGroup.recipes)) {
        _removeAll<RecipeStepEntity>(store);
        _removeAll<RecipeIngredientEntity>(store);
        _removeAll<RecipeEntity>(store);
      }
      if (groups.contains(_DataGroup.measurements)) {
        _removeAll<TapeMeasurementEntryEntity>(store);
        _removeAll<TapeMeasurementEntity>(store);
        _removeAll<ScaleMeasurementEntity>(store);
        final Box<DailyRecordEntity> dailyBox = store.box<DailyRecordEntity>();
        final List<DailyRecordEntity> days = dailyBox.getAll();
        for (final DailyRecordEntity day in days) {
          day.weightKg = null;
          day.weightRefKg = null;
          day.weightReliabilityCode = '';
        }
        if (days.isNotEmpty) {
          dailyBox.putMany(days);
        }
      }
      if (groups.contains(_DataGroup.profile)) {
        _removeAll<UserProfileEntity>(store);
      }
    });
    ref.read(userProfileRepositoryProvider).createDefaultProfileIfMissing();
    _loaded = false;
    ref.invalidate(profileSettingsRevisionProvider);
    ref.invalidate(foodHubV01Provider);
    ref.invalidate(foodDaysV01Provider);
    ref.invalidate(foodMealsV01Provider);
    ref.invalidate(measurementHubProvider);
    ref.invalidate(ingredientArchiveProvider);
    ref.invalidate(recipeArchiveProvider);
    ref.invalidate(appInfoProvider);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dati selezionati eliminati.')),
    );
  }

  void _removeAll<T>(Store store) {
    final box = store.box<T>();
    final List<int> ids =
        box.getAll().map((dynamic item) => item.id as int).toList();
    if (ids.isNotEmpty) {
      box.removeMany(ids);
    }
  }

  Future<void> _save(UserProfileEntity profile) async {
    if (_isApplying) return;
    setState(() {
      _isApplying = true;
      _applyProgress = 0;
      _applyMessage = 'Preparo le nuove impostazioni...';
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      final int? age = _toInt(_age.text);
      profile.displayName = _name.text.trim();
      profile.birthDateEpochDay =
          age == null ? null : _birthEpochDayForAge(age);
      profile.biologicalSexCode = _sex;
      profile.initialWeightKg = _toDouble(_initialWeight.text);
      profile.heightCm = _toDouble(_height.text);
      profile.defaultStepGoal = _toInt(_stepGoal.text) ?? 8000;
      profile.defaultTargetKcal = _toInt(_targetKcal.text) ?? 1980;
      profile.targetModeCode = _targetMode;
      profile.adaptiveReferenceDays =
          (_toInt(_adaptiveReferenceDays.text) ?? 28).clamp(7, 180).toInt();
      profile.sedentaryBaseKcal = 0;
      profile.rmrActivityFactor = TargetModelConstants.rmrActivityFactor;
      profile.stepKcalCoefficient =
          TargetModelConstants.legacyStepKcalCoefficient;
      profile.averageWorkoutsPerWeek = _toInt(_workoutsPerWeek.text) ?? 0;
      profile.averageWorkoutDurationMinutes =
          _toInt(_workoutDuration.text) ?? 0;
      profile.workoutActivityTypeCode = _workoutType;
      profile.activityFallbackModeCode = _activityFallbackMode;
      profile.macroModeCode = _macroMode;
      if (_macroMode == MacroModeCodes.customGramsPerKg) {
        profile.proteinGramsPerKg = (_toDouble(_proteinKg.text) ?? 0)
            .clamp(0, TargetModelConstants.customProteinMaximumGramsPerKg)
            .toDouble();
        profile.fatGramsPerKg = (_toDouble(_fatKg.text) ?? 0)
            .clamp(0, TargetModelConstants.customFatMaximumGramsPerKg)
            .toDouble();
        profile.carbsGramsPerKg = (_toDouble(_carbsKg.text) ?? 0)
            .clamp(
              0,
              TargetModelConstants.customCarbohydrateMaximumGramsPerKg,
            )
            .toDouble();
      } else if (_macroMode == MacroModeCodes.defaultByWeight) {
        profile.proteinGramsPerKg =
            TargetModelConstants.proteinDefaultGramsPerKg;
      }
      // Fibre e zuccheri restano sempre gestiti dal modello automatico.
      // I campi legacy non vengono convertiti o cancellati silenziosamente.
      profile.themeModeCode = _themeMode;
      profile.languageCode = _language;
      profile.kcalPerKg = TargetModelConstants.energyDensityPriorKcalPerKg;

      final List<DailyRecordEntity> recalculatedDays =
          await _buildRecalculatedDayTargets(profile);
      if (!mounted) return;

      setState(() {
        _applyProgress = 0.94;
        _applyMessage =
            'Salvataggio atomico di profilo e ${recalculatedDays.length} giorni...';
      });
      await WidgetsBinding.instance.endOfFrame;

      ref
          .read(userProfileRepositoryProvider)
          .saveWithDailyRecords(profile, recalculatedDays);

      ref.invalidate(userProfileRepositoryProvider);
      ref.invalidate(profileSettingsRevisionProvider);
      ref.invalidate(foodHubV01Provider);
      ref.invalidate(foodDaysV01Provider);
      ref.invalidate(foodMealsV01Provider);
      _loaded = false;

      if (!mounted) return;
      setState(() {
        _applyProgress = 1;
        _applyMessage = 'Aggiornamento completato.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo e target aggiornati.')),
      );
    } catch (error) {
      _loaded = false;
      ref.invalidate(userProfileRepositoryProvider);
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aggiornamento annullato: nessuna modifica parziale salvata. $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
          _applyProgress = null;
          _applyMessage = 'Preparazione aggiornamento...';
        });
      }
    }
  }

  Future<List<DailyRecordEntity>> _buildRecalculatedDayTargets(
    UserProfileEntity profile,
  ) async {
    final dailyRepository = ref.read(dailyRecordRepositoryProvider);
    final analytics = ref.read(foodAnalyticsServiceProvider);
    final List<DailyRecordEntity> allDays = dailyRepository.getAllActive();
    final DateTime today = DateTime.now();
    final String todayKey = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final List<DailyRecordEntity> days = allDays
        .where((DailyRecordEntity day) => day.dateKey.compareTo(todayKey) >= 0)
        .toList(growable: false);

    if (days.isEmpty) {
      if (mounted) {
        setState(() {
          _applyProgress = 0.88;
          _applyMessage =
              'Snapshot storici conservati; nessun giorno corrente o futuro da aggiornare.';
        });
      }
      return days;
    }

    for (int index = 0; index < days.length; index += 1) {
      final DailyRecordEntity day = days[index];
      day.stepGoal = profile.defaultStepGoal;
      final TargetDayResult result = analytics.targetResultForDay(
        day: day,
        allDays: allDays,
        profile: profile,
      );
      analytics.applyTargetSnapshot(day, result);

      if (index % 2 == 0 || index + 1 == days.length) {
        if (!mounted) return days;
        final double ratio = (index + 1) / days.length;
        setState(() {
          _applyProgress = 0.08 + (ratio * 0.8);
          _applyMessage =
              'Aggiornamento target correnti/futuri: ${index + 1} di ${days.length}...';
        });
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    }
    return days;
  }
}

class _AppInformationCard extends StatelessWidget {
  const _AppInformationCard({
    required this.appInfo,
    required this.onRefresh,
  });

  final AsyncValue<AppInfoSnapshot> appInfo;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return appInfo.when(
      loading: () => const TtAppCard(
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Text('Caricamento informazioni app...')),
          ],
        ),
      ),
      error: (Object error, StackTrace stackTrace) => TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Informazioni app non disponibili',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(error.toString(),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
      data: (AppInfoSnapshot info) => _SummaryCard(
        title: 'Informazioni app',
        icon: Icons.info_outline_rounded,
        onEdit: onRefresh,
        actionIcon: Icons.refresh_rounded,
        actionTooltip: 'Aggiorna',
        rows: <_SettingRowData>[
          _SettingRowData('Versione', info.versionLabel),
          _SettingRowData(
            'Spazio dati locali',
            formatAppByteSize(info.localDataBytes),
          ),
          _SettingRowData(
            'Spazio ObjectBox',
            formatAppByteSize(info.objectBoxBytes),
          ),
          _SettingRowData('Directory file', info.filesDirectory),
          _SettingRowData(
            'Directory ObjectBox',
            info.objectBoxDirectory.isEmpty
                ? 'Store non aperto'
                : info.objectBoxDirectory,
          ),
        ],
      ),
    );
  }
}

class _MealTargetEditorSheet extends StatefulWidget {
  const _MealTargetEditorSheet({required this.initial});

  final MealTargetSettings initial;

  @override
  State<_MealTargetEditorSheet> createState() => _MealTargetEditorSheetState();
}

class _MealTargetEditorSheetState extends State<_MealTargetEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  late String _modeCode;
  String? _distributionError;

  static const List<String> _fields = MealTargetMetricCodes.values;

  @override
  void initState() {
    super.initState();
    _modeCode = MealTargetModeCodes.values.contains(widget.initial.modeCode)
        ? widget.initial.modeCode
        : MealTargetModeCodes.none;
    for (final String slot in MealTargetSettings.supportedSlots) {
      final MealNutrientPercentages initial =
          widget.initial.slotPercentages[slot] ??
              MealNutrientPercentages.uniform;
      _seedControllers(
        slot,
        initial.isComplete ? initial : MealNutrientPercentages.uniform,
      );
    }
  }

  void _seedControllers(String group, MealNutrientPercentages percentages) {
    final Map<String, double?> values = <String, double?>{
      MealTargetMetricCodes.kcal: percentages.kcalPercent,
      MealTargetMetricCodes.protein: percentages.proteinPercent,
      MealTargetMetricCodes.carbs: percentages.carbsPercent,
      MealTargetMetricCodes.fat: percentages.fatPercent,
      MealTargetMetricCodes.fiber: percentages.fiberPercent,
      MealTargetMetricCodes.sugar: percentages.sugarPercent,
    };
    for (final String field in _fields) {
      _controllers['${group}_$field'] = TextEditingController(
        text: _optionalNumber(values[field]),
      );
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String group, String field) {
    return _controllers['${group}_$field']!;
  }

  MealNutrientPercentages _percentagesFor(String group) {
    return MealNutrientPercentages(
      kcalPercent:
          _toDouble(_controller(group, MealTargetMetricCodes.kcal).text),
      proteinPercent:
          _toDouble(_controller(group, MealTargetMetricCodes.protein).text),
      carbsPercent:
          _toDouble(_controller(group, MealTargetMetricCodes.carbs).text),
      fatPercent: _toDouble(_controller(group, MealTargetMetricCodes.fat).text),
      fiberPercent:
          _toDouble(_controller(group, MealTargetMetricCodes.fiber).text),
      sugarPercent:
          _toDouble(_controller(group, MealTargetMetricCodes.sugar).text),
    );
  }

  MealTargetSettings _settings() {
    return MealTargetSettings(
      modeCode: _modeCode,
      slotPercentages: <String, MealNutrientPercentages>{
        for (final String slot in MealTargetSettings.supportedSlots)
          slot: _percentagesFor(slot),
      },
    );
  }

  void _refreshDistribution() {
    if (mounted) {
      setState(() => _distributionError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Distribuzione target per pasto',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          'Imposta la percentuale del totale giornaliero destinata a ogni pasto. Ogni metrica deve sommare al 100%.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Chiudi',
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
                    initialValue: _modeCode,
                    decoration: const InputDecoration(
                      labelText: 'Modalità distribuzione',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem<String>(
                        value: MealTargetModeCodes.none,
                        child: Text('Nessun target per pasto'),
                      ),
                      DropdownMenuItem<String>(
                        value: MealTargetModeCodes.shared,
                        child: Text('Uniforme: 25% per ogni pasto'),
                      ),
                      DropdownMenuItem<String>(
                        value: MealTargetModeCodes.custom,
                        child: Text('Percentuali personalizzate'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          _modeCode = value;
                          _distributionError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_modeCode == MealTargetModeCodes.none)
                    const TtAppCard(
                      child: Text(
                        'I pasti mostreranno solo i valori consumati, senza target o barre di avanzamento.',
                      ),
                    ),
                  if (_modeCode == MealTargetModeCodes.shared)
                    const TtAppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Distribuzione uniforme',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: AppSpacing.xs),
                          Text(
                            'Ogni pasto riceve il 25% di calorie, proteine, carboidrati, grassi, fibre e zuccheri del target giornaliero.',
                          ),
                        ],
                      ),
                    ),
                  if (_modeCode == MealTargetModeCodes.custom) ...<Widget>[
                    _distributionSummaryCard(),
                    const SizedBox(height: AppSpacing.md),
                    for (final String slot
                        in MealTargetSettings.supportedSlots) ...<Widget>[
                      _targetCard(
                        group: slot,
                        title: _mealSlotLabel(slot),
                        subtitle:
                            'Quota percentuale del totale giornaliero per questo pasto.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  if (_distributionError != null) ...<Widget>[
                    TtAppCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.error_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _distributionError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                        onPressed: () {
                          if (!(_formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          final MealTargetSettings settings = _settings();
                          final String? error = settings.validationMessage();
                          if (error != null) {
                            setState(() => _distributionError = error);
                            return;
                          }
                          Navigator.of(context).pop(settings);
                        },
                        child: const Text('Salva'),
                      ),
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

  Widget _distributionSummaryCard() {
    final MealTargetDistributionTotals totals =
        _settings().distributionTotals();
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Controllo somme',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ogni voce deve raggiungere esattamente il 100%.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String metric in MealTargetMetricCodes.values)
                _percentageTotalChip(
                  label: MealTargetMetricCodes.label(metric),
                  value: totals.valueFor(metric),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _percentageTotalChip({
    required String label,
    required double value,
  }) {
    final bool valid = (value - 100).abs() <= 0.01;
    final Color color = valid
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        '$label ${_optionalNumber(value)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _targetCard({
    required String group,
    required String title,
    required String subtitle,
  }) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.kcal),
                  label: 'Calorie',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.protein),
                  label: 'Proteine',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.carbs),
                  label: 'Carboidrati',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.fat),
                  label: 'Grassi',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.fiber),
                  label: 'Fibre',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _targetField(
                  controller: _controller(group, MealTargetMetricCodes.sugar),
                  label: 'Zuccheri',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _targetField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
      ],
      onChanged: (_) => _refreshDistribution(),
      decoration: InputDecoration(
        labelText: label,
        suffixText: '%',
        helperText: 'Quota giornaliera',
      ),
      validator: (String? value) {
        final String clean = value?.trim() ?? '';
        if (clean.isEmpty) {
          return 'Obbligatorio';
        }
        final double? parsed = _toDouble(clean);
        if (parsed == null || parsed < 0 || parsed > 100) {
          return 'Da 0 a 100';
        }
        return null;
      },
    );
  }
}

String _mealTargetModeLabel(String code) {
  return switch (code) {
    MealTargetModeCodes.shared => 'Uniforme: 25% per pasto',
    MealTargetModeCodes.custom => 'Percentuali personalizzate',
    _ => 'Disattivato',
  };
}

String _mealTargetSettingsSummary(MealTargetSettings settings) {
  if (settings.modeCode == MealTargetModeCodes.shared) {
    return '25% di ogni target giornaliero per ciascun pasto';
  }
  if (settings.modeCode == MealTargetModeCodes.custom) {
    final String? error = settings.validationMessage();
    return error == null
        ? 'Sei distribuzioni complete al 100%'
        : 'Configurazione da completare';
  }
  return 'Nessuna distribuzione configurata';
}

String _mealSlotLabel(String slot) {
  return switch (slot) {
    'colazione' => 'Colazione',
    'spuntino' => 'Spuntino',
    'pranzo' => 'Pranzo',
    'cena' => 'Cena',
    _ => slot,
  };
}

String _optionalNumber(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

enum _DataGroup {
  food('Giorni e pasti', 'DailyRecord, Meal e MealItem'),
  ingredients('Ingredienti', 'Archivio IngredientEntity'),
  recipes('Ricette', 'Recipe, ingredienti ricetta e passaggi'),
  measurements('Misurazioni', 'Bilancia, metro e voci metro'),
  profile('Profilo', 'Profilo utente e impostazioni');

  const _DataGroup(this.label, this.subtitle);

  final String label;
  final String subtitle;
}

class _SettingRowData {
  const _SettingRowData(this.label, this.value);

  final String label;
  final String value;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.onEdit,
    this.onTap,
    this.actionIcon = Icons.edit_rounded,
    this.actionTooltip = 'Modifica',
  });

  final String title;
  final IconData icon;
  final List<_SettingRowData> rows;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final IconData actionIcon;
  final String actionTooltip;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return TtAppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, color: colors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: actionTooltip,
                  onPressed: onEdit,
                  icon: Icon(actionIcon),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final _SettingRowData row in rows) _SettingsMetricRow(row: row),
        ],
      ),
    );
  }
}

class _SettingsMetricRow extends StatelessWidget {
  const _SettingsMetricRow({required this.row});

  final _SettingRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileExplanationCard extends StatelessWidget {
  const _ProfileExplanationCard({
    required this.title,
    required this.body,
    required this.rows,
  });

  final String title;
  final String body;
  final List<_SettingRowData> rows;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(body),
          const SizedBox(height: AppSpacing.md),
          for (final _SettingRowData row in rows) _SettingsMetricRow(row: row),
        ],
      ),
    );
  }
}

class _StepsExclusionPolicyBanner extends StatelessWidget {
  const _StepsExclusionPolicyBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Avviso per evitare il doppio conteggio dei passi',
      child: TtAppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.info_outline_rounded),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Evita il doppio conteggio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Chiudi avviso doppio conteggio',
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Nel totale dei passi giornalieri inserisci soltanto i passi '
              'della normale attività quotidiana. Escludi i passi svolti '
              'durante camminate, corse, tapis roulant o altri allenamenti '
              'registrati separatamente, perché le calorie di queste attività '
              'vengono calcolate a parte.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onDismiss,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Ho capito'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetModelSourcesCard extends StatelessWidget {
  const _TargetModelSourcesCard({
    required this.profile,
    required this.targets,
    required this.onResetWarnings,
  });

  final UserProfileEntity profile;
  final ProfileNutritionTargets targets;
  final VoidCallback onResetWarnings;

  @override
  Widget build(BuildContext context) {
    final String stepLength = targets.stepEstimate.stepLengthMeters == null
        ? 'non disponibile · fallback legacy 0,020 kcal/passo'
        : '${targets.stepEstimate.stepLengthMeters!.toStringAsFixed(3)} m · '
            '${targets.stepEstimate.stepLengthSourceCode}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ProfileExplanationCard(
          title: 'Fonti, formule e limiti',
          body:
              'Dettaglio interno del modello ${TargetModelConstants.modelVersion}. '
              'Le evidenze scientifiche, le linee guida e le euristiche sono '
              'separate; i parametri IN STALLO restano operativi ma non sono '
              'presentati come valori fisiologici personali.',
          rows: <_SettingRowData>[
            const _SettingRowData(
              'Evidenza · RMR',
              'Mifflin–St Jeor; stima di popolazione, non calorimetria indiretta',
            ),
            _SettingRowData(
              'Dati RMR',
              'peso ${targets.rmrWeightKg.toStringAsFixed(1)} kg · '
                  'altezza ${targets.rmrHeightCm?.toStringAsFixed(1) ?? 'n/d'} cm · '
                  'età ${targets.rmrAgeYears ?? 'n/d'} · '
                  '${targets.rmrPhysiologicalCoefficientCode}',
            ),
            const _SettingRowData(
              'IN STALLO · quota base',
              'RMR × 1,10 · euristica interna legacy',
            ),
            _SettingRowData('Passi · lunghezza', stepLength),
            _SettingRowData(
              'Passi · formula',
              'peso × distanza × 0,50 kcal/kg/km · '
                  '${targets.stepEstimate.effectiveKcalPerStep.toStringAsFixed(5)} kcal/passo',
            ),
            const _SettingRowData(
              'Fallback attività',
              'separato per passi e allenamenti; una sola componente stimata = '
                  'parzialmente provvisorio',
            ),
            const _SettingRowData(
              'Passi degli allenamenti',
              'esclusione manuale: il totale giornaliero deve già escludere i '
                  'passi delle attività registrate separatamente',
            ),
            const _SettingRowData(
              'Euristica · peso',
              'mediana giornaliera + regressione Theil–Sen + prior 7700 kcal/kg',
            ),
            const _SettingRowData(
              'Composizione corporea',
              'modello attivo con regola conservativa: almeno 7 giorni, 14 giorni '
                  'di copertura, stesso dispositivo, controllo acqua e buchi; '
                  'fallback automatico al peso quando la qualità non basta',
            ),
            _SettingRowData(
              'Guardrail',
              '${profile.minimumReasonableTdee.round()}–'
                  '${profile.maximumReasonableTdee.round()} kcal · '
                  '${targets.guardrailApplied ? 'applicato (${targets.guardrailReasonCode})' : 'non applicato'}',
            ),
            const _SettingRowData(
              'Macro 0.1.0',
              'default invariato; personalizzato in g/kg per proteine, grassi e '
                  'carboidrati con controllo calorie 4/4/9; fibre e zuccheri '
                  'restano automatici',
            ),
            const _SettingRowData(
              'Limite',
              'stima non clinica per adulti sani; esclusi minori, gravidanza, '
                  'allattamento e condizioni cliniche',
            ),
            _SettingRowData(
                'Policy passi', StepsExclusionPolicy.currentVersion),
            const _SettingRowData(
              'Data di entrata in vigore',
              TargetModelConstants.effectiveDate,
            ),
            _SettingRowData(
                'Patch logica', TargetModelConstants.logicalPatchId),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onResetWarnings,
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Ripristina avvisi informativi'),
        ),
      ],
    );
  }
}

class _MacroCalorieBanner extends StatelessWidget {
  const _MacroCalorieBanner({
    required this.targetKcal,
    required this.calculatedKcal,
    required this.suggestedProteinPerKg,
    required this.suggestedFatPerKg,
    required this.suggestedCarbsPerKg,
  });

  final double targetKcal;
  final double calculatedKcal;
  final double suggestedProteinPerKg;
  final double suggestedFatPerKg;
  final double suggestedCarbsPerKg;

  @override
  Widget build(BuildContext context) {
    final double delta = calculatedKcal - targetKcal;
    final double deltaPercent =
        targetKcal <= 0 ? 0 : delta.abs() / targetKcal * 100;
    final bool aligned =
        deltaPercent <= TargetModelConstants.macroCalorieTolerancePercent;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return TtAppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                aligned
                    ? Icons.check_circle_outline_rounded
                    : Icons.tune_rounded,
                color: aligned ? colors.primary : colors.tertiary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  aligned
                      ? 'Calorie dei macro allineate'
                      : 'Distribuzione da riequilibrare',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              Chip(label: Text('Target ${targetKcal.round()} kcal')),
              Chip(label: Text('Macro ${calculatedKcal.round()} kcal')),
              Chip(
                label: Text(
                  '${delta >= 0 ? '+' : ''}${delta.round()} kcal',
                ),
              ),
            ],
          ),
          if (!aligned) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Suggerimento proporzionale basato sui valori inseriti:',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Proteine ${_display(suggestedProteinPerKg)} g/kg · '
              'Grassi ${_display(suggestedFatPerKg)} g/kg · '
              'Carboidrati ${_display(suggestedCarbsPerKg)} g/kg',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  static String _display(double value) {
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  TextInputType? keyboardType,
  String? helperText,
  bool enabled = true,
  ValueChanged<String>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, helperText: helperText),
    ),
  );
}

double? _toDouble(String value) {
  final String clean = value.trim().replaceAll(',', '.');
  if (clean.isEmpty) {
    return null;
  }
  return double.tryParse(clean);
}

int? _toInt(String value) {
  final double? parsed = _toDouble(value);
  return parsed?.round();
}

String _num(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _safeCode(String value, Set<String> allowed, String fallback) {
  return allowed.contains(value) ? value : fallback;
}

int? _ageFromEpochDay(int? epochDay) {
  if (epochDay == null) {
    return null;
  }
  final DateTime birth = DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
  );
  final DateTime now = DateTime.now();
  int age = now.year - birth.year;
  if (DateTime(now.year, birth.month, birth.day).isAfter(now)) {
    age -= 1;
  }
  return age;
}

int _birthEpochDayForAge(int age) {
  final DateTime now = DateTime.now();
  final DateTime birth = DateTime(now.year - age, now.month, now.day);
  return birth.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}

String _sexLabel(String code) {
  return switch (code) {
    BiologicalSexCodes.female => 'Donna',
    BiologicalSexCodes.male => 'Uomo',
    BiologicalSexCodes.other => 'Altro',
    _ => 'Non specificato',
  };
}

String _targetModeLabel(String code) {
  return switch (code) {
    TargetModeCodes.fixedUser => 'Fisso impostato',
    TargetModeCodes.adaptiveWeekly => 'Adattivo settimanale',
    _ => 'Calcolato e fisso',
  };
}

String _activityFallbackModeLabel(String code) {
  return switch (code) {
    ActivityFallbackModeCodes.recordedOnly => 'Solo dati registrati',
    ActivityFallbackModeCodes.profileEstimate =>
      'Legacy: convertito in fallback per componente',
    _ => 'Registrati con fallback profilo',
  };
}

String _activityFallbackDescription(String code) {
  return switch (code) {
    ActivityFallbackModeCodes.recordedOnly =>
      'Il target usa esclusivamente passi reali e allenamenti completati. '
          'I dati mancanti valgono zero.',
    ActivityFallbackModeCodes.profileEstimate =>
      'Modalità legacy convertita: ogni componente registrata prevale e il '
          'fallback viene usato soltanto per la componente mancante.',
    _ => 'Passi e allenamenti sono valutati separatamente. I dati registrati '
        'prevalgono sempre. Se manca solo una componente, viene stimata solo '
        'quella e il calcolo è parzialmente provvisorio; se mancano entrambe, '
        'il calcolo è provvisorio.',
  };
}

String _workoutLabel(String code) {
  return switch (code) {
    WorkoutActivityTypeCodes.mixed => 'Pesi + aerobico',
    WorkoutActivityTypeCodes.cardio => 'Solo cardio',
    _ => 'Solo sala pesi',
  };
}

String _macroModeLabel(String code) {
  return switch (code) {
    MacroModeCodes.customGramsPerKg => 'Personalizzato g/kg',
    MacroModeCodes.custom => 'Legacy conservato',
    MacroModeCodes.customTheo2 => 'Legacy 0.1.0',
    _ => 'Default 0.1.0',
  };
}

String _themeLabel(String code) {
  return switch (code) {
    ThemePreferenceCodes.light => 'Chiaro',
    ThemePreferenceCodes.dark => 'Scuro',
    _ => 'Sistema',
  };
}
