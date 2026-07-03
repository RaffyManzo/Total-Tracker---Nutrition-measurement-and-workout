import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:objectbox/objectbox.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../core/services/app_info_service.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_section_header.dart';
import '../../nutrition/data/entities/ingredient_entity.dart';
import '../../nutrition/data/entities/nutrition_tracking_entities.dart';
import '../../nutrition/data/services/food_analytics_service.dart';
import '../../nutrition/domain/meal_target_settings.dart';
import '../../nutrition/presentation/food_v01_screens.dart';
import '../../nutrition/presentation/measurement_screens.dart';
import '../data/entities/user_profile_entity.dart';
import '../domain/profile_codes.dart';
import '../domain/profile_nutrition_calculator.dart';
import '../domain/profile_activity_estimator.dart';
import 'profile_activity_settings_panel.dart';

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
  final TextEditingController _stepCoeff = TextEditingController();
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
  String _activityFallbackMode = ActivityFallbackModeCodes.profileEstimate;
  String _macroMode = MacroModeCodes.defaultByWeight;
  String _themeMode = ThemePreferenceCodes.system;
  String _language = 'it';
  String _weightLossResponse = _WeightLossResponseCodes.standard;
  bool _isApplying = false;
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
    _stepCoeff.dispose();
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

    return Scaffold(
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
                color:
                    Theme.of(context).colorScheme.scrim.withValues(alpha: 0.42),
                child: Center(
                  child: TtAppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Aggiorno profilo e calcoli...',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            _activityFallbackMode = ActivityFallbackModeCodes.profileEstimate;
            await _save(profile);
            if (mounted) {
              setState(() {});
            }
          },
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
            _SettingRowData('Zuccheri max', '${estimate.sugarGrams.round()} g'),
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
          _SettingRowData('Moltiplicatore sedentario',
              'x${estimate.sedentaryMultiplier.toStringAsFixed(2)}'),
          _SettingRowData(
              'Base sedentaria', '${estimate.sedentaryKcal.round()} kcal'),
          _SettingRowData('Allenamenti medi',
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
          _SettingRowData('Kcal per passo', _num(profile.stepKcalCoefficient)),
          _SettingRowData(
            'Allenamenti',
            '${profile.averageWorkoutsPerWeek}/settimana, ${profile.averageWorkoutDurationMinutes} min',
          ),
          _SettingRowData('Tipo allenamento',
              _workoutLabel(profile.workoutActivityTypeCode)),
          _SettingRowData(
              'Risposta peso', _weightLossResponseLabel(_weightLossResponse)),
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
          _SettingRowData('Zuccheri max', '${estimate.sugarGrams.round()} g'),
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
    _stepCoeff.text = _num(profile.stepKcalCoefficient);
    _workoutsPerWeek.text = profile.averageWorkoutsPerWeek.toString();
    _workoutDuration.text = profile.averageWorkoutDurationMinutes.toString();
    _proteinKg.text = _num(profile.proteinGramsPerKg);
    _fatKg.text = _num(profile.fatGramsPerKg);
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
    _activityFallbackMode = ActivityFallbackModeCodes.profileEstimate;
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
    _weightLossResponse = _weightLossResponseFromKcalPerKg(profile.kcalPerKg);
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
                body: 'L’app stima il metabolismo basale con la formula '
                    'Harris-Benedict usando sesso, eta, altezza e peso. Il '
                    'risultato viene moltiplicato per il moltiplicatore '
                    'sedentario configurato.',
                rows: <_SettingRowData>[
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
                body: _activityFallbackDescription(
                    ActivityFallbackModeCodes.profileEstimate),
                rows: <_SettingRowData>[
                  _SettingRowData(
                    'Modalita',
                    _activityFallbackModeLabel(
                        ActivityFallbackModeCodes.profileEstimate),
                  ),
                  _SettingRowData(
                    'Passi target',
                    '${profile.defaultStepGoal} · ${estimate.stepDailyKcal.round()} kcal',
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
                  _SettingRowData(
                    'Risposta peso',
                    _weightLossResponseLabel(_weightLossResponse),
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
                  'Harris-Benedict in base a sesso, età, peso e altezza',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: 'x${estimate.sedentaryMultiplier.toStringAsFixed(2)}',
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Moltiplicatore sedentario',
              helperText: 'Base fissa 1.10 per il calcolo sedentario',
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
                  'Le sorgenti registrate saranno abilitate con il motore allenamenti',
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: ActivityFallbackModeCodes.recordedWithProfileFallback,
                enabled: false,
                child: Text('Registrati, con fallback profilo - prossimamente'),
              ),
              DropdownMenuItem<String>(
                value: ActivityFallbackModeCodes.recordedOnly,
                enabled: false,
                child: Text('Solo dati registrati - prossimamente'),
              ),
              DropdownMenuItem<String>(
                value: ActivityFallbackModeCodes.profileEstimate,
                child: Text('Sempre stima del profilo'),
              ),
            ],
            onChanged: (String? value) {
              if (value == ActivityFallbackModeCodes.profileEstimate) {
                setSheetState(
                  () => _activityFallbackMode =
                      ActivityFallbackModeCodes.profileEstimate,
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_stepGoal, 'Target passi giornaliero',
              keyboardType: TextInputType.number),
          _field(_stepCoeff, 'Kcal attive per passo',
              keyboardType: TextInputType.number),
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
          DropdownButtonFormField<String>(
            initialValue: _weightLossResponse,
            decoration: const InputDecoration(
                labelText: 'Quanto facilmente perdi peso'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: _WeightLossResponseCodes.easy,
                child: Text('Perdo peso facilmente'),
              ),
              DropdownMenuItem<String>(
                value: _WeightLossResponseCodes.standard,
                child: Text('Nella media'),
              ),
              DropdownMenuItem<String>(
                value: _WeightLossResponseCodes.resistant,
                child: Text('Perdo peso con difficoltà'),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setSheetState(() => _weightLossResponse = value);
              }
            },
          ),
        ];
      },
    );
    _finishSheet(profile, saved);
  }

  Future<void> _showMacroSheet(UserProfileEntity profile) async {
    final bool saved = await _showEditorSheet(
      title: 'Macro nutrienti',
      childBuilder: (BuildContext context, StateSetter setSheetState) {
        return <Widget>[
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: MacroModeCodes.defaultByWeight,
                label: Text('Default'),
              ),
              ButtonSegment<String>(
                value: MacroModeCodes.custom,
                label: Text('Custom'),
              ),
            ],
            selected: <String>{_macroMode},
            onSelectionChanged: (Set<String> value) {
              setSheetState(() => _macroMode = value.first);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_proteinKg, 'Proteine g/kg',
              keyboardType: TextInputType.number),
          _field(_fatKg, 'Grassi g/kg', keyboardType: TextInputType.number),
          _field(_fiberKg, 'Fibre g/kg', keyboardType: TextInputType.number),
          const TtAppCard(
            child: Text(
              'I carboidrati vengono calcolati dalle calorie residue dopo proteine (4 kcal/g) e grassi (9 kcal/g), così la somma energetica dei macro coincide con il target calorico.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            _sugarCarbsPercent,
            'Zuccheri % dei carboidrati',
            keyboardType: TextInputType.number,
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
                child: Text('English - prossimamente'),
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
    setState(() => _isApplying = true);
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
          (_toInt(_adaptiveReferenceDays.text) ?? 28).clamp(7, 180);
      profile.sedentaryBaseKcal = 0;
      profile.rmrActivityFactor = 1.10;
      profile.stepKcalCoefficient = _toDouble(_stepCoeff.text) ?? 0.020;
      profile.averageWorkoutsPerWeek = _toInt(_workoutsPerWeek.text) ?? 0;
      profile.averageWorkoutDurationMinutes =
          _toInt(_workoutDuration.text) ?? 0;
      profile.workoutActivityTypeCode = _workoutType;
      profile.activityFallbackModeCode =
          ActivityFallbackModeCodes.profileEstimate;
      profile.macroModeCode = _macroMode;
      profile.proteinGramsPerKg = _toDouble(_proteinKg.text) ?? 2.2;
      profile.fatGramsPerKg = _toDouble(_fatKg.text) ?? 1;
      profile.fiberGramsPerKg = _toDouble(_fiberKg.text) ?? 0.5;
      profile.carbsGramsPerKg = _toDouble(_carbsKg.text) ?? 3;
      profile.sugarCarbsPercent =
          (_toDouble(_sugarCarbsPercent.text) ?? 25).clamp(0, 100).toDouble();
      profile.themeModeCode = _themeMode;
      profile.languageCode = _language;
      profile.kcalPerKg = _kcalPerKgForWeightLossResponse(_weightLossResponse);
      ref.read(userProfileRepositoryProvider).save(profile);
      _recalculateStoredDayTargets(profile);
      ref.invalidate(userProfileRepositoryProvider);
      ref.invalidate(profileSettingsRevisionProvider);
      ref.invalidate(foodHubV01Provider);
      ref.invalidate(foodDaysV01Provider);
      ref.invalidate(foodMealsV01Provider);
      _loaded = false;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo salvato.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  void _recalculateStoredDayTargets(UserProfileEntity profile) {
    final dailyRepository = ref.read(dailyRecordRepositoryProvider);
    final analytics = ref.read(foodAnalyticsServiceProvider);
    final List<DailyRecordEntity> days = dailyRepository.getAllActive();
    for (final DailyRecordEntity day in days) {
      day.stepGoal = profile.defaultStepGoal;
      final TargetDayResult result = analytics.targetResultForDay(
        day: day,
        allDays: days,
        profile: profile,
      );
      analytics.applyTargetSnapshot(day, result);
      dailyRepository.save(day);
    }
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

class _WeightLossResponseCodes {
  const _WeightLossResponseCodes._();

  static const String easy = 'easy';
  static const String standard = 'standard';
  static const String resistant = 'resistant';
}

String _weightLossResponseFromKcalPerKg(double value) {
  if (value <= 7200) {
    return _WeightLossResponseCodes.easy;
  }
  if (value >= 8200) {
    return _WeightLossResponseCodes.resistant;
  }
  return _WeightLossResponseCodes.standard;
}

double _kcalPerKgForWeightLossResponse(String code) {
  return switch (code) {
    _WeightLossResponseCodes.easy => 6900,
    _WeightLossResponseCodes.resistant => 8500,
    _ => 7700,
  };
}

String _weightLossResponseLabel(String code) {
  return switch (code) {
    _WeightLossResponseCodes.easy => 'Perdo peso facilmente',
    _WeightLossResponseCodes.resistant => 'Perdo peso con difficoltà',
    _ => 'Nella media',
  };
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

Widget _field(
  TextEditingController controller,
  String label, {
  TextInputType? keyboardType,
  String? helperText,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
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
    ActivityFallbackModeCodes.profileEstimate => 'Sempre stima profilo',
    _ => 'Registrati con fallback profilo',
  };
}

String _activityFallbackDescription(String code) {
  return switch (code) {
    ActivityFallbackModeCodes.recordedOnly =>
      'Il target usa esclusivamente passi reali e allenamenti completati. '
          'I dati mancanti valgono zero.',
    ActivityFallbackModeCodes.profileEstimate =>
      'Il target usa sempre target passi e allenamenti medi del profilo, '
          'senza sostituirli con i dati del giorno.',
    _ => 'Per oggi e per i giorni futuri usa i dati reali quando presenti; '
        'altrimenti usa target passi e allenamenti medi del profilo. '
        'I giorni passati restano basati solo sui dati registrati.',
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
  return code == MacroModeCodes.custom ? 'Custom' : 'Default per peso';
}

String _themeLabel(String code) {
  return switch (code) {
    ThemePreferenceCodes.light => 'Chiaro',
    ThemePreferenceCodes.dark => 'Scuro',
    _ => 'Sistema',
  };
}
