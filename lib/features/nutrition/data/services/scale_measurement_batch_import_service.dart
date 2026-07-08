import 'dart:convert';

import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../entities/nutrition_tracking_entities.dart';
import '../import/legacy_scale_xls_importer.dart';
import 'scale_device_catalog_service.dart';
import 'scale_measurement_validator.dart';
import 'target_input_change_bus.dart';
import 'target_input_mutation_service.dart';

class ScaleBatchImportReport {
  const ScaleBatchImportReport({
    required this.readRows,
    required this.selectedRows,
    required this.importedRows,
    required this.exactDuplicates,
    required this.timestampConflicts,
    required this.invalidRows,
    required this.fromDateKey,
    required this.toDateKey,
  });

  final int readRows;
  final int selectedRows;
  final int importedRows;
  final int exactDuplicates;
  final int timestampConflicts;
  final int invalidRows;
  final String? fromDateKey;
  final String? toDateKey;
}

class ScaleMeasurementBatchImportService {
  ScaleMeasurementBatchImportService(
    this._store, {
    ScaleMeasurementValidator validator = const ScaleMeasurementValidator(),
  }) : _validator = validator;

  final Store _store;
  final ScaleMeasurementValidator _validator;

  ScaleBatchImportReport importSelected({
    required LegacyScaleImportPreview preview,
    required Set<String> selectedRowIds,
    required ScaleDeviceOption device,
  }) {
    final List<LegacyScaleImportRow> selected = preview.rows
        .where((row) => selectedRowIds.contains(row.rowId))
        .toList(growable: false);
    final Box<ScaleMeasurementEntity> scaleBox =
        _store.box<ScaleMeasurementEntity>();
    final List<ScaleMeasurementEntity> existing = scaleBox
        .getAll()
        .where((item) => item.deletedAtEpochMs == null)
        .toList(growable: false);
    final Set<String> exactFingerprints = existing.map(_fingerprint).toSet();
    final Set<String> timestampKeys = existing
        .map((item) => '${item.dateKey}|${item.measurementTime}|${item.device}')
        .toSet();

    final List<ScaleMeasurementEntity> candidates = <ScaleMeasurementEntity>[];
    int exactDuplicates = 0;
    int timestampConflicts = 0;
    int invalidRows = 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    final String storedDevice = ScaleDeviceCatalogService.encode(device);

    for (final LegacyScaleImportRow row in selected) {
      final ScaleMeasurementEntity entity = ScaleMeasurementEntity(
        uuid: const Uuid().v4(),
        dateKey: row.dateKey,
        title: 'Bilancia · ${row.dateKey}',
        weightKg: row.weightKg,
        weightSourceCode: 'xls_import',
        bodyFatPercent: row.number('bodyFatPercent'),
        muscleMassKg: row.number('muscleMassKg'),
        waterPercent: row.number('waterPercent'),
        boneMassKg: row.number('boneMassKg'),
        visceralFat: row.number('visceralFat'),
        subcutaneousFatPercent: row.number('subcutaneousFatPercent'),
        basalMetabolismKcal: row.number('basalMetabolismKcal'),
        bmi: row.number('bmi'),
        metabolicAge: row.number('metabolicAge'),
        physiqueRating: row.text('physiqueRating'),
        measurementTime: row.measurementTime,
        device: storedDevice,
        reliabilityCode: 'normal',
        notes: _notesFor(row),
        createdAtEpochMs: now,
        updatedAtEpochMs: now,
      );
      final ScaleValidationResult validation = _validator.validate(entity);
      if (!validation.isValid) {
        invalidRows += 1;
        continue;
      }
      entity.reliabilityCode = validation.reliabilityCode;
      final String fingerprint = _fingerprint(entity);
      final String timestampKey =
          '${entity.dateKey}|${entity.measurementTime}|${entity.device}';
      if (exactFingerprints.contains(fingerprint)) {
        exactDuplicates += 1;
        continue;
      }
      if (timestampKeys.contains(timestampKey)) {
        timestampConflicts += 1;
        continue;
      }
      candidates.add(entity);
      exactFingerprints.add(fingerprint);
      timestampKeys.add(timestampKey);
    }

    String? fromDateKey;
    String? toDateKey;
    if (candidates.isNotEmpty) {
      final String minDateKey = candidates
          .map((item) => item.dateKey)
          .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
      final String maxDateKey = candidates
          .map((item) => item.dateKey)
          .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
      fromDateKey = minDateKey;
      toDateKey = maxDateKey;
      _store.runInTransaction(TxMode.write, () {
        scaleBox.putMany(candidates);
        TargetInputMutationService.enqueueInCurrentTransaction(
          _store,
          kind: TargetInputChangeKind.importBatch,
          fromDateKey: minDateKey,
          toDateKey: maxDateKey,
          reasonCode: 'scale_xls_batch_import',
          sourceEntityUuid: 'xls:${preview.filePath.hashCode}',
        );
      });
      TargetInputMutationService.publishAfterCommit(
        kind: TargetInputChangeKind.importBatch,
        fromDateKey: minDateKey,
        toDateKey: maxDateKey,
        reasonCode: 'scale_xls_batch_import',
        sourceEntityUuid: 'xls:${preview.filePath.hashCode}',
      );
    }

    return ScaleBatchImportReport(
      readRows: preview.rows.length,
      selectedRows: selected.length,
      importedRows: candidates.length,
      exactDuplicates: exactDuplicates,
      timestampConflicts: timestampConflicts,
      invalidRows: invalidRows,
      fromDateKey: fromDateKey,
      toDateKey: toDateKey,
    );
  }

  String _fingerprint(ScaleMeasurementEntity item) {
    final Map<String, Object?> canonical = <String, Object?>{
      'dateKey': item.dateKey,
      'time': item.measurementTime,
      'device': item.device,
      'weight': _number(item.weightKg),
      'fat': _number(item.bodyFatPercent),
      'muscle': _number(item.muscleMassKg),
      'water': _number(item.waterPercent),
      'bone': _number(item.boneMassKg),
      'visceral': _number(item.visceralFat),
      'subcutaneous': _number(item.subcutaneousFatPercent),
      'bmr': _number(item.basalMetabolismKcal),
      'bmi': _number(item.bmi),
      'age': _number(item.metabolicAge),
      'physique': item.physiqueRating.trim(),
    };
    return jsonEncode(canonical);
  }

  String? _number(double? value) {
    if (value == null || !value.isFinite) return null;
    return value.toStringAsFixed(6);
  }

  String _notesFor(LegacyScaleImportRow row) {
    final List<String> lines = <String>[
      'Importato da XLS legacy.',
      'Origine: foglio ${row.sourceSheetName}, riga ${row.sourceRowNumber}.',
      if (row.unmappedValues.isNotEmpty)
        'Campi originali non modellati: ${jsonEncode(row.unmappedValues)}',
      ...row.warnings,
    ];
    return lines.join('\n');
  }
}
