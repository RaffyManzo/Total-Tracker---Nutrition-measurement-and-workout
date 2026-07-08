import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/import/legacy_scale_xls_importer.dart';

void main() {
  LegacyScaleImportRow row({
    required int sequence,
    required DateTime dateTime,
    required bool hasTime,
    int sheet = 0,
  }) {
    return LegacyScaleImportRow(
      index: sequence,
      sourceSequence: sequence,
      sourceSheetIndex: sheet,
      sourceSheetName: 'Sheet ${sheet + 1}',
      sourceRowNumber: sequence + 1,
      dateTime: dateTime,
      hasExplicitTime: hasTime,
      weightKg: 64,
      values: const <String, Object?>{},
      unmappedValues: const <String, Object?>{},
      warnings: const <String>[],
    );
  }

  test('latest per day selects the row with the latest valid time', () {
    final LegacyScaleImportRow morning = row(
      sequence: 1,
      dateTime: DateTime(2026, 7, 8, 8),
      hasTime: true,
    );
    final LegacyScaleImportRow evening = row(
      sequence: 2,
      dateTime: DateTime(2026, 7, 8, 22, 30),
      hasTime: true,
    );
    final Set<String> selected = LegacyScaleSelection.select(
      rows: <LegacyScaleImportRow>[morning, evening],
      mode: XlsDailySelectionMode.latestPerDay,
    );
    expect(selected, <String>{evening.rowId});
  });

  test('missing time ranks before every row with an explicit time', () {
    final LegacyScaleImportRow noTime = row(
      sequence: 1,
      dateTime: DateTime(2026, 7, 8),
      hasTime: false,
    );
    final LegacyScaleImportRow timed = row(
      sequence: 2,
      dateTime: DateTime(2026, 7, 8, 0, 1),
      hasTime: true,
    );
    final Set<String> selected = LegacyScaleSelection.select(
      rows: <LegacyScaleImportRow>[noTime, timed],
      mode: XlsDailySelectionMode.latestPerDay,
    );
    expect(selected, <String>{timed.rowId});
  });

  test('equal times retain the first stable workbook row', () {
    final LegacyScaleImportRow first = row(
      sequence: 1,
      dateTime: DateTime(2026, 7, 8, 20),
      hasTime: true,
    );
    final LegacyScaleImportRow second = row(
      sequence: 2,
      dateTime: DateTime(2026, 7, 8, 20),
      hasTime: true,
      sheet: 1,
    );
    final Set<String> selected = LegacyScaleSelection.select(
      rows: <LegacyScaleImportRow>[first, second],
      mode: XlsDailySelectionMode.latestPerDay,
    );
    expect(selected, <String>{first.rowId});
  });

  test('date range selection is inclusive and reversible', () {
    final List<LegacyScaleImportRow> rows = <LegacyScaleImportRow>[
      row(
        sequence: 1,
        dateTime: DateTime(2026, 7, 7, 8),
        hasTime: true,
      ),
      row(
        sequence: 2,
        dateTime: DateTime(2026, 7, 8, 8),
        hasTime: true,
      ),
      row(
        sequence: 3,
        dateTime: DateTime(2026, 7, 9, 8),
        hasTime: true,
      ),
    ];
    final Set<String> selected = LegacyScaleSelection.select(
      rows: rows,
      fromDateKey: '2026-07-08',
      toDateKey: '2026-07-09',
    );
    expect(selected, <String>{rows[1].rowId, rows[2].rowId});
    expect(rows, hasLength(3));
  });
}
