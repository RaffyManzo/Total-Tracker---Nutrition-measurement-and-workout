import 'dart:convert';
import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/time/clock.dart';
import '../../nutrition/data/entities/ingredient_entity.dart';
import '../../nutrition/data/entities/nutrition_tracking_entities.dart';
import '../../profile/data/entities/user_profile_entity.dart';
import '../../workout/data/entities/exercise_entity.dart';
import '../../workout/data/entities/exercise_muscle_link_entity.dart';
import '../../workout/data/entities/muscle_entity.dart';
import '../../workout/data/entities/workout_tracking_entities.dart';
import '../domain/transfer_models.dart';

class TotalTrackerTransferService {
  TotalTrackerTransferService(
    this._store, {
    Clock clock = const Clock(),
    Uuid uuid = const Uuid(),
    TransferArchiveCodec codec = const TransferArchiveCodec(),
  })  : _clock = clock,
        _uuid = uuid,
        _codec = codec;

  final Store _store;
  final Clock _clock;
  final Uuid _uuid;
  final TransferArchiveCodec _codec;

  Future<String> resolveDefaultExportDirectory() async {
    final Directory? downloads = await getDownloadsDirectory();
    if (downloads != null) {
      final Directory target = Directory(
        p.join(downloads.path, 'Total Tracker'),
      );
      if (await isWritableDirectory(target.path)) {
        return target.path;
      }
    }
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory target = Directory(
      p.join(documents.path, 'Total Tracker', 'exports'),
    );
    await target.create(recursive: true);
    return target.path;
  }

  Future<bool> isWritableDirectory(String path) async {
    final String normalized = path.trim();
    if (normalized.isEmpty) {
      return false;
    }
    try {
      final Directory directory = Directory(normalized);
      await directory.create(recursive: true);
      final File probe = File(
        p.join(
          directory.path,
          '.total_tracker_write_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }

  Future<TransferExportResult> exportArchive({
    required TransferExportOptions options,
    required String directoryPath,
  }) async {
    if (options.isEmpty) {
      throw const FormatException(
          'Seleziona almeno una categoria da esportare.');
    }
    if (!await isWritableDirectory(directoryPath)) {
      throw FileSystemException(
        'La cartella di esportazione non e accessibile.',
        directoryPath,
      );
    }

    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final Map<String, dynamic> data = _store.runInTransaction(
      TxMode.read,
      () => _buildExportData(options),
    );
    final Map<String, int> counts = _countExportData(data);
    final DateTime now = DateTime.now().toUtc();
    final Map<String, dynamic> manifest = <String, dynamic>{
      'format': totalTrackerArchiveFormat,
      'formatVersion': totalTrackerArchiveVersion,
      'appVersion': packageInfo.version,
      'appBuild': packageInfo.buildNumber,
      'createdAt': now.toIso8601String(),
      'areas': options.areaCodes,
      'counts': counts,
    };
    final List<int> bytes = _codec.encode(
      TransferArchivePayload(manifest: manifest, data: data),
    );
    final String timestamp =
        now.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final String filePath = p.join(
      directoryPath,
      'total-tracker-$timestamp.totaltracker',
    );
    final File file = File(filePath);
    final File temporaryFile = File('$filePath.part');
    try {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      await temporaryFile.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await temporaryFile.rename(filePath);
    } on Object {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      rethrow;
    }
    return TransferExportResult(
      path: file.path,
      counts: counts,
      bytes: bytes.length,
    );
  }

  Future<TransferImportAnalysis> analyzeImport(String sourcePath) async {
    final File file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException(
          'File di importazione non trovato.', sourcePath);
    }
    final int archiveLength = await file.length();
    if (archiveLength <= 0 ||
        archiveLength > totalTrackerMaxCompressedArchiveBytes) {
      throw const FormatException(
        'Dimensione archivio non valida o superiore al limite consentito.',
      );
    }
    final List<int> archiveBytes = await file.readAsBytes();
    final TransferArchivePayload payload = _codec.decode(archiveBytes);
    return _store.runInTransaction(
      TxMode.read,
      () => _buildImportAnalysis(sourcePath, payload),
    );
  }

  TransferImportResult applyImport(TransferImportAnalysis analysis) {
    int created = 0;
    int updated = 0;
    int skipped = 0;

    _store.runInTransaction(TxMode.write, () {
      for (final TransferImportSection section in analysis.sections) {
        for (final TransferImportItem item in section.items) {
          if (!item.selected ||
              item.resolution == TransferConflictResolution.keepExisting) {
            skipped += 1;
            continue;
          }
          final bool wasUpdated = _importItem(section.code, item);
          if (wasUpdated) {
            updated += 1;
          } else {
            created += 1;
          }
        }
      }
    });

    return TransferImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
    );
  }

  Map<String, dynamic> _buildExportData(TransferExportOptions options) {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (options.includeProfile) {
      final List<UserProfileEntity> profiles = _store
          .box<UserProfileEntity>()
          .getAll()
          .where((UserProfileEntity item) =>
              item.isActive && item.deletedAtEpochMs == null)
          .toList();
      if (profiles.isNotEmpty) {
        data['profile'] = _profileToMap(profiles.first);
      }
    }
    if (options.includeFood) {
      data.addAll(_buildFoodExportData());
    }
    if (options.includeWorkout) {
      data.addAll(_buildWorkoutExportData());
    }
    return data;
  }

  Map<String, dynamic> _buildFoodExportData() {
    final Box<IngredientEntity> ingredientBox = _store.box<IngredientEntity>();
    final Box<DailyRecordEntity> dayBox = _store.box<DailyRecordEntity>();
    final Box<MealEntity> mealBox = _store.box<MealEntity>();
    final Box<MealItemEntity> mealItemBox = _store.box<MealItemEntity>();
    final Box<RecipeEntity> recipeBox = _store.box<RecipeEntity>();
    final Box<RecipeIngredientEntity> recipeIngredientBox =
        _store.box<RecipeIngredientEntity>();
    final Box<RecipeStepEntity> recipeStepBox = _store.box<RecipeStepEntity>();
    final Box<ScaleMeasurementEntity> scaleBox =
        _store.box<ScaleMeasurementEntity>();
    final Box<TapeMeasurementEntity> tapeBox =
        _store.box<TapeMeasurementEntity>();
    final Box<TapeMeasurementEntryEntity> tapeEntryBox =
        _store.box<TapeMeasurementEntryEntity>();

    final List<IngredientEntity> ingredients = ingredientBox
        .getAll()
        .where((IngredientEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<RecipeEntity> recipes = recipeBox
        .getAll()
        .where((RecipeEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<DailyRecordEntity> days = dayBox
        .getAll()
        .where((DailyRecordEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final Map<int, DailyRecordEntity> daysById = <int, DailyRecordEntity>{
      for (final DailyRecordEntity item in days) item.id: item,
    };
    final List<MealEntity> meals = mealBox
        .getAll()
        .where((MealEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<ScaleMeasurementEntity> scales = scaleBox
        .getAll()
        .where((ScaleMeasurementEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<TapeMeasurementEntity> tapes = tapeBox
        .getAll()
        .where((TapeMeasurementEntity item) => item.deletedAtEpochMs == null)
        .toList();

    return <String, dynamic>{
      'ingredients': <Map<String, dynamic>>[
        for (final IngredientEntity item in ingredients) _ingredientToMap(item),
      ],
      'recipes': <Map<String, dynamic>>[
        for (final RecipeEntity item in recipes)
          <String, dynamic>{
            ..._recipeToMap(item),
            'ingredients': <Map<String, dynamic>>[
              for (final RecipeIngredientEntity child in recipeIngredientBox
                  .getAll()
                  .where((RecipeIngredientEntity child) =>
                      child.recipe.targetId == item.id &&
                      child.deletedAtEpochMs == null)
                  .toList()
                ..sort((RecipeIngredientEntity a, RecipeIngredientEntity b) =>
                    a.position.compareTo(b.position)))
                _recipeIngredientToMap(child),
            ],
            'steps': <Map<String, dynamic>>[
              for (final RecipeStepEntity child in recipeStepBox
                  .getAll()
                  .where((RecipeStepEntity child) =>
                      child.recipe.targetId == item.id &&
                      child.deletedAtEpochMs == null)
                  .toList()
                ..sort((RecipeStepEntity a, RecipeStepEntity b) =>
                    a.position.compareTo(b.position)))
                _recipeStepToMap(child),
            ],
          },
      ],
      'days': <Map<String, dynamic>>[
        for (final DailyRecordEntity item in days) _dayToMap(item),
      ],
      'meals': <Map<String, dynamic>>[
        for (final MealEntity item in meals)
          <String, dynamic>{
            ..._mealToMap(item),
            'dailyRecordUuid': daysById[item.dailyRecord.targetId]?.uuid ?? '',
            'items': <Map<String, dynamic>>[
              for (final MealItemEntity child in mealItemBox
                  .getAll()
                  .where((MealItemEntity child) =>
                      child.meal.targetId == item.id &&
                      child.deletedAtEpochMs == null)
                  .toList()
                ..sort((MealItemEntity a, MealItemEntity b) =>
                    a.position.compareTo(b.position)))
                _mealItemToMap(child),
            ],
          },
      ],
      'scaleMeasurements': <Map<String, dynamic>>[
        for (final ScaleMeasurementEntity item in scales) _scaleToMap(item),
      ],
      'tapeMeasurements': <Map<String, dynamic>>[
        for (final TapeMeasurementEntity item in tapes)
          <String, dynamic>{
            ..._tapeToMap(item),
            'entries': <Map<String, dynamic>>[
              for (final TapeMeasurementEntryEntity child in tapeEntryBox
                  .getAll()
                  .where((TapeMeasurementEntryEntity child) =>
                      child.tapeMeasurement.targetId == item.id &&
                      child.deletedAtEpochMs == null)
                  .toList()
                ..sort((TapeMeasurementEntryEntity a,
                        TapeMeasurementEntryEntity b) =>
                    a.position.compareTo(b.position)))
                _tapeEntryToMap(child),
            ],
          },
      ],
    };
  }

  Map<String, dynamic> _buildWorkoutExportData() {
    final Box<MuscleEntity> muscleBox = _store.box<MuscleEntity>();
    final Box<ExerciseEntity> exerciseBox = _store.box<ExerciseEntity>();
    final Box<ExerciseMuscleLinkEntity> linkBox =
        _store.box<ExerciseMuscleLinkEntity>();
    final Box<RoutineEntity> routineBox = _store.box<RoutineEntity>();
    final Box<RoutineExerciseEntity> routineExerciseBox =
        _store.box<RoutineExerciseEntity>();
    final Box<RoutineSetTemplateEntity> routineSetBox =
        _store.box<RoutineSetTemplateEntity>();
    final Box<WorkoutPlanEntity> planBox = _store.box<WorkoutPlanEntity>();
    final Box<WorkoutPlanDayEntity> planDayBox =
        _store.box<WorkoutPlanDayEntity>();
    final Box<WorkoutPlanExerciseEntity> planExerciseBox =
        _store.box<WorkoutPlanExerciseEntity>();
    final Box<WorkoutSessionEntity> sessionBox =
        _store.box<WorkoutSessionEntity>();
    final Box<SessionExerciseEntity> sessionExerciseBox =
        _store.box<SessionExerciseEntity>();
    final Box<SessionSetEntity> sessionSetBox = _store.box<SessionSetEntity>();

    final Map<int, MuscleEntity> musclesById = <int, MuscleEntity>{
      for (final MuscleEntity item in muscleBox.getAll()) item.id: item,
    };
    final List<ExerciseEntity> exercises = exerciseBox
        .getAll()
        .where((ExerciseEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<RoutineEntity> routines = routineBox
        .getAll()
        .where((RoutineEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<WorkoutPlanEntity> plans = planBox
        .getAll()
        .where((WorkoutPlanEntity item) => item.deletedAtEpochMs == null)
        .toList();
    final List<WorkoutSessionEntity> sessions = sessionBox
        .getAll()
        .where((WorkoutSessionEntity item) => item.deletedAtEpochMs == null)
        .toList();

    return <String, dynamic>{
      'muscles': <Map<String, dynamic>>[
        for (final MuscleEntity item in muscleBox.getAll()) _muscleToMap(item),
      ],
      'exercises': <Map<String, dynamic>>[
        for (final ExerciseEntity item in exercises)
          <String, dynamic>{
            ..._exerciseToMap(item),
            'muscles': <Map<String, dynamic>>[
              for (final ExerciseMuscleLinkEntity link in linkBox
                  .getAll()
                  .where((ExerciseMuscleLinkEntity link) =>
                      link.exercise.targetId == item.id &&
                      link.deletedAtEpochMs == null)
                  .toList()
                ..sort(
                    (ExerciseMuscleLinkEntity a, ExerciseMuscleLinkEntity b) =>
                        a.position.compareTo(b.position)))
                <String, dynamic>{
                  'uuid': link.uuid,
                  'muscleCode': musclesById[link.muscle.targetId]?.code ?? '',
                  'roleCode': link.roleCode,
                  'position': link.position,
                },
            ],
          },
      ],
      'routines': <Map<String, dynamic>>[
        for (final RoutineEntity item in routines)
          <String, dynamic>{
            ..._routineToMap(item),
            'exercises': <Map<String, dynamic>>[
              for (final RoutineExerciseEntity child in routineExerciseBox
                  .getAll()
                  .where((RoutineExerciseEntity child) =>
                      child.routine.targetId == item.id &&
                      child.deletedAtEpochMs == null)
                  .toList()
                ..sort((RoutineExerciseEntity a, RoutineExerciseEntity b) =>
                    a.position.compareTo(b.position)))
                <String, dynamic>{
                  ..._routineExerciseToMap(child),
                  'sets': <Map<String, dynamic>>[
                    for (final RoutineSetTemplateEntity set in routineSetBox
                        .getAll()
                        .where((RoutineSetTemplateEntity set) =>
                            set.routineExercise.targetId == child.id &&
                            set.deletedAtEpochMs == null)
                        .toList()
                      ..sort((RoutineSetTemplateEntity a,
                              RoutineSetTemplateEntity b) =>
                          a.position.compareTo(b.position)))
                      _routineSetToMap(set),
                  ],
                },
            ],
          },
      ],
      'workoutPlans': <Map<String, dynamic>>[
        for (final WorkoutPlanEntity item in plans)
          <String, dynamic>{
            ..._planToMap(item),
            'days': <Map<String, dynamic>>[
              for (final WorkoutPlanDayEntity day in planDayBox
                  .getAll()
                  .where((WorkoutPlanDayEntity day) =>
                      day.workoutPlan.targetId == item.id &&
                      day.deletedAtEpochMs == null)
                  .toList()
                ..sort((WorkoutPlanDayEntity a, WorkoutPlanDayEntity b) =>
                    a.position.compareTo(b.position)))
                <String, dynamic>{
                  ..._planDayToMap(day),
                  'exercises': <Map<String, dynamic>>[
                    for (final WorkoutPlanExerciseEntity exercise
                        in planExerciseBox
                            .getAll()
                            .where((WorkoutPlanExerciseEntity exercise) =>
                                exercise.workoutPlanDay.targetId == day.id &&
                                exercise.deletedAtEpochMs == null)
                            .toList()
                          ..sort((WorkoutPlanExerciseEntity a,
                                  WorkoutPlanExerciseEntity b) =>
                              a.position.compareTo(b.position)))
                      _planExerciseToMap(exercise),
                  ],
                },
            ],
          },
      ],
      'workoutSessions': <Map<String, dynamic>>[
        for (final WorkoutSessionEntity item in sessions)
          <String, dynamic>{
            ..._sessionToMap(item),
            'exercises': <Map<String, dynamic>>[
              for (final SessionExerciseEntity exercise in sessionExerciseBox
                  .getAll()
                  .where((SessionExerciseEntity exercise) =>
                      exercise.workoutSession.targetId == item.id &&
                      exercise.deletedAtEpochMs == null)
                  .toList()
                ..sort((SessionExerciseEntity a, SessionExerciseEntity b) =>
                    a.position.compareTo(b.position)))
                <String, dynamic>{
                  ..._sessionExerciseToMap(exercise),
                  'sets': <Map<String, dynamic>>[
                    for (final SessionSetEntity set in sessionSetBox
                        .getAll()
                        .where((SessionSetEntity set) =>
                            set.sessionExercise.targetId == exercise.id &&
                            set.deletedAtEpochMs == null)
                        .toList()
                      ..sort((SessionSetEntity a, SessionSetEntity b) =>
                          a.position.compareTo(b.position)))
                      _sessionSetToMap(set),
                  ],
                },
            ],
          },
      ],
    };
  }

  Map<String, int> _countExportData(Map<String, dynamic> data) {
    final Map<String, int> counts = <String, int>{};
    for (final MapEntry<String, dynamic> entry in data.entries) {
      if (entry.value is List) {
        counts[entry.key] = (entry.value as List).length;
      } else if (entry.value is Map) {
        counts[entry.key] = 1;
      }
    }
    return counts;
  }

  TransferImportAnalysis _buildImportAnalysis(
    String sourcePath,
    TransferArchivePayload payload,
  ) {
    final List<TransferImportSection> sections = <TransferImportSection>[];
    final List<String> warnings = <String>[];
    final Map<String, dynamic> data = payload.data;

    final Map<String, dynamic>? profile = _mapOrNull(data['profile']);
    if (profile != null) {
      sections.add(_profileSection(profile));
    }

    _appendSection(
      sections,
      code: 'ingredients',
      title: 'Ingredienti',
      description: 'Alimenti e relativi valori nutrizionali.',
      rawItems: _mapList(data['ingredients']),
      conflictResolver: _ingredientConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['name']),
      subtitleResolver: (Map<String, dynamic> item) => <String>[
        _s(item['brand']),
        if (_s(item['barcode']).isNotEmpty) 'barcode ${_s(item['barcode'])}',
      ].where((String value) => value.isNotEmpty).join(' · '),
    );
    _appendSection(
      sections,
      code: 'recipes',
      title: 'Ricette',
      description: 'Ricette, ingredienti collegati e procedimento.',
      rawItems: _mapList(data['recipes']),
      conflictResolver: _recipeConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['title']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_mapList(item['ingredients']).length} ingredienti · ${_mapList(item['steps']).length} passaggi',
    );
    _appendSection(
      sections,
      code: 'days',
      title: 'Giornate',
      description: 'Dati quotidiani, target, passi e sonno.',
      rawItems: _mapList(data['days']),
      conflictResolver: _dayConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['dateKey']),
      subtitleResolver: (Map<String, dynamic> item) => _s(item['weekdayLabel']),
    );
    _appendSection(
      sections,
      code: 'meals',
      title: 'Pasti',
      description: 'Pasti e voci alimentari associate.',
      rawItems: _mapList(data['meals']),
      conflictResolver: _mealConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['title']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_s(item['dateKey'])} · ${_s(item['mealTypeCode'])} · ${_mapList(item['items']).length} voci',
    );
    _appendSection(
      sections,
      code: 'scaleMeasurements',
      title: 'Misure bilancia',
      description: 'Peso e composizione corporea.',
      rawItems: _mapList(data['scaleMeasurements']),
      conflictResolver: _scaleConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['dateKey']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_s(item['weightKg'])} kg · ${_s(item['reliabilityCode'])}',
    );
    _appendSection(
      sections,
      code: 'tapeMeasurements',
      title: 'Misure metro',
      description: 'Circonferenze corporee e singole aree.',
      rawItems: _mapList(data['tapeMeasurements']),
      conflictResolver: _tapeConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['dateKey']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_mapList(item['entries']).length} misure',
    );
    _appendSection(
      sections,
      code: 'muscles',
      title: 'Catalogo muscoli',
      description: 'Catalogo usato dagli esercizi.',
      rawItems: _mapList(data['muscles']),
      conflictResolver: _muscleConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['displayNameIt']),
      subtitleResolver: (Map<String, dynamic> item) => _s(item['code']),
    );
    _appendSection(
      sections,
      code: 'exercises',
      title: 'Esercizi',
      description: 'Esercizi e associazioni muscolari.',
      rawItems: _mapList(data['exercises']),
      conflictResolver: _exerciseConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['name']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_s(item['exerciseModeCode'])} · ${_mapList(item['muscles']).length} muscoli',
    );
    _appendSection(
      sections,
      code: 'routines',
      title: 'Routine',
      description: 'Routine, esercizi e serie programmate.',
      rawItems: _mapList(data['routines']),
      conflictResolver: _routineConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['name']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_mapList(item['exercises']).length} esercizi',
    );
    _appendSection(
      sections,
      code: 'workoutPlans',
      title: 'Schede allenamento',
      description: 'Schede, giornate ed esercizi.',
      rawItems: _mapList(data['workoutPlans']),
      conflictResolver: _planConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['name']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_mapList(item['days']).length} giornate',
    );
    _appendSection(
      sections,
      code: 'workoutSessions',
      title: 'Sessioni',
      description: 'Sessioni svolte e dettaglio delle serie.',
      rawItems: _mapList(data['workoutSessions']),
      conflictResolver: _sessionConflict,
      titleResolver: (Map<String, dynamic> item) => _s(item['title']),
      subtitleResolver: (Map<String, dynamic> item) =>
          '${_s(item['sessionDateKey'])} · ${_mapList(item['exercises']).length} esercizi',
    );

    if (sections.isEmpty) {
      warnings
          .add('L archivio e valido ma non contiene categorie importabili.');
    }
    return TransferImportAnalysis(
      sourcePath: sourcePath,
      manifest: payload.manifest,
      sections: sections,
      warnings: warnings,
    );
  }

  TransferImportSection _profileSection(Map<String, dynamic> profile) {
    const Map<String, String> labels = <String, String>{
      'displayName': 'Nome profilo',
      'birthDateEpochDay': 'Data di nascita',
      'biologicalSexCode': 'Sesso biologico',
      'heightCm': 'Altezza',
      'initialWeightKg': 'Peso iniziale',
      'defaultStepGoal': 'Target passi',
      'defaultTargetKcal': 'Target calorico',
      'targetModeCode': 'Modalita target',
      'sedentaryBaseKcal': 'Base sedentaria',
      'averageWorkoutsPerWeek': 'Allenamenti medi',
      'averageWorkoutDurationMinutes': 'Durata allenamento media',
      'workoutActivityTypeCode': 'Tipo allenamento',
      'activityFallbackModeCode': 'Fallback attivita',
      'macroModeCode': 'Modalita macro',
      'mealTargetModeCode': 'Modalita target pasti',
      'mealTargetsJson': 'Distribuzione pasti',
      'proteinGramsPerKg': 'Proteine per kg',
      'fatGramsPerKg': 'Grassi per kg',
      'fiberGramsPerKg': 'Fibre per kg',
      'carbsGramsPerKg': 'Carboidrati per kg',
      'sugarCarbsPercent': 'Percentuale zuccheri',
      'waterGlassLiters': 'Volume bicchiere',
      'stepKcalCoefficient': 'Coefficiente passi',
      'adaptiveReferenceDays': 'Finestra adattiva',
      'adaptiveMinimumObservedDays': 'Giorni minimi osservati',
      'rmrActivityFactor': 'Fattore RMR',
      'kcalPerKg': 'Kcal per kg',
      'minimumReasonableTdee': 'TDEE minimo',
      'maximumReasonableTdee': 'TDEE massimo',
      'themeModeCode': 'Tema',
      'languageCode': 'Lingua',
    };
    final UserProfileEntity? current = _activeProfile();
    final List<TransferImportItem> items = <TransferImportItem>[];
    for (final MapEntry<String, String> entry in labels.entries) {
      if (!profile.containsKey(entry.key)) {
        continue;
      }
      final Object? currentValue =
          current == null ? null : _profileFieldValue(current, entry.key);
      final Object? incomingValue = profile[entry.key];
      final bool conflict = current != null && currentValue != incomingValue;
      items.add(
        TransferImportItem(
          id: 'profile:${entry.key}',
          categoryCode: 'profile',
          title: entry.value,
          subtitle: 'Valore importato: ${_displayValue(incomingValue)}',
          data: <String, dynamic>{
            'field': entry.key,
            'value': incomingValue,
          },
          hasConflict: conflict,
          conflictDescription: conflict
              ? 'Valore locale: ${_displayValue(currentValue)}. Verrà sovrascritto.'
              : '',
        ),
      );
    }
    return TransferImportSection(
      code: 'profile',
      title: 'Profilo',
      description: 'Scegli singolarmente le impostazioni da importare.',
      items: items,
      isProfileSection: true,
    );
  }

  void _appendSection(
    List<TransferImportSection> sections, {
    required String code,
    required String title,
    required String description,
    required List<Map<String, dynamic>> rawItems,
    required String? Function(Map<String, dynamic>) conflictResolver,
    required String Function(Map<String, dynamic>) titleResolver,
    required String Function(Map<String, dynamic>) subtitleResolver,
  }) {
    if (rawItems.isEmpty) {
      return;
    }
    sections.add(
      TransferImportSection(
        code: code,
        title: title,
        description: description,
        items: <TransferImportItem>[
          for (int index = 0; index < rawItems.length; index += 1)
            _buildImportItem(
              code: code,
              index: index,
              data: rawItems[index],
              conflictResolver: conflictResolver,
              titleResolver: titleResolver,
              subtitleResolver: subtitleResolver,
            ),
        ],
      ),
    );
  }

  TransferImportItem _buildImportItem({
    required String code,
    required int index,
    required Map<String, dynamic> data,
    required String? Function(Map<String, dynamic>) conflictResolver,
    required String Function(Map<String, dynamic>) titleResolver,
    required String Function(Map<String, dynamic>) subtitleResolver,
  }) {
    final String? conflict = conflictResolver(data);
    return TransferImportItem(
      id: '$code:$index:${_s(data['uuid'])}',
      categoryCode: code,
      title: titleResolver(data).trim().isEmpty
          ? 'Elemento ${index + 1}'
          : titleResolver(data),
      subtitle: subtitleResolver(data),
      data: data,
      hasConflict: conflict != null,
      conflictDescription: conflict ?? '',
    );
  }

  bool _importItem(String sectionCode, TransferImportItem item) {
    if (sectionCode == 'profile') {
      return _importProfileField(item);
    }
    return switch (sectionCode) {
      'ingredients' => _importIngredient(item),
      'recipes' => _importRecipe(item),
      'days' => _importDay(item),
      'meals' => _importMeal(item),
      'scaleMeasurements' => _importScale(item),
      'tapeMeasurements' => _importTape(item),
      'muscles' => _importMuscle(item),
      'exercises' => _importExercise(item),
      'routines' => _importRoutine(item),
      'workoutPlans' => _importPlan(item),
      'workoutSessions' => _importSession(item),
      _ => false,
    };
  }

  bool _importProfileField(TransferImportItem item) {
    final Box<UserProfileEntity> box = _store.box<UserProfileEntity>();
    UserProfileEntity? profile = _activeProfile();
    final int now = _clock.nowEpochMs();
    final bool existed = profile != null;
    profile ??= UserProfileEntity(
      uuid: _uuid.v4(),
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    final String field = _s(item.data['field']);
    final Object? value = item.data['value'];
    _setProfileField(profile, field, value);
    profile.updatedAtEpochMs = now;
    profile.id = box.put(profile);
    return existed;
  }

  bool _importIngredient(TransferImportItem item) {
    final Box<IngredientEntity> box = _store.box<IngredientEntity>();
    final IngredientEntity? existing = _findIngredient(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final IngredientEntity entity = _ingredientFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    return overwrite;
  }

  bool _importRecipe(TransferImportItem item) {
    final Box<RecipeEntity> box = _store.box<RecipeEntity>();
    final Box<RecipeIngredientEntity> ingredientBox =
        _store.box<RecipeIngredientEntity>();
    final Box<RecipeStepEntity> stepBox = _store.box<RecipeStepEntity>();
    final RecipeEntity? existing = _findRecipe(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final RecipeEntity entity = _recipeFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      ingredientBox.removeMany(ingredientBox
          .getAll()
          .where((RecipeIngredientEntity child) =>
              child.recipe.targetId == entity.id)
          .map((RecipeIngredientEntity child) => child.id)
          .toList());
      stepBox.removeMany(stepBox
          .getAll()
          .where((RecipeStepEntity child) => child.recipe.targetId == entity.id)
          .map((RecipeStepEntity child) => child.id)
          .toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['ingredients'])) {
      final RecipeIngredientEntity child = _recipeIngredientFromMap(raw);
      child.recipe.targetId = entity.id;
      ingredientBox.put(child);
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['steps'])) {
      final RecipeStepEntity child = _recipeStepFromMap(raw);
      child.recipe.targetId = entity.id;
      stepBox.put(child);
    }
    return overwrite;
  }

  bool _importDay(TransferImportItem item) {
    final Box<DailyRecordEntity> box = _store.box<DailyRecordEntity>();
    final DailyRecordEntity? existing = _findDay(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final DailyRecordEntity entity = _dayFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    return overwrite;
  }

  bool _importMeal(TransferImportItem item) {
    final Box<MealEntity> box = _store.box<MealEntity>();
    final Box<MealItemEntity> itemBox = _store.box<MealItemEntity>();
    final MealEntity? existing = _findMeal(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final MealEntity entity = _mealFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    final String dayUuid = _s(item.data['dailyRecordUuid']);
    final DailyRecordEntity? day = _store
        .box<DailyRecordEntity>()
        .getAll()
        .where((DailyRecordEntity candidate) =>
            (dayUuid.isNotEmpty && candidate.uuid == dayUuid) ||
            candidate.dateKey == entity.dateKey)
        .firstOrNull;
    if (day != null) {
      entity.dailyRecord.targetId = day.id;
    }
    entity.id = box.put(entity);
    if (overwrite) {
      itemBox.removeMany(itemBox
          .getAll()
          .where((MealItemEntity child) => child.meal.targetId == entity.id)
          .map((MealItemEntity child) => child.id)
          .toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['items'])) {
      final MealItemEntity child = _mealItemFromMap(raw);
      child.meal.targetId = entity.id;
      itemBox.put(child);
    }
    return overwrite;
  }

  bool _importScale(TransferImportItem item) {
    final Box<ScaleMeasurementEntity> box =
        _store.box<ScaleMeasurementEntity>();
    final ScaleMeasurementEntity? existing = _findScale(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final ScaleMeasurementEntity entity = _scaleFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    return overwrite;
  }

  bool _importTape(TransferImportItem item) {
    final Box<TapeMeasurementEntity> box = _store.box<TapeMeasurementEntity>();
    final Box<TapeMeasurementEntryEntity> entryBox =
        _store.box<TapeMeasurementEntryEntity>();
    final TapeMeasurementEntity? existing = _findTape(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final TapeMeasurementEntity entity = _tapeFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      entryBox.removeMany(entryBox
          .getAll()
          .where((TapeMeasurementEntryEntity child) =>
              child.tapeMeasurement.targetId == entity.id)
          .map((TapeMeasurementEntryEntity child) => child.id)
          .toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['entries'])) {
      final TapeMeasurementEntryEntity child = _tapeEntryFromMap(raw);
      child.tapeMeasurement.targetId = entity.id;
      entryBox.put(child);
    }
    return overwrite;
  }

  bool _importMuscle(TransferImportItem item) {
    final Box<MuscleEntity> box = _store.box<MuscleEntity>();
    final MuscleEntity? existing = _findMuscle(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final Map<String, dynamic> source = <String, dynamic>{...item.data};
    if (existing != null &&
        item.resolution == TransferConflictResolution.importCopy) {
      source['code'] =
          '${_s(item.data['code'])}_imported_${_uuid.v4().substring(0, 8)}';
      source['displayNameIt'] = '${_s(item.data['displayNameIt'])} (copia)';
      source['displayNameEn'] = '${_s(item.data['displayNameEn'])} (copy)';
    }
    final MuscleEntity entity = _muscleFromMap(
      source,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    return overwrite;
  }

  bool _importExercise(TransferImportItem item) {
    final Box<ExerciseEntity> box = _store.box<ExerciseEntity>();
    final Box<ExerciseMuscleLinkEntity> linkBox =
        _store.box<ExerciseMuscleLinkEntity>();
    final ExerciseEntity? existing = _findExercise(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final ExerciseEntity entity = _exerciseFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      linkBox.removeMany(linkBox
          .getAll()
          .where((ExerciseMuscleLinkEntity link) =>
              link.exercise.targetId == entity.id)
          .map((ExerciseMuscleLinkEntity link) => link.id)
          .toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['muscles'])) {
      final MuscleEntity? muscle = _store
          .box<MuscleEntity>()
          .getAll()
          .where((MuscleEntity muscle) =>
              _norm(muscle.code) == _norm(_s(raw['muscleCode'])))
          .firstOrNull;
      if (muscle == null) {
        continue;
      }
      final int now = _clock.nowEpochMs();
      final ExerciseMuscleLinkEntity link = ExerciseMuscleLinkEntity(
        uuid: _uuid.v4(),
        roleCode: _s(raw['roleCode'], 'primary'),
        position: _i(raw['position']),
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      link.exercise.targetId = entity.id;
      link.muscle.targetId = muscle.id;
      linkBox.put(link);
    }
    return overwrite;
  }

  bool _importRoutine(TransferImportItem item) {
    final Box<RoutineEntity> box = _store.box<RoutineEntity>();
    final Box<RoutineExerciseEntity> exerciseBox =
        _store.box<RoutineExerciseEntity>();
    final Box<RoutineSetTemplateEntity> setBox =
        _store.box<RoutineSetTemplateEntity>();
    final RoutineEntity? existing = _findRoutine(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final RoutineEntity entity = _routineFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      final List<RoutineExerciseEntity> old = exerciseBox
          .getAll()
          .where((RoutineExerciseEntity child) =>
              child.routine.targetId == entity.id)
          .toList();
      for (final RoutineExerciseEntity child in old) {
        setBox.removeMany(setBox
            .getAll()
            .where((RoutineSetTemplateEntity set) =>
                set.routineExercise.targetId == child.id)
            .map((RoutineSetTemplateEntity set) => set.id)
            .toList());
      }
      exerciseBox
          .removeMany(old.map((RoutineExerciseEntity e) => e.id).toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['exercises'])) {
      final RoutineExerciseEntity child = _routineExerciseFromMap(raw);
      child.routine.targetId = entity.id;
      child.id = exerciseBox.put(child);
      for (final Map<String, dynamic> setRaw in _mapList(raw['sets'])) {
        final RoutineSetTemplateEntity set = _routineSetFromMap(setRaw);
        set.routineExercise.targetId = child.id;
        setBox.put(set);
      }
    }
    return overwrite;
  }

  bool _importPlan(TransferImportItem item) {
    final Box<WorkoutPlanEntity> box = _store.box<WorkoutPlanEntity>();
    final Box<WorkoutPlanDayEntity> dayBox = _store.box<WorkoutPlanDayEntity>();
    final Box<WorkoutPlanExerciseEntity> exerciseBox =
        _store.box<WorkoutPlanExerciseEntity>();
    final WorkoutPlanEntity? existing = _findPlan(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final WorkoutPlanEntity entity = _planFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      final List<WorkoutPlanDayEntity> old = dayBox
          .getAll()
          .where((WorkoutPlanDayEntity day) =>
              day.workoutPlan.targetId == entity.id)
          .toList();
      for (final WorkoutPlanDayEntity day in old) {
        exerciseBox.removeMany(exerciseBox
            .getAll()
            .where((WorkoutPlanExerciseEntity exercise) =>
                exercise.workoutPlanDay.targetId == day.id)
            .map((WorkoutPlanExerciseEntity exercise) => exercise.id)
            .toList());
      }
      dayBox.removeMany(old.map((WorkoutPlanDayEntity day) => day.id).toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['days'])) {
      final WorkoutPlanDayEntity day = _planDayFromMap(raw);
      day.workoutPlan.targetId = entity.id;
      day.id = dayBox.put(day);
      for (final Map<String, dynamic> exerciseRaw
          in _mapList(raw['exercises'])) {
        final WorkoutPlanExerciseEntity exercise =
            _planExerciseFromMap(exerciseRaw);
        exercise.workoutPlanDay.targetId = day.id;
        exerciseBox.put(exercise);
      }
    }
    return overwrite;
  }

  bool _importSession(TransferImportItem item) {
    final Box<WorkoutSessionEntity> box = _store.box<WorkoutSessionEntity>();
    final Box<SessionExerciseEntity> exerciseBox =
        _store.box<SessionExerciseEntity>();
    final Box<SessionSetEntity> setBox = _store.box<SessionSetEntity>();
    final WorkoutSessionEntity? existing = _findSession(item.data);
    final bool overwrite = existing != null &&
        item.resolution == TransferConflictResolution.overwrite;
    final WorkoutSessionEntity entity = _sessionFromMap(
      item.data,
      id: overwrite ? existing.id : 0,
      uuid: overwrite ? existing.uuid : _importUuid(item.data, item.resolution),
    );
    entity.id = box.put(entity);
    if (overwrite) {
      final List<SessionExerciseEntity> old = exerciseBox
          .getAll()
          .where((SessionExerciseEntity exercise) =>
              exercise.workoutSession.targetId == entity.id)
          .toList();
      for (final SessionExerciseEntity exercise in old) {
        setBox.removeMany(setBox
            .getAll()
            .where((SessionSetEntity set) =>
                set.sessionExercise.targetId == exercise.id)
            .map((SessionSetEntity set) => set.id)
            .toList());
      }
      exerciseBox
          .removeMany(old.map((SessionExerciseEntity e) => e.id).toList());
    }
    for (final Map<String, dynamic> raw in _mapList(item.data['exercises'])) {
      final SessionExerciseEntity exercise = _sessionExerciseFromMap(raw);
      exercise.workoutSession.targetId = entity.id;
      exercise.id = exerciseBox.put(exercise);
      for (final Map<String, dynamic> setRaw in _mapList(raw['sets'])) {
        final SessionSetEntity set = _sessionSetFromMap(setRaw);
        set.sessionExercise.targetId = exercise.id;
        setBox.put(set);
      }
    }
    return overwrite;
  }

  String? _ingredientConflict(Map<String, dynamic> data) {
    final IngredientEntity? existing = _findIngredient(data);
    return existing == null
        ? null
        : 'Esiste gia "${existing.name}". Per impostazione predefinita verra sovrascritto.';
  }

  String? _recipeConflict(Map<String, dynamic> data) {
    final RecipeEntity? existing = _findRecipe(data);
    return existing == null
        ? null
        : 'Esiste gia la ricetta "${existing.title}".';
  }

  String? _dayConflict(Map<String, dynamic> data) {
    final DailyRecordEntity? existing = _findDay(data);
    return existing == null
        ? null
        : 'La giornata ${existing.dateKey} esiste gia.';
  }

  String? _mealConflict(Map<String, dynamic> data) {
    final MealEntity? existing = _findMeal(data);
    return existing == null
        ? null
        : 'Il pasto ${existing.mealTypeCode} del ${existing.dateKey} esiste gia.';
  }

  String? _scaleConflict(Map<String, dynamic> data) {
    final ScaleMeasurementEntity? existing = _findScale(data);
    return existing == null
        ? null
        : 'Esiste gia una misura bilancia per ${existing.dateKey}.';
  }

  String? _tapeConflict(Map<String, dynamic> data) {
    final TapeMeasurementEntity? existing = _findTape(data);
    return existing == null
        ? null
        : 'Esiste gia una misura metro per ${existing.dateKey}.';
  }

  String? _muscleConflict(Map<String, dynamic> data) {
    final MuscleEntity? existing = _findMuscle(data);
    return existing == null ? null : 'Il muscolo ${existing.code} esiste gia.';
  }

  String? _exerciseConflict(Map<String, dynamic> data) {
    final ExerciseEntity? existing = _findExercise(data);
    return existing == null
        ? null
        : 'L esercizio "${existing.name}" esiste gia.';
  }

  String? _routineConflict(Map<String, dynamic> data) {
    final RoutineEntity? existing = _findRoutine(data);
    return existing == null
        ? null
        : 'La routine "${existing.name}" esiste gia.';
  }

  String? _planConflict(Map<String, dynamic> data) {
    final WorkoutPlanEntity? existing = _findPlan(data);
    return existing == null ? null : 'La scheda "${existing.name}" esiste gia.';
  }

  String? _sessionConflict(Map<String, dynamic> data) {
    final WorkoutSessionEntity? existing = _findSession(data);
    return existing == null
        ? null
        : 'La sessione "${existing.title}" del ${existing.sessionDateKey} esiste gia.';
  }

  UserProfileEntity? _activeProfile() => _store
      .box<UserProfileEntity>()
      .getAll()
      .where((UserProfileEntity item) =>
          item.isActive && item.deletedAtEpochMs == null)
      .firstOrNull;

  IngredientEntity? _findIngredient(Map<String, dynamic> data) {
    final String uuid = _s(data['uuid']);
    final String barcode = _norm(_s(data['barcode']));
    final String key = '${_norm(_s(data['name']))}|${_norm(_s(data['brand']))}';
    return _store
        .box<IngredientEntity>()
        .getAll()
        .where((IngredientEntity item) {
      if (item.deletedAtEpochMs != null) return false;
      if (uuid.isNotEmpty && item.uuid == uuid) return true;
      if (barcode.isNotEmpty && _norm(item.barcode) == barcode) return true;
      return '${_norm(item.name)}|${_norm(item.brand)}' == key;
    }).firstOrNull;
  }

  RecipeEntity? _findRecipe(Map<String, dynamic> data) => _store
      .box<RecipeEntity>()
      .getAll()
      .where((RecipeEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              _norm(item.title) == _norm(_s(data['title']))))
      .firstOrNull;

  DailyRecordEntity? _findDay(Map<String, dynamic> data) => _store
      .box<DailyRecordEntity>()
      .getAll()
      .where((DailyRecordEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              item.dateKey == _s(data['dateKey'])))
      .firstOrNull;

  MealEntity? _findMeal(Map<String, dynamic> data) => _store
      .box<MealEntity>()
      .getAll()
      .where((MealEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              (item.dateKey == _s(data['dateKey']) &&
                  item.mealTypeCode == _s(data['mealTypeCode']))))
      .firstOrNull;

  ScaleMeasurementEntity? _findScale(Map<String, dynamic> data) => _store
      .box<ScaleMeasurementEntity>()
      .getAll()
      .where((ScaleMeasurementEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              (item.dateKey == _s(data['dateKey']) &&
                  item.measurementTime == _s(data['measurementTime']))))
      .firstOrNull;

  TapeMeasurementEntity? _findTape(Map<String, dynamic> data) => _store
      .box<TapeMeasurementEntity>()
      .getAll()
      .where((TapeMeasurementEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              (item.dateKey == _s(data['dateKey']) &&
                  item.measurementTime == _s(data['measurementTime']))))
      .firstOrNull;

  MuscleEntity? _findMuscle(Map<String, dynamic> data) => _store
      .box<MuscleEntity>()
      .getAll()
      .where((MuscleEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              _norm(item.code) == _norm(_s(data['code']))))
      .firstOrNull;

  ExerciseEntity? _findExercise(Map<String, dynamic> data) => _store
      .box<ExerciseEntity>()
      .getAll()
      .where((ExerciseEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              _norm(item.name) == _norm(_s(data['name']))))
      .firstOrNull;

  RoutineEntity? _findRoutine(Map<String, dynamic> data) => _store
      .box<RoutineEntity>()
      .getAll()
      .where((RoutineEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              _norm(item.name) == _norm(_s(data['name']))))
      .firstOrNull;

  WorkoutPlanEntity? _findPlan(Map<String, dynamic> data) => _store
      .box<WorkoutPlanEntity>()
      .getAll()
      .where((WorkoutPlanEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              _norm(item.name) == _norm(_s(data['name']))))
      .firstOrNull;

  WorkoutSessionEntity? _findSession(Map<String, dynamic> data) => _store
      .box<WorkoutSessionEntity>()
      .getAll()
      .where((WorkoutSessionEntity item) =>
          item.deletedAtEpochMs == null &&
          ((_s(data['uuid']).isNotEmpty && item.uuid == _s(data['uuid'])) ||
              (item.sessionDateKey == _s(data['sessionDateKey']) &&
                  _norm(item.title) == _norm(_s(data['title'])))))
      .firstOrNull;

  String _importUuid(
    Map<String, dynamic> data,
    TransferConflictResolution resolution,
  ) {
    if (resolution == TransferConflictResolution.importCopy) {
      return _uuid.v4();
    }
    final String incoming = _s(data['uuid']);
    return incoming.isEmpty ? _uuid.v4() : incoming;
  }

  // Serialization helpers. ObjectBox ids and device-local paths are excluded.
  Map<String, dynamic> _profileToMap(UserProfileEntity x) => <String, dynamic>{
        'displayName': x.displayName,
        'birthDateEpochDay': x.birthDateEpochDay,
        'biologicalSexCode': x.biologicalSexCode,
        'heightCm': x.heightCm,
        'initialWeightKg': x.initialWeightKg,
        'defaultStepGoal': x.defaultStepGoal,
        'defaultTargetKcal': x.defaultTargetKcal,
        'targetModeCode': x.targetModeCode,
        'sedentaryBaseKcal': x.sedentaryBaseKcal,
        'averageWorkoutsPerWeek': x.averageWorkoutsPerWeek,
        'averageWorkoutDurationMinutes': x.averageWorkoutDurationMinutes,
        'workoutActivityTypeCode': x.workoutActivityTypeCode,
        'activityFallbackModeCode': x.activityFallbackModeCode,
        'macroModeCode': x.macroModeCode,
        'mealTargetModeCode': x.mealTargetModeCode,
        'mealTargetsJson': x.mealTargetsJson,
        'proteinGramsPerKg': x.proteinGramsPerKg,
        'fatGramsPerKg': x.fatGramsPerKg,
        'fiberGramsPerKg': x.fiberGramsPerKg,
        'carbsGramsPerKg': x.carbsGramsPerKg,
        'sugarCarbsPercent': x.sugarCarbsPercent,
        'waterGlassLiters': x.waterGlassLiters,
        'stepKcalCoefficient': x.stepKcalCoefficient,
        'adaptiveReferenceDays': x.adaptiveReferenceDays,
        'adaptiveMinimumObservedDays': x.adaptiveMinimumObservedDays,
        'rmrActivityFactor': x.rmrActivityFactor,
        'kcalPerKg': x.kcalPerKg,
        'minimumReasonableTdee': x.minimumReasonableTdee,
        'maximumReasonableTdee': x.maximumReasonableTdee,
        'themeModeCode': x.themeModeCode,
        'languageCode': x.languageCode,
      };

  Object? _profileFieldValue(UserProfileEntity x, String field) =>
      switch (field) {
        'displayName' => x.displayName,
        'birthDateEpochDay' => x.birthDateEpochDay,
        'biologicalSexCode' => x.biologicalSexCode,
        'heightCm' => x.heightCm,
        'initialWeightKg' => x.initialWeightKg,
        'defaultStepGoal' => x.defaultStepGoal,
        'defaultTargetKcal' => x.defaultTargetKcal,
        'targetModeCode' => x.targetModeCode,
        'sedentaryBaseKcal' => x.sedentaryBaseKcal,
        'averageWorkoutsPerWeek' => x.averageWorkoutsPerWeek,
        'averageWorkoutDurationMinutes' => x.averageWorkoutDurationMinutes,
        'workoutActivityTypeCode' => x.workoutActivityTypeCode,
        'activityFallbackModeCode' => x.activityFallbackModeCode,
        'macroModeCode' => x.macroModeCode,
        'mealTargetModeCode' => x.mealTargetModeCode,
        'mealTargetsJson' => x.mealTargetsJson,
        'proteinGramsPerKg' => x.proteinGramsPerKg,
        'fatGramsPerKg' => x.fatGramsPerKg,
        'fiberGramsPerKg' => x.fiberGramsPerKg,
        'carbsGramsPerKg' => x.carbsGramsPerKg,
        'sugarCarbsPercent' => x.sugarCarbsPercent,
        'waterGlassLiters' => x.waterGlassLiters,
        'stepKcalCoefficient' => x.stepKcalCoefficient,
        'adaptiveReferenceDays' => x.adaptiveReferenceDays,
        'adaptiveMinimumObservedDays' => x.adaptiveMinimumObservedDays,
        'rmrActivityFactor' => x.rmrActivityFactor,
        'kcalPerKg' => x.kcalPerKg,
        'minimumReasonableTdee' => x.minimumReasonableTdee,
        'maximumReasonableTdee' => x.maximumReasonableTdee,
        'themeModeCode' => x.themeModeCode,
        'languageCode' => x.languageCode,
        _ => null,
      };

  void _setProfileField(UserProfileEntity x, String field, Object? value) {
    switch (field) {
      case 'displayName':
        x.displayName = _s(value);
        break;
      case 'birthDateEpochDay':
        x.birthDateEpochDay = _ni(value);
        break;
      case 'biologicalSexCode':
        x.biologicalSexCode = _s(value);
        break;
      case 'heightCm':
        x.heightCm = _nd(value);
        break;
      case 'initialWeightKg':
        x.initialWeightKg = _nd(value);
        break;
      case 'defaultStepGoal':
        x.defaultStepGoal = _i(value);
        break;
      case 'defaultTargetKcal':
        x.defaultTargetKcal = _i(value);
        break;
      case 'targetModeCode':
        x.targetModeCode = _s(value);
        break;
      case 'sedentaryBaseKcal':
        x.sedentaryBaseKcal = _d(value);
        break;
      case 'averageWorkoutsPerWeek':
        x.averageWorkoutsPerWeek = _i(value);
        break;
      case 'averageWorkoutDurationMinutes':
        x.averageWorkoutDurationMinutes = _i(value);
        break;
      case 'workoutActivityTypeCode':
        x.workoutActivityTypeCode = _s(value);
        break;
      case 'activityFallbackModeCode':
        x.activityFallbackModeCode = _s(value);
        break;
      case 'macroModeCode':
        x.macroModeCode = _s(value);
        break;
      case 'mealTargetModeCode':
        x.mealTargetModeCode = _s(value);
        break;
      case 'mealTargetsJson':
        x.mealTargetsJson = _s(value);
        break;
      case 'proteinGramsPerKg':
        x.proteinGramsPerKg = _d(value);
        break;
      case 'fatGramsPerKg':
        x.fatGramsPerKg = _d(value);
        break;
      case 'fiberGramsPerKg':
        x.fiberGramsPerKg = _d(value);
        break;
      case 'carbsGramsPerKg':
        x.carbsGramsPerKg = _d(value);
        break;
      case 'sugarCarbsPercent':
        x.sugarCarbsPercent = _d(value);
        break;
      case 'waterGlassLiters':
        x.waterGlassLiters = _d(value);
        break;
      case 'stepKcalCoefficient':
        x.stepKcalCoefficient = _d(value);
        break;
      case 'adaptiveReferenceDays':
        x.adaptiveReferenceDays = _i(value);
        break;
      case 'adaptiveMinimumObservedDays':
        x.adaptiveMinimumObservedDays = _i(value);
        break;
      case 'rmrActivityFactor':
        x.rmrActivityFactor = _d(value);
        break;
      case 'kcalPerKg':
        x.kcalPerKg = _d(value);
        break;
      case 'minimumReasonableTdee':
        x.minimumReasonableTdee = _d(value);
        break;
      case 'maximumReasonableTdee':
        x.maximumReasonableTdee = _d(value);
        break;
      case 'themeModeCode':
        x.themeModeCode = _s(value);
        break;
      case 'languageCode':
        x.languageCode = _s(value);
        break;
    }
  }

  Map<String, dynamic> _ingredientToMap(IngredientEntity x) =>
      <String, dynamic>{
        'uuid': x.uuid,
        'name': x.name,
        'brand': x.brand,
        'baseUnit': x.baseUnit,
        'barcode': x.barcode,
        'packageQuantity': x.packageQuantity,
        'sourceTypeCode': x.sourceTypeCode,
        'sourceName': x.sourceName,
        'sourceUrl': x.sourceUrl,
        'imageUrl': x.imageUrl,
        'categories': x.categories,
        'notes': x.notes,
        'nutritionReferenceAmount': x.nutritionReferenceAmount,
        'nutritionReferenceUnitCode': x.nutritionReferenceUnitCode,
        'kcalPerReference': x.kcalPerReference,
        'proteinPerReference': x.proteinPerReference,
        'carbsPerReference': x.carbsPerReference,
        'fatPerReference': x.fatPerReference,
        'fiberPerReference': x.fiberPerReference,
        'sugarPerReference': x.sugarPerReference,
        'saltPerReference': x.saltPerReference,
        'isArchived': x.isArchived,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };

  IngredientEntity _ingredientFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      IngredientEntity(
        id: id,
        uuid: uuid,
        name: _s(m['name'], 'Ingrediente'),
        brand: _s(m['brand']),
        baseUnit: _s(m['baseUnit'], 'g'),
        barcode: _s(m['barcode']),
        packageQuantity: _nd(m['packageQuantity']),
        sourceTypeCode: _s(m['sourceTypeCode'], 'manual'),
        sourceName: _s(m['sourceName']),
        sourceUrl: _s(m['sourceUrl']),
        imageUrl: _s(m['imageUrl']),
        categories: _s(m['categories']),
        notes: _s(m['notes']),
        nutritionReferenceAmount: _d(m['nutritionReferenceAmount'], 100),
        nutritionReferenceUnitCode: _s(m['nutritionReferenceUnitCode'], 'g'),
        kcalPerReference: _d(m['kcalPerReference']),
        proteinPerReference: _d(m['proteinPerReference']),
        carbsPerReference: _d(m['carbsPerReference']),
        fatPerReference: _d(m['fatPerReference']),
        fiberPerReference: _d(m['fiberPerReference']),
        sugarPerReference: _d(m['sugarPerReference']),
        saltPerReference: _d(m['saltPerReference']),
        isArchived: _b(m['isArchived']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _dayToMap(DailyRecordEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'dateKey': x.dateKey,
        'weekCode': x.weekCode,
        'weekdayCode': x.weekdayCode,
        'weekdayLabel': x.weekdayLabel,
        'weekdayIndex': x.weekdayIndex,
        'targetKcal': x.targetKcal,
        'targetStatusCode': x.targetStatusCode,
        'targetCalculatedAtEpochMs': x.targetCalculatedAtEpochMs,
        'targetSourceHash': x.targetSourceHash,
        'tdeeRefKcal': x.tdeeRefKcal,
        'tdeeTheoreticalKcal': x.tdeeTheoreticalKcal,
        'tdeeObservedKcal': x.tdeeObservedKcal,
        'observedConfidence': x.observedConfidence,
        'referenceDaysCount': x.referenceDaysCount,
        'validIntakeDays': x.validIntakeDays,
        'validWeightDays': x.validWeightDays,
        'rmrKcal': x.rmrKcal,
        'weightRefKg': x.weightRefKg,
        'activeRefKcal': x.activeRefKcal,
        'activeKcalSteps': x.activeKcalSteps,
        'activeKcalWorkoutCompleted': x.activeKcalWorkoutCompleted,
        'activeKcalWorkoutInProgress': x.activeKcalWorkoutInProgress,
        'activeKcalWorkoutPlanned': x.activeKcalWorkoutPlanned,
        'activeKcalWorkoutSkipped': x.activeKcalWorkoutSkipped,
        'activeKcalWorkoutUnknown': x.activeKcalWorkoutUnknown,
        'activeKcalActual': x.activeKcalActual,
        'activeEffectiveKcal': x.activeEffectiveKcal,
        'activityDeltaKcal': x.activityDeltaKcal,
        'activeStatusCode': x.activeStatusCode,
        'caloriesInKcal': x.caloriesInKcal,
        'energyBalanceKcal': x.energyBalanceKcal,
        'weightKg': x.weightKg,
        'weightReliabilityCode': x.weightReliabilityCode,
        'freeMealModeCode': x.freeMealModeCode,
        'freeMealKcal': x.freeMealKcal,
        'freeMealReliabilityCode': x.freeMealReliabilityCode,
        'dataCompletenessScore': x.dataCompletenessScore,
        'waterLiters': x.waterLiters,
        'waterGlasses': x.waterGlasses,
        'sleepDeepHours': x.sleepDeepHours,
        'sleepLightHours': x.sleepLightHours,
        'sleepQualityCode': x.sleepQualityCode,
        'steps': x.steps,
        'stepGoal': x.stepGoal,
        'notes': x.notes,
        'activityBonusKcal': x.activityBonusKcal,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };

  DailyRecordEntity _dayFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      DailyRecordEntity(
        id: id,
        uuid: uuid,
        dateKey: _s(m['dateKey']),
        weekCode: _s(m['weekCode']),
        weekdayCode: _s(m['weekdayCode']),
        weekdayLabel: _s(m['weekdayLabel']),
        weekdayIndex: _i(m['weekdayIndex'], 1),
        targetKcal: _nd(m['targetKcal']),
        targetStatusCode: _s(m['targetStatusCode'], 'provisional'),
        targetCalculatedAtEpochMs: _ni(m['targetCalculatedAtEpochMs']),
        targetSourceHash: _s(m['targetSourceHash']),
        tdeeRefKcal: _nd(m['tdeeRefKcal']),
        tdeeTheoreticalKcal: _nd(m['tdeeTheoreticalKcal']),
        tdeeObservedKcal: _nd(m['tdeeObservedKcal']),
        observedConfidence: _nd(m['observedConfidence']),
        referenceDaysCount: _ni(m['referenceDaysCount']),
        validIntakeDays: _ni(m['validIntakeDays']),
        validWeightDays: _ni(m['validWeightDays']),
        rmrKcal: _nd(m['rmrKcal']),
        weightRefKg: _nd(m['weightRefKg']),
        activeRefKcal: _nd(m['activeRefKcal']),
        activeKcalSteps: _nd(m['activeKcalSteps']),
        activeKcalWorkoutCompleted: _nd(m['activeKcalWorkoutCompleted']),
        activeKcalWorkoutInProgress: _nd(m['activeKcalWorkoutInProgress']),
        activeKcalWorkoutPlanned: _nd(m['activeKcalWorkoutPlanned']),
        activeKcalWorkoutSkipped: _nd(m['activeKcalWorkoutSkipped']),
        activeKcalWorkoutUnknown: _nd(m['activeKcalWorkoutUnknown']),
        activeKcalActual: _nd(m['activeKcalActual']),
        activeEffectiveKcal: _nd(m['activeEffectiveKcal']),
        activityDeltaKcal: _nd(m['activityDeltaKcal']),
        activeStatusCode: _s(m['activeStatusCode'], 'unknown'),
        caloriesInKcal: _nd(m['caloriesInKcal']),
        energyBalanceKcal: _nd(m['energyBalanceKcal']),
        weightKg: _nd(m['weightKg']),
        weightReliabilityCode: _s(m['weightReliabilityCode']),
        freeMealModeCode: _s(m['freeMealModeCode'], 'none'),
        freeMealKcal: _nd(m['freeMealKcal']),
        freeMealReliabilityCode: _s(m['freeMealReliabilityCode']),
        dataCompletenessScore: _nd(m['dataCompletenessScore']),
        waterLiters: _nd(m['waterLiters']),
        waterGlasses: _ni(m['waterGlasses']),
        sleepDeepHours: _nd(m['sleepDeepHours']),
        sleepLightHours: _nd(m['sleepLightHours']),
        sleepQualityCode: _s(m['sleepQualityCode']),
        steps: _i(m['steps']),
        stepGoal: _i(m['stepGoal'], 8000),
        notes: _s(m['notes']),
        activityBonusKcal: _d(m['activityBonusKcal']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _mealToMap(MealEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'dateKey': x.dateKey,
        'weekCode': x.weekCode,
        'weekdayCode': x.weekdayCode,
        'weekdayLabel': x.weekdayLabel,
        'mealTypeCode': x.mealTypeCode,
        'title': x.title,
        'mealModeCode': x.mealModeCode,
        'freeMealTrackingCode': x.freeMealTrackingCode,
        'freeMealLabel': x.freeMealLabel,
        'freeMealNotes': x.freeMealNotes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };

  MealEntity _mealFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      MealEntity(
        id: id,
        uuid: uuid,
        dateKey: _s(m['dateKey']),
        weekCode: _s(m['weekCode']),
        weekdayCode: _s(m['weekdayCode']),
        weekdayLabel: _s(m['weekdayLabel']),
        mealTypeCode: _s(m['mealTypeCode']),
        title: _s(m['title'], 'Pasto'),
        mealModeCode: _s(m['mealModeCode'], 'standard'),
        freeMealTrackingCode: _s(m['freeMealTrackingCode']),
        freeMealLabel: _s(m['freeMealLabel']),
        freeMealNotes: _s(m['freeMealNotes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _mealItemToMap(MealItemEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'position': x.position,
        'kindCode': x.kindCode,
        'sourceUuid': x.sourceUuid,
        'itemNameSnapshot': x.itemNameSnapshot,
        'quantityModeCode': x.quantityModeCode,
        'grams': x.grams,
        'portions': x.portions,
        'kcal': x.kcal,
        'proteinGrams': x.proteinGrams,
        'carbsGrams': x.carbsGrams,
        'fatGrams': x.fatGrams,
        'fiberGrams': x.fiberGrams,
        'sugarGrams': x.sugarGrams,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };

  MealItemEntity _mealItemFromMap(Map<String, dynamic> m) => MealItemEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        kindCode: _s(m['kindCode']),
        sourceUuid: _s(m['sourceUuid']),
        itemNameSnapshot: _s(m['itemNameSnapshot'], 'Voce'),
        quantityModeCode: _s(m['quantityModeCode'], 'grams'),
        grams: _nd(m['grams']),
        portions: _nd(m['portions']),
        kcal: _d(m['kcal']),
        proteinGrams: _d(m['proteinGrams']),
        carbsGrams: _d(m['carbsGrams']),
        fatGrams: _d(m['fatGrams']),
        fiberGrams: _d(m['fiberGrams']),
        sugarGrams: _d(m['sugarGrams']),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _recipeToMap(RecipeEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'title': x.title,
        'subtitle': x.subtitle,
        'summary': x.summary,
        'imagePath': x.imagePath,
        'servings': x.servings,
        'prepTimeMinutes': x.prepTimeMinutes,
        'cookTimeMinutes': x.cookTimeMinutes,
        'restTimeMinutes': x.restTimeMinutes,
        'difficultyCode': x.difficultyCode,
        'courseCode': x.courseCode,
        'cuisineCode': x.cuisineCode,
        'source': x.source,
        'satietyIndex': x.satietyIndex,
        'usageScore': x.usageScore,
        'totalWeightGrams': x.totalWeightGrams,
        'yieldGrams': x.yieldGrams,
        'cookedLossGrams': x.cookedLossGrams,
        'cookedLossPercent': x.cookedLossPercent,
        'caloriesTotal': x.caloriesTotal,
        'proteinTotalGrams': x.proteinTotalGrams,
        'carbsTotalGrams': x.carbsTotalGrams,
        'fatTotalGrams': x.fatTotalGrams,
        'fiberTotalGrams': x.fiberTotalGrams,
        'sugarTotalGrams': x.sugarTotalGrams,
        'kcalPerServing': x.kcalPerServing,
        'kcalPer100Grams': x.kcalPer100Grams,
        'proteinPer100Grams': x.proteinPer100Grams,
        'carbsPer100Grams': x.carbsPer100Grams,
        'fatPer100Grams': x.fatPer100Grams,
        'tagsJson': x.tagsJson,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };

  RecipeEntity _recipeFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      RecipeEntity(
        id: id,
        uuid: uuid,
        title: _s(m['title'], 'Ricetta'),
        subtitle: _s(m['subtitle']),
        summary: _s(m['summary']),
        imagePath: _s(m['imagePath']),
        servings: _i(m['servings'], 1),
        prepTimeMinutes: _i(m['prepTimeMinutes']),
        cookTimeMinutes: _i(m['cookTimeMinutes']),
        restTimeMinutes: _i(m['restTimeMinutes']),
        difficultyCode: _s(m['difficultyCode'], 'easy'),
        courseCode: _s(m['courseCode']),
        cuisineCode: _s(m['cuisineCode']),
        source: _s(m['source']),
        satietyIndex: _nd(m['satietyIndex']),
        usageScore: _nd(m['usageScore']),
        totalWeightGrams: _nd(m['totalWeightGrams']),
        yieldGrams: _nd(m['yieldGrams']),
        cookedLossGrams: _nd(m['cookedLossGrams']),
        cookedLossPercent: _nd(m['cookedLossPercent']),
        caloriesTotal: _nd(m['caloriesTotal']),
        proteinTotalGrams: _nd(m['proteinTotalGrams']),
        carbsTotalGrams: _nd(m['carbsTotalGrams']),
        fatTotalGrams: _nd(m['fatTotalGrams']),
        fiberTotalGrams: _nd(m['fiberTotalGrams']),
        sugarTotalGrams: _nd(m['sugarTotalGrams']),
        kcalPerServing: _nd(m['kcalPerServing']),
        kcalPer100Grams: _nd(m['kcalPer100Grams']),
        proteinPer100Grams: _nd(m['proteinPer100Grams']),
        carbsPer100Grams: _nd(m['carbsPer100Grams']),
        fatPer100Grams: _nd(m['fatPer100Grams']),
        tagsJson: _s(m['tagsJson'], '[]'),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _recipeIngredientToMap(RecipeIngredientEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'ingredientUuid': x.ingredientUuid,
        'nameSnapshot': x.nameSnapshot,
        'grams': x.grams,
        'finalGrams': x.finalGrams,
        'preparationNote': x.preparationNote,
        'calories': x.calories,
        'proteinGrams': x.proteinGrams,
        'carbsGrams': x.carbsGrams,
        'fatGrams': x.fatGrams,
        'fiberGrams': x.fiberGrams,
        'sugarGrams': x.sugarGrams,
      };
  RecipeIngredientEntity _recipeIngredientFromMap(Map<String, dynamic> m) =>
      RecipeIngredientEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        ingredientUuid: _s(m['ingredientUuid']),
        nameSnapshot: _s(m['nameSnapshot'], 'Ingrediente'),
        grams: _d(m['grams']),
        finalGrams: _nd(m['finalGrams']),
        preparationNote: _s(m['preparationNote']),
        calories: _d(m['calories']),
        proteinGrams: _d(m['proteinGrams']),
        carbsGrams: _d(m['carbsGrams']),
        fatGrams: _d(m['fatGrams']),
        fiberGrams: _d(m['fiberGrams']),
        sugarGrams: _d(m['sugarGrams']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _recipeStepToMap(RecipeStepEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'instruction': x.instruction,
        'durationMinutes': x.durationMinutes,
        'notes': x.notes,
      };
  RecipeStepEntity _recipeStepFromMap(Map<String, dynamic> m) =>
      RecipeStepEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        instruction: _s(m['instruction'], 'Passaggio'),
        durationMinutes: _ni(m['durationMinutes']),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _scaleToMap(ScaleMeasurementEntity x) =>
      <String, dynamic>{
        'uuid': x.uuid,
        'dateKey': x.dateKey,
        'title': x.title,
        'weightKg': x.weightKg,
        'weightSourceCode': x.weightSourceCode,
        'bodyFatPercent': x.bodyFatPercent,
        'muscleMassKg': x.muscleMassKg,
        'waterPercent': x.waterPercent,
        'boneMassKg': x.boneMassKg,
        'visceralFat': x.visceralFat,
        'subcutaneousFatPercent': x.subcutaneousFatPercent,
        'basalMetabolismKcal': x.basalMetabolismKcal,
        'bmi': x.bmi,
        'metabolicAge': x.metabolicAge,
        'physiqueRating': x.physiqueRating,
        'measurementTime': x.measurementTime,
        'device': x.device,
        'reliabilityCode': x.reliabilityCode,
        'weightAnomalyConfirmationKey': x.weightAnomalyConfirmationKey,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  ScaleMeasurementEntity _scaleFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      ScaleMeasurementEntity(
        id: id,
        uuid: uuid,
        dateKey: _s(m['dateKey']),
        title: _s(m['title'], 'Bilancia'),
        weightKg: _nd(m['weightKg']),
        weightSourceCode: _s(m['weightSourceCode'], 'manual'),
        bodyFatPercent: _nd(m['bodyFatPercent']),
        muscleMassKg: _nd(m['muscleMassKg']),
        waterPercent: _nd(m['waterPercent']),
        boneMassKg: _nd(m['boneMassKg']),
        visceralFat: _nd(m['visceralFat']),
        subcutaneousFatPercent: _nd(m['subcutaneousFatPercent']),
        basalMetabolismKcal: _nd(m['basalMetabolismKcal']),
        bmi: _nd(m['bmi']),
        metabolicAge: _nd(m['metabolicAge']),
        physiqueRating: _s(m['physiqueRating']),
        measurementTime: _s(m['measurementTime']),
        device: _s(m['device']),
        reliabilityCode: _s(m['reliabilityCode'], 'normal'),
        weightAnomalyConfirmationKey: _s(m['weightAnomalyConfirmationKey']),
        notes: _s(m['notes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _tapeToMap(TapeMeasurementEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'dateKey': x.dateKey,
        'title': x.title,
        'measurementTime': x.measurementTime,
        'reliabilityCode': x.reliabilityCode,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  TapeMeasurementEntity _tapeFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      TapeMeasurementEntity(
        id: id,
        uuid: uuid,
        dateKey: _s(m['dateKey']),
        title: _s(m['title'], 'Metro'),
        measurementTime: _s(m['measurementTime']),
        reliabilityCode: _s(m['reliabilityCode'], 'normal'),
        notes: _s(m['notes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _tapeEntryToMap(TapeMeasurementEntryEntity x) =>
      <String, dynamic>{
        'measurementCode': x.measurementCode,
        'position': x.position,
        'valueCm': x.valueCm,
      };
  TapeMeasurementEntryEntity _tapeEntryFromMap(Map<String, dynamic> m) =>
      TapeMeasurementEntryEntity(
        uuid: _uuid.v4(),
        measurementCode: _s(m['measurementCode']),
        position: _i(m['position']),
        valueCm: _nd(m['valueCm']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _muscleToMap(MuscleEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'code': x.code,
        'displayNameIt': x.displayNameIt,
        'displayNameEn': x.displayNameEn,
        'groupCode': x.groupCode,
        'bodyRegionCode': x.bodyRegionCode,
        'sortOrder': x.sortOrder,
        'isActive': x.isActive,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  MuscleEntity _muscleFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      MuscleEntity(
        id: id,
        uuid: uuid,
        code: _s(m['code']),
        displayNameIt: _s(m['displayNameIt']),
        displayNameEn: _s(m['displayNameEn']),
        groupCode: _s(m['groupCode']),
        bodyRegionCode: _s(m['bodyRegionCode']),
        sortOrder: _i(m['sortOrder']),
        isActive: _b(m['isActive'], true),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _exerciseToMap(ExerciseEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'name': x.name,
        'exerciseModeCode': x.exerciseModeCode,
        'mediaPath': x.mediaPath,
        'defaultRestSec': x.defaultRestSec,
        'notes': x.notes,
        'isArchived': x.isArchived,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  ExerciseEntity _exerciseFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      ExerciseEntity(
        id: id,
        uuid: uuid,
        name: _s(m['name'], 'Esercizio'),
        exerciseModeCode: _s(m['exerciseModeCode'], 'gym'),
        mediaPath: _s(m['mediaPath']),
        defaultRestSec: _ni(m['defaultRestSec']),
        notes: _s(m['notes']),
        isArchived: _b(m['isArchived']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _routineToMap(RoutineEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'name': x.name,
        'slug': x.slug,
        'summary': x.summary,
        'goal': x.goal,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  RoutineEntity _routineFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      RoutineEntity(
        id: id,
        uuid: uuid,
        name: _s(m['name'], 'Routine'),
        slug: _s(m['slug'], _norm(_s(m['name']))),
        summary: _s(m['summary']),
        goal: _s(m['goal']),
        notes: _s(m['notes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _routineExerciseToMap(RoutineExerciseEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'exerciseUuid': x.exerciseUuid,
        'exerciseNameSnapshot': x.exerciseNameSnapshot,
        'exerciseModeCode': x.exerciseModeCode,
        'mediaSnapshot': x.mediaSnapshot,
        'restSeconds': x.restSeconds,
        'primaryMuscleCodesJson': x.primaryMuscleCodesJson,
        'secondaryMuscleCodesJson': x.secondaryMuscleCodesJson,
        'activityTargetDurationMinutes': x.activityTargetDurationMinutes,
        'treadmillTargetDurationMinutes': x.treadmillTargetDurationMinutes,
        'treadmillTargetDistanceKm': x.treadmillTargetDistanceKm,
        'treadmillTargetAverageSpeedKmh': x.treadmillTargetAverageSpeedKmh,
        'treadmillTargetAverageInclinePercent':
            x.treadmillTargetAverageInclinePercent,
        'notes': x.notes,
      };
  RoutineExerciseEntity _routineExerciseFromMap(Map<String, dynamic> m) =>
      RoutineExerciseEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        exerciseUuid: _s(m['exerciseUuid']),
        exerciseNameSnapshot: _s(m['exerciseNameSnapshot'], 'Esercizio'),
        exerciseModeCode: _s(m['exerciseModeCode'], 'gym'),
        mediaSnapshot: _s(m['mediaSnapshot']),
        restSeconds: _ni(m['restSeconds']),
        primaryMuscleCodesJson: _s(m['primaryMuscleCodesJson'], '[]'),
        secondaryMuscleCodesJson: _s(m['secondaryMuscleCodesJson'], '[]'),
        activityTargetDurationMinutes: _ni(m['activityTargetDurationMinutes']),
        treadmillTargetDurationMinutes:
            _ni(m['treadmillTargetDurationMinutes']),
        treadmillTargetDistanceKm: _nd(m['treadmillTargetDistanceKm']),
        treadmillTargetAverageSpeedKmh:
            _nd(m['treadmillTargetAverageSpeedKmh']),
        treadmillTargetAverageInclinePercent:
            _nd(m['treadmillTargetAverageInclinePercent']),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _routineSetToMap(RoutineSetTemplateEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'setRoleCode': x.setRoleCode,
        'targetRepetitions': x.targetRepetitions,
        'effortTypeCode': x.effortTypeCode,
        'rir': x.rir,
        'executionSpeedCode': x.executionSpeedCode,
        'executionQualityCode': x.executionQualityCode,
        'notes': x.notes,
      };
  RoutineSetTemplateEntity _routineSetFromMap(Map<String, dynamic> m) =>
      RoutineSetTemplateEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        setRoleCode: _s(m['setRoleCode'], 'working'),
        targetRepetitions: _i(m['targetRepetitions'], 8),
        effortTypeCode: _s(m['effortTypeCode'], 'rir'),
        rir: _ni(m['rir']),
        executionSpeedCode: _s(m['executionSpeedCode'], 'normal'),
        executionQualityCode: _s(m['executionQualityCode'], 'good'),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _planToMap(WorkoutPlanEntity x) => <String, dynamic>{
        'uuid': x.uuid,
        'name': x.name,
        'levelCode': x.levelCode,
        'statusCode': x.statusCode,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  WorkoutPlanEntity _planFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      WorkoutPlanEntity(
        id: id,
        uuid: uuid,
        name: _s(m['name'], 'Scheda'),
        levelCode: _s(m['levelCode']),
        statusCode: _s(m['statusCode'], 'draft'),
        notes: _s(m['notes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _planDayToMap(WorkoutPlanDayEntity x) =>
      <String, dynamic>{
        'dayCode': x.dayCode,
        'position': x.position,
        'title': x.title,
        'notes': x.notes,
      };
  WorkoutPlanDayEntity _planDayFromMap(Map<String, dynamic> m) =>
      WorkoutPlanDayEntity(
        uuid: _uuid.v4(),
        dayCode: _s(m['dayCode']),
        position: _i(m['position']),
        title: _s(m['title'], 'Giorno'),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _planExerciseToMap(WorkoutPlanExerciseEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'exerciseUuid': x.exerciseUuid,
        'exerciseNameSnapshot': x.exerciseNameSnapshot,
        'exerciseModeCode': x.exerciseModeCode,
        'setsCount': x.setsCount,
        'warmupSetsCount': x.warmupSetsCount,
        'repetitionsText': x.repetitionsText,
        'restSeconds': x.restSeconds,
        'activityDurationMinutes': x.activityDurationMinutes,
        'treadmillDurationMinutes': x.treadmillDurationMinutes,
        'treadmillDistanceKm': x.treadmillDistanceKm,
        'treadmillAverageSpeedKmh': x.treadmillAverageSpeedKmh,
        'treadmillAverageInclinePercent': x.treadmillAverageInclinePercent,
        'note': x.note,
        'mediaOverride': x.mediaOverride,
      };
  WorkoutPlanExerciseEntity _planExerciseFromMap(Map<String, dynamic> m) =>
      WorkoutPlanExerciseEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        exerciseUuid: _s(m['exerciseUuid']),
        exerciseNameSnapshot: _s(m['exerciseNameSnapshot'], 'Esercizio'),
        exerciseModeCode: _s(m['exerciseModeCode'], 'gym'),
        setsCount: _ni(m['setsCount']),
        warmupSetsCount: _ni(m['warmupSetsCount']),
        repetitionsText: _s(m['repetitionsText']),
        restSeconds: _ni(m['restSeconds']),
        activityDurationMinutes: _ni(m['activityDurationMinutes']),
        treadmillDurationMinutes: _ni(m['treadmillDurationMinutes']),
        treadmillDistanceKm: _nd(m['treadmillDistanceKm']),
        treadmillAverageSpeedKmh: _nd(m['treadmillAverageSpeedKmh']),
        treadmillAverageInclinePercent:
            _nd(m['treadmillAverageInclinePercent']),
        note: _s(m['note']),
        mediaOverride: _s(m['mediaOverride']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  Map<String, dynamic> _sessionToMap(WorkoutSessionEntity x) =>
      <String, dynamic>{
        'uuid': x.uuid,
        'title': x.title,
        'sessionDateKey': x.sessionDateKey,
        'routineUuid': x.routineUuid,
        'routineNameSnapshot': x.routineNameSnapshot,
        'workoutPlanUuid': x.workoutPlanUuid,
        'workoutPlanDayUuid': x.workoutPlanDayUuid,
        'statusCode': x.statusCode,
        'durationMinutes': x.durationMinutes,
        'averageHeartRateBpm': x.averageHeartRateBpm,
        'estimatedKcalBurned': x.estimatedKcalBurned,
        'notes': x.notes,
        'createdAtEpochMs': x.createdAtEpochMs,
        'updatedAtEpochMs': x.updatedAtEpochMs,
      };
  WorkoutSessionEntity _sessionFromMap(Map<String, dynamic> m,
          {required int id, required String uuid}) =>
      WorkoutSessionEntity(
        id: id,
        uuid: uuid,
        title: _s(m['title'], 'Sessione'),
        sessionDateKey: _s(m['sessionDateKey']),
        routineUuid: _s(m['routineUuid']),
        routineNameSnapshot: _s(m['routineNameSnapshot']),
        workoutPlanUuid: _s(m['workoutPlanUuid']),
        workoutPlanDayUuid: _s(m['workoutPlanDayUuid']),
        statusCode: _s(m['statusCode'], 'planned'),
        durationMinutes: _ni(m['durationMinutes']),
        averageHeartRateBpm: _ni(m['averageHeartRateBpm']),
        estimatedKcalBurned: _nd(m['estimatedKcalBurned']),
        notes: _s(m['notes']),
        createdAtEpochMs: _i(m['createdAtEpochMs'], _clock.nowEpochMs()),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _sessionExerciseToMap(SessionExerciseEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'exerciseUuid': x.exerciseUuid,
        'exerciseNameSnapshot': x.exerciseNameSnapshot,
        'exerciseModeCode': x.exerciseModeCode,
        'mediaSnapshot': x.mediaSnapshot,
        'restSeconds': x.restSeconds,
        'primaryMuscleCodesJson': x.primaryMuscleCodesJson,
        'secondaryMuscleCodesJson': x.secondaryMuscleCodesJson,
        'activityDurationMinutes': x.activityDurationMinutes,
        'activityAverageHeartRateBpm': x.activityAverageHeartRateBpm,
        'activityKcalBurned': x.activityKcalBurned,
        'treadmillDurationMinutes': x.treadmillDurationMinutes,
        'treadmillDistanceKm': x.treadmillDistanceKm,
        'treadmillAverageSpeedKmh': x.treadmillAverageSpeedKmh,
        'treadmillAverageInclinePercent': x.treadmillAverageInclinePercent,
        'treadmillAverageHeartRateBpm': x.treadmillAverageHeartRateBpm,
        'isCompleted': x.isCompleted,
        'notes': x.notes,
      };
  SessionExerciseEntity _sessionExerciseFromMap(Map<String, dynamic> m) =>
      SessionExerciseEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        exerciseUuid: _s(m['exerciseUuid']),
        exerciseNameSnapshot: _s(m['exerciseNameSnapshot'], 'Esercizio'),
        exerciseModeCode: _s(m['exerciseModeCode'], 'gym'),
        mediaSnapshot: _s(m['mediaSnapshot']),
        restSeconds: _ni(m['restSeconds']),
        primaryMuscleCodesJson: _s(m['primaryMuscleCodesJson'], '[]'),
        secondaryMuscleCodesJson: _s(m['secondaryMuscleCodesJson'], '[]'),
        activityDurationMinutes: _ni(m['activityDurationMinutes']),
        activityAverageHeartRateBpm: _ni(m['activityAverageHeartRateBpm']),
        activityKcalBurned: _nd(m['activityKcalBurned']),
        treadmillDurationMinutes: _ni(m['treadmillDurationMinutes']),
        treadmillDistanceKm: _nd(m['treadmillDistanceKm']),
        treadmillAverageSpeedKmh: _nd(m['treadmillAverageSpeedKmh']),
        treadmillAverageInclinePercent:
            _nd(m['treadmillAverageInclinePercent']),
        treadmillAverageHeartRateBpm: _ni(m['treadmillAverageHeartRateBpm']),
        isCompleted: _b(m['isCompleted']),
        notes: _s(m['notes']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );
  Map<String, dynamic> _sessionSetToMap(SessionSetEntity x) =>
      <String, dynamic>{
        'position': x.position,
        'setRoleCode': x.setRoleCode,
        'targetRepetitions': x.targetRepetitions,
        'repetitionsDone': x.repetitionsDone,
        'weightKg': x.weightKg,
        'previousRepetitionsDone': x.previousRepetitionsDone,
        'previousWeightKg': x.previousWeightKg,
        'previousEffortTypeCode': x.previousEffortTypeCode,
        'previousRir': x.previousRir,
        'previousExecutionSpeedCode': x.previousExecutionSpeedCode,
        'previousExecutionQualityCode': x.previousExecutionQualityCode,
        'effortTypeCode': x.effortTypeCode,
        'rir': x.rir,
        'executionSpeedCode': x.executionSpeedCode,
        'executionQualityCode': x.executionQualityCode,
        'setNote': x.setNote,
        'isCompleted': x.isCompleted,
      };
  SessionSetEntity _sessionSetFromMap(Map<String, dynamic> m) =>
      SessionSetEntity(
        uuid: _uuid.v4(),
        position: _i(m['position']),
        setRoleCode: _s(m['setRoleCode'], 'working'),
        targetRepetitions: _ni(m['targetRepetitions']),
        repetitionsDone: _ni(m['repetitionsDone']),
        weightKg: _nd(m['weightKg']),
        previousRepetitionsDone: _ni(m['previousRepetitionsDone']),
        previousWeightKg: _nd(m['previousWeightKg']),
        previousEffortTypeCode: _s(m['previousEffortTypeCode']),
        previousRir: _ni(m['previousRir']),
        previousExecutionSpeedCode: _s(m['previousExecutionSpeedCode']),
        previousExecutionQualityCode: _s(m['previousExecutionQualityCode']),
        effortTypeCode: _s(m['effortTypeCode'], 'rir'),
        rir: _ni(m['rir']),
        executionSpeedCode: _s(m['executionSpeedCode'], 'normal'),
        executionQualityCode: _s(m['executionQualityCode'], 'good'),
        setNote: _s(m['setNote']),
        isCompleted: _b(m['isCompleted']),
        createdAtEpochMs: _clock.nowEpochMs(),
        updatedAtEpochMs: _clock.nowEpochMs(),
      );

  String _displayValue(Object? value) {
    if (value == null) return 'non impostato';
    if (value is double) return value.toStringAsFixed(2);
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map item) => item.map<String, dynamic>(
              (Object? key, Object? value) =>
                  MapEntry<String, dynamic>(key.toString(), value),
            ))
        .toList();
  }

  Map<String, dynamic>? _mapOrNull(Object? value) {
    if (value is! Map) return null;
    return value.map<String, dynamic>(
      (Object? key, Object? value) =>
          MapEntry<String, dynamic>(key.toString(), value),
    );
  }

  String _norm(String value) => value.trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
  String _s(Object? value, [String fallback = '']) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  int _i(Object? value, [int fallback = 0]) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;
  int? _ni(Object? value) => value == null || value == ''
      ? null
      : value is int
          ? value
          : int.tryParse(value.toString());
  double _d(Object? value, [double fallback = 0]) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? fallback;
  double? _nd(Object? value) => value == null || value == ''
      ? null
      : value is num
          ? value.toDouble()
          : double.tryParse(value.toString());
  bool _b(Object? value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString().toLowerCase() == 'true';
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
