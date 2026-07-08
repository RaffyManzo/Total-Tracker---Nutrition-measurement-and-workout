import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:excel2003/excel2003.dart';
import 'package:intl/intl.dart';

class LegacyScaleImportLimits {
  const LegacyScaleImportLimits({
    this.maxFileBytes = 20 * 1024 * 1024,
    this.maxSheets = 32,
    this.maxTotalRows = 20000,
    this.maxColumnsPerSheet = 128,
    this.maxNonEmptyCells = 500000,
    this.maxCellTextLength = 4096,
  });

  final int maxFileBytes;
  final int maxSheets;
  final int maxTotalRows;
  final int maxColumnsPerSheet;
  final int maxNonEmptyCells;
  final int maxCellTextLength;
}

class LegacyScaleFieldMatch {
  const LegacyScaleFieldMatch({
    required this.targetField,
    required this.sourceHeader,
    required this.score,
    this.sourceSheetName = '',
  });

  final String targetField;
  final String sourceHeader;
  final double score;
  final String sourceSheetName;
}

class LegacyScaleImportRow {
  const LegacyScaleImportRow({
    required this.index,
    required this.sourceSequence,
    required this.sourceSheetIndex,
    required this.sourceSheetName,
    required this.sourceRowNumber,
    required this.dateTime,
    required this.hasExplicitTime,
    required this.weightKg,
    required this.values,
    required this.unmappedValues,
    required this.warnings,
  });

  /// Stable global index retained for compatibility with previous call sites.
  final int index;
  final int sourceSequence;
  final int sourceSheetIndex;
  final String sourceSheetName;
  final int sourceRowNumber;
  final DateTime dateTime;
  final bool hasExplicitTime;
  final double weightKg;
  final Map<String, Object?> values;
  final Map<String, Object?> unmappedValues;
  final List<String> warnings;

  String get rowId => '$sourceSheetIndex:$sourceRowNumber:$sourceSequence';
  String get dateKey => DateFormat('yyyy-MM-dd').format(dateTime);
  String get measurementTime => DateFormat('HH:mm:ss').format(dateTime);
  String get duplicateKey => '$dateKey|$measurementTime';

  int get timeOfDaySeconds => hasExplicitTime
      ? dateTime.hour * 3600 + dateTime.minute * 60 + dateTime.second
      : -1;

  double? number(String key) {
    final Object? value = values[key];
    return value is num ? value.toDouble() : null;
  }

  String text(String key) => (values[key] ?? '').toString().trim();
}

class LegacyScaleImportPreview {
  const LegacyScaleImportPreview({
    required this.filePath,
    required this.sheetNames,
    required this.matches,
    required this.rows,
    required this.unmatchedHeaders,
    required this.warnings,
  });

  final String filePath;
  final List<String> sheetNames;
  final List<LegacyScaleFieldMatch> matches;
  final List<LegacyScaleImportRow> rows;
  final List<String> unmatchedHeaders;
  final List<String> warnings;

  String get sheetName =>
      sheetNames.isEmpty ? 'Nessun foglio' : sheetNames.join(', ');
  String? get firstDateKey => rows.isEmpty ? null : rows.first.dateKey;
  String? get lastDateKey => rows.isEmpty ? null : rows.last.dateKey;
}

enum XlsDailySelectionMode { allMeasurements, latestPerDay }

class LegacyScaleSelection {
  const LegacyScaleSelection._();

  static Set<String> select({
    required Iterable<LegacyScaleImportRow> rows,
    String? fromDateKey,
    String? toDateKey,
    XlsDailySelectionMode mode = XlsDailySelectionMode.allMeasurements,
  }) {
    final List<LegacyScaleImportRow> eligible = rows.where((row) {
      if (fromDateKey != null && row.dateKey.compareTo(fromDateKey) < 0) {
        return false;
      }
      if (toDateKey != null && row.dateKey.compareTo(toDateKey) > 0) {
        return false;
      }
      return true;
    }).toList(growable: false);

    if (mode == XlsDailySelectionMode.allMeasurements) {
      return eligible.map((row) => row.rowId).toSet();
    }

    final Map<String, LegacyScaleImportRow> latestByDay = {};
    for (final LegacyScaleImportRow candidate in eligible) {
      final LegacyScaleImportRow? current = latestByDay[candidate.dateKey];
      if (current == null || _isLater(candidate, current)) {
        latestByDay[candidate.dateKey] = candidate;
      }
    }
    return latestByDay.values.map((row) => row.rowId).toSet();
  }

  static bool _isLater(
    LegacyScaleImportRow candidate,
    LegacyScaleImportRow current,
  ) {
    final int timeCompare = candidate.timeOfDaySeconds.compareTo(
      current.timeOfDaySeconds,
    );
    if (timeCompare != 0) return timeCompare > 0;

    // Stable tie-break: retain the first workbook row. This avoids a hidden,
    // non-deterministic choice while the UI continues to expose every row.
    return candidate.sourceSequence < current.sourceSequence;
  }
}

class LegacyScaleXlsImporter {
  const LegacyScaleXlsImporter({
    this.limits = const LegacyScaleImportLimits(),
  });

  final LegacyScaleImportLimits limits;

  static const Map<String, List<String>> aliases = <String, List<String>>{
    'dateTime': <String>[
      'tempo',
      'data',
      'date',
      'datetime',
      'timestamp',
      'ora misurazione',
      'measurement time',
    ],
    'weightKg': <String>['peso', 'weight', 'body weight', 'peso kg'],
    'bmi': <String>['bmi', 'indice massa corporea'],
    'bodyFatPercent': <String>[
      'grasso corporeo',
      'body fat',
      'fat percentage',
      'percentuale grasso',
    ],
    'muscleMassKg': <String>[
      'massa muscolare',
      'muscle mass',
      'muscolo kg',
    ],
    'waterPercent': <String>[
      'acqua corporea',
      'body water',
      'water percentage',
    ],
    'visceralFat': <String>['grasso viscerale', 'visceral fat'],
    'boneMassKg': <String>['massa ossea', 'bone mass'],
    'basalMetabolismKcal': <String>[
      'bmr',
      'metabolismo basale',
      'basal metabolism',
    ],
    'subcutaneousFatPercent': <String>[
      'grasso sottocutaneo',
      'subcutaneous fat',
    ],
    'physiqueRating': <String>[
      'tipo di corpo',
      'body type',
      'physique rating',
    ],
    'metabolicAge': <String>[
      'eta del corpo',
      'età del corpo',
      'eta metabolica',
      'metabolic age',
      'body age',
    ],
  };

  Future<LegacyScaleImportPreview> readAsync(String filePath) {
    final LegacyScaleImportLimits capturedLimits = limits;
    return Isolate.run(
      () => LegacyScaleXlsImporter(limits: capturedLimits).read(filePath),
    );
  }

  LegacyScaleImportPreview read(String filePath) {
    final File file = File(filePath);
    if (!file.existsSync()) {
      throw FileSystemException('File XLS non trovato.', filePath);
    }
    final int fileBytes = file.lengthSync();
    if (fileBytes > limits.maxFileBytes) {
      throw FormatException(
        'File troppo grande: $fileBytes byte; limite ${limits.maxFileBytes}.',
      );
    }

    final XlsReader reader = XlsReader(filePath);
    reader.open();
    if (reader.sheetCount <= 0) {
      throw const FormatException('Il file XLS non contiene fogli leggibili.');
    }
    if (reader.sheetCount > limits.maxSheets) {
      throw FormatException(
        'Troppi fogli: ${reader.sheetCount}; limite ${limits.maxSheets}.',
      );
    }

    final List<String> sheetNames = <String>[];
    final List<LegacyScaleFieldMatch> allMatches = <LegacyScaleFieldMatch>[];
    final Set<String> unmatchedHeaders = <String>{};
    final List<String> globalWarnings = <String>[];
    final List<LegacyScaleImportRow> rows = <LegacyScaleImportRow>[];
    int totalRows = 0;
    int nonEmptyCells = 0;
    int sourceSequence = 0;

    for (int sheetIndex = 0; sheetIndex < reader.sheetCount; sheetIndex += 1) {
      final String sheetName = sheetIndex < reader.sheetNames.length
          ? reader.sheetNames[sheetIndex]
          : 'Foglio ${sheetIndex + 1}';
      final dynamic sheet = reader.sheet(sheetIndex);
      final List<dynamic> rawRows = List<dynamic>.from(
        sheet.toMaps() as List<dynamic>,
      );
      if (rawRows.isEmpty) continue;

      sheetNames.add(sheetName);
      totalRows += rawRows.length;
      if (totalRows > limits.maxTotalRows) {
        throw FormatException(
          'Troppe righe complessive: $totalRows; limite ${limits.maxTotalRows}.',
        );
      }

      final Set<String> headers = <String>{};
      for (final dynamic rawRow in rawRows) {
        if (rawRow is! Map) continue;
        if (rawRow.length > limits.maxColumnsPerSheet) {
          throw FormatException(
            'Il foglio "$sheetName" supera ${limits.maxColumnsPerSheet} colonne.',
          );
        }
        for (final MapEntry<dynamic, dynamic> entry in rawRow.entries) {
          final String header = entry.key.toString();
          headers.add(header);
          final String text = (entry.value ?? '').toString();
          if (text.trim().isNotEmpty) nonEmptyCells += 1;
          if (text.length > limits.maxCellTextLength) {
            throw FormatException(
              'Cella troppo lunga in "$sheetName"; limite ${limits.maxCellTextLength}.',
            );
          }
        }
      }
      if (nonEmptyCells > limits.maxNonEmptyCells) {
        throw FormatException(
          'Troppe celle non vuote: $nonEmptyCells; limite ${limits.maxNonEmptyCells}.',
        );
      }

      final List<LegacyScaleFieldMatch> sheetMatches = matchHeaders(headers)
          .map(
            (match) => LegacyScaleFieldMatch(
              targetField: match.targetField,
              sourceHeader: match.sourceHeader,
              score: match.score,
              sourceSheetName: sheetName,
            ),
          )
          .toList(growable: false);
      allMatches.addAll(sheetMatches);

      final Map<String, String> sourceByTarget = <String, String>{
        for (final LegacyScaleFieldMatch match in sheetMatches)
          match.targetField: match.sourceHeader,
      };
      if (!sourceByTarget.containsKey('dateTime') ||
          !sourceByTarget.containsKey('weightKg')) {
        globalWarnings.add(
          'Foglio "$sheetName" ignorato: colonne data/ora o peso non riconosciute.',
        );
        continue;
      }

      for (int rowIndex = 0; rowIndex < rawRows.length; rowIndex += 1) {
        final dynamic raw = rawRows[rowIndex];
        if (raw is! Map) continue;
        sourceSequence += 1;
        final Map<String, Object?> source = <String, Object?>{
          for (final MapEntry<dynamic, dynamic> entry in raw.entries)
            entry.key.toString(): entry.value,
        };
        final List<String> warnings = <String>[];
        final _ParsedDateTime? parsedDate = _parseDateTime(
          source[sourceByTarget['dateTime']],
        );
        final double? weightKg = _number(source[sourceByTarget['weightKg']]);
        if (parsedDate == null || weightKg == null || weightKg <= 0) {
          globalWarnings.add(
            'Foglio "$sheetName", riga ${rowIndex + 2} ignorata: '
            'data/ora o peso non valido.',
          );
          continue;
        }

        final Map<String, Object?> values = <String, Object?>{};
        for (final MapEntry<String, String> match in sourceByTarget.entries) {
          if (match.key == 'dateTime' || match.key == 'weightKg') continue;
          final Object? rawValue = source[match.value];
          if (match.key == 'physiqueRating') {
            final String text = (rawValue ?? '').toString().trim();
            if (text.isNotEmpty) values[match.key] = text;
          } else {
            final double? value = _number(rawValue);
            if (value != null) values[match.key] = value;
          }
        }

        final Set<String> mappedHeaders = sourceByTarget.values.toSet();
        final Map<String, Object?> unmapped = <String, Object?>{};
        for (final MapEntry<String, Object?> entry in source.entries) {
          if (mappedHeaders.contains(entry.key)) continue;
          final String value = (entry.value ?? '').toString().trim();
          if (value.isNotEmpty) unmapped[entry.key] = entry.value;
        }
        if (unmapped.isNotEmpty) {
          warnings.add('Campi non modellati conservati nelle note.');
        }
        if (!parsedDate.hasExplicitTime) {
          warnings.add(
            'Orario assente: nella selezione "una per giorno" questa riga '
            'precede qualsiasi riga con orario valido.',
          );
        }

        rows.add(
          LegacyScaleImportRow(
            index: sourceSequence,
            sourceSequence: sourceSequence,
            sourceSheetIndex: sheetIndex,
            sourceSheetName: sheetName,
            sourceRowNumber: rowIndex + 2,
            dateTime: parsedDate.value,
            hasExplicitTime: parsedDate.hasExplicitTime,
            weightKg: weightKg,
            values: Map<String, Object?>.unmodifiable(values),
            unmappedValues: Map<String, Object?>.unmodifiable(unmapped),
            warnings: List<String>.unmodifiable(warnings),
          ),
        );
      }

      final Set<String> matchedHeaders = sheetMatches
          .map((LegacyScaleFieldMatch match) => match.sourceHeader)
          .toSet();
      unmatchedHeaders.addAll(
        headers.where((String header) => !matchedHeaders.contains(header)),
      );
    }

    if (sheetNames.isEmpty) {
      throw const FormatException('Nessun foglio non vuoto trovato.');
    }
    if (rows.isEmpty) {
      throw const FormatException(
          'Nessuna misurazione valida trovata nel file.');
    }

    rows.sort((LegacyScaleImportRow a, LegacyScaleImportRow b) {
      final int dateCompare = a.dateTime.compareTo(b.dateTime);
      if (dateCompare != 0) return dateCompare;
      return a.sourceSequence.compareTo(b.sourceSequence);
    });
    final List<String> sortedUnmatched = unmatchedHeaders.toList()..sort();

    return LegacyScaleImportPreview(
      filePath: filePath,
      sheetNames: List<String>.unmodifiable(sheetNames),
      matches: List<LegacyScaleFieldMatch>.unmodifiable(allMatches),
      rows: List<LegacyScaleImportRow>.unmodifiable(rows),
      unmatchedHeaders: List<String>.unmodifiable(sortedUnmatched),
      warnings: List<String>.unmodifiable(globalWarnings),
    );
  }

  List<LegacyScaleFieldMatch> matchHeaders(Iterable<String> rawHeaders) {
    final Set<String> headers = rawHeaders.toSet();
    final List<LegacyScaleFieldMatch> matches = <LegacyScaleFieldMatch>[];
    final Set<String> consumed = <String>{};
    for (final MapEntry<String, List<String>> target in aliases.entries) {
      String? bestHeader;
      double bestScore = 0;
      for (final String header in headers) {
        if (consumed.contains(header)) continue;
        for (final String alias in target.value) {
          final double score = _similarity(header, alias);
          if (score > bestScore) {
            bestScore = score;
            bestHeader = header;
          }
        }
      }
      if (bestHeader != null && bestScore >= 0.58) {
        consumed.add(bestHeader);
        matches.add(
          LegacyScaleFieldMatch(
            targetField: target.key,
            sourceHeader: bestHeader,
            score: bestScore,
          ),
        );
      }
    }
    return matches;
  }

  double _similarity(String left, String right) {
    final String a = _normalize(left);
    final String b = _normalize(right);
    if (a == b && a.isNotEmpty) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    if (a.contains(b) || b.contains(a)) {
      final int shortest =
          math.min(a.length, b.length).clamp(1, b.length).toInt();
      return 0.88 + (0.1 * shortest / b.length);
    }
    final Set<String> aTokens =
        a.split(' ').where((String value) => value.isNotEmpty).toSet();
    final Set<String> bTokens =
        b.split(' ').where((String value) => value.isNotEmpty).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0;
    final int intersection = aTokens.intersection(bTokens).length;
    final int union = aTokens.union(bTokens).length;
    return intersection / union;
  }

  String _normalize(String input) {
    String value = input.toLowerCase().trim();
    const Map<String, String> replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'è': 'e',
      'é': 'e',
      'ì': 'i',
      'í': 'i',
      'ò': 'o',
      'ó': 'o',
      'ù': 'u',
      'ú': 'u',
      '%': ' percent ',
    };
    replacements.forEach((String from, String to) {
      value = value.replaceAll(from, to);
    });
    return value
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double? _number(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw == null) return null;
    final RegExpMatch? match = RegExp(
      r'-?\d+(?:[.,]\d+)?',
    ).firstMatch(raw.toString().replaceAll(' ', ''));
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  _ParsedDateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) {
      return _ParsedDateTime(
        DateTime(
          raw.year,
          raw.month,
          raw.day,
          raw.hour,
          raw.minute,
          raw.second,
          raw.millisecond,
        ),
        raw.hour != 0 || raw.minute != 0 || raw.second != 0,
      );
    }
    if (raw is num) return _parseExcel1900Serial(raw.toDouble());

    final String value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    final bool hasTime = RegExp(r'(?:T|\s)\d{1,2}:\d{2}').hasMatch(value);
    final DateTime? direct = DateTime.tryParse(value);
    if (direct != null) {
      return _ParsedDateTime(
        DateTime(
          direct.year,
          direct.month,
          direct.day,
          direct.hour,
          direct.minute,
          direct.second,
          direct.millisecond,
        ),
        hasTime,
      );
    }

    const List<(String, bool)> patterns = <(String, bool)>[
      ('dd/MM/yyyy HH:mm:ss', true),
      ('dd/MM/yyyy HH:mm', true),
      ('dd-MM-yyyy HH:mm:ss', true),
      ('dd-MM-yyyy HH:mm', true),
      ('yyyy/MM/dd HH:mm:ss', true),
      ('yyyy/MM/dd HH:mm', true),
      ('dd/MM/yyyy', false),
      ('dd-MM-yyyy', false),
    ];
    for (final (String pattern, bool explicitTime) in patterns) {
      try {
        return _ParsedDateTime(
          DateFormat(pattern).parseStrict(value),
          explicitTime,
        );
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  _ParsedDateTime? _parseExcel1900Serial(double serial) {
    if (!serial.isFinite || serial <= 0) return null;
    final int wholeDays = serial.floor();
    if (wholeDays == 60) {
      // Excel exposes the non-existent 1900-02-29. Reject it explicitly.
      return null;
    }
    final int adjustedDays = wholeDays > 60 ? wholeDays - 1 : wholeDays;
    final double fraction = serial - wholeDays;
    final int milliseconds = (fraction * Duration.millisecondsPerDay)
        .round()
        .clamp(0, Duration.millisecondsPerDay - 1)
        .toInt();
    // Use UTC only as a calendar arithmetic helper, then construct a local
    // date from the resulting fields. This avoids timezone and DST shifts
    // without converting the spreadsheet value from UTC to local time.
    final DateTime calendarDay = DateTime.utc(1899, 12, 31).add(
      Duration(days: adjustedDays),
    );
    final int hour = milliseconds ~/ Duration.millisecondsPerHour;
    final int minute = (milliseconds % Duration.millisecondsPerHour) ~/
        Duration.millisecondsPerMinute;
    final int second = (milliseconds % Duration.millisecondsPerMinute) ~/
        Duration.millisecondsPerSecond;
    final int millisecond = milliseconds % Duration.millisecondsPerSecond;
    final DateTime value = DateTime(
      calendarDay.year,
      calendarDay.month,
      calendarDay.day,
      hour,
      minute,
      second,
      millisecond,
    );
    return _ParsedDateTime(value, milliseconds > 0);
  }
}

class _ParsedDateTime {
  const _ParsedDateTime(this.value, this.hasExplicitTime);

  final DateTime value;
  final bool hasExplicitTime;
}
