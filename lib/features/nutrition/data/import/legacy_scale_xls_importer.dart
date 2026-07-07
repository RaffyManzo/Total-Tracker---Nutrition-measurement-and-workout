import 'package:excel2003/excel2003.dart';
import 'package:intl/intl.dart';

class LegacyScaleFieldMatch {
  const LegacyScaleFieldMatch({
    required this.targetField,
    required this.sourceHeader,
    required this.score,
  });

  final String targetField;
  final String sourceHeader;
  final double score;
}

class LegacyScaleImportRow {
  const LegacyScaleImportRow({
    required this.index,
    required this.dateTime,
    required this.weightKg,
    required this.values,
    required this.unmappedValues,
    required this.warnings,
  });

  final int index;
  final DateTime dateTime;
  final double weightKg;
  final Map<String, Object?> values;
  final Map<String, Object?> unmappedValues;
  final List<String> warnings;

  String get dateKey => DateFormat('yyyy-MM-dd').format(dateTime);
  String get measurementTime => DateFormat('HH:mm:ss').format(dateTime);
  String get duplicateKey => '$dateKey|$measurementTime';

  double? number(String key) {
    final Object? value = values[key];
    return value is num ? value.toDouble() : null;
  }

  String text(String key) => (values[key] ?? '').toString().trim();
}

class LegacyScaleImportPreview {
  const LegacyScaleImportPreview({
    required this.filePath,
    required this.sheetName,
    required this.matches,
    required this.rows,
    required this.unmatchedHeaders,
    required this.warnings,
  });

  final String filePath;
  final String sheetName;
  final List<LegacyScaleFieldMatch> matches;
  final List<LegacyScaleImportRow> rows;
  final List<String> unmatchedHeaders;
  final List<String> warnings;
}

class LegacyScaleXlsImporter {
  const LegacyScaleXlsImporter();

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

  LegacyScaleImportPreview read(String filePath) {
    final XlsReader reader = XlsReader(filePath);
    reader.open();
    if (reader.sheetCount <= 0) {
      throw const FormatException('Il file XLS non contiene fogli leggibili.');
    }
    final dynamic sheet = reader.sheet(0);
    final List<dynamic> rawRows = List<dynamic>.from(sheet.toMaps() as List);
    if (rawRows.isEmpty) {
      throw const FormatException('Il primo foglio non contiene misurazioni.');
    }

    final Set<String> headers = <String>{};
    for (final dynamic rawRow in rawRows) {
      if (rawRow is Map) {
        headers.addAll(rawRow.keys.map((Object? key) => key.toString()));
      }
    }
    final List<LegacyScaleFieldMatch> matches = matchHeaders(headers);
    final Map<String, String> sourceByTarget = <String, String>{
      for (final LegacyScaleFieldMatch match in matches)
        match.targetField: match.sourceHeader,
    };
    if (!sourceByTarget.containsKey('dateTime') ||
        !sourceByTarget.containsKey('weightKg')) {
      throw const FormatException(
        'Il file deve contenere almeno una colonna data/ora e una colonna peso.',
      );
    }

    final List<LegacyScaleImportRow> rows = <LegacyScaleImportRow>[];
    final List<String> globalWarnings = <String>[];
    for (int index = 0; index < rawRows.length; index += 1) {
      final dynamic raw = rawRows[index];
      if (raw is! Map) continue;
      final Map<String, Object?> source = <String, Object?>{
        for (final MapEntry<dynamic, dynamic> entry in raw.entries)
          entry.key.toString(): entry.value,
      };
      final List<String> warnings = <String>[];
      final DateTime? dateTime = _parseDateTime(
        source[sourceByTarget['dateTime']],
      );
      final double? weightKg = _number(source[sourceByTarget['weightKg']]);
      if (dateTime == null || weightKg == null || weightKg <= 0) {
        globalWarnings.add(
          'Riga ${index + 2} ignorata: data/ora o peso non valido.',
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
      rows.add(
        LegacyScaleImportRow(
          index: index,
          dateTime: dateTime,
          weightKg: weightKg,
          values: Map<String, Object?>.unmodifiable(values),
          unmappedValues: Map<String, Object?>.unmodifiable(unmapped),
          warnings: List<String>.unmodifiable(warnings),
        ),
      );
    }

    final Set<String> matchedHeaders = matches
        .map((LegacyScaleFieldMatch match) => match.sourceHeader)
        .toSet();
    final List<String> unmatchedHeaders = headers
        .where((String header) => !matchedHeaders.contains(header))
        .toList()
      ..sort();

    return LegacyScaleImportPreview(
      filePath: filePath,
      sheetName:
          reader.sheetNames.isEmpty ? 'Foglio 1' : reader.sheetNames.first,
      matches: List<LegacyScaleFieldMatch>.unmodifiable(matches),
      rows: List<LegacyScaleImportRow>.unmodifiable(rows),
      unmatchedHeaders: List<String>.unmodifiable(unmatchedHeaders),
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
    if (a == b) return 1;
    if (a.contains(b) || b.contains(a)) {
      final num shortest = a.length.clamp(1, b.length);
      return 0.88 + (0.1 * shortest.toDouble() / b.length.toDouble());
    }
    final Set<String> aTokens =
        a.split(' ').where((String v) => v.isNotEmpty).toSet();
    final Set<String> bTokens =
        b.split(' ').where((String v) => v.isNotEmpty).toSet();
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
    final RegExpMatch? match = RegExp(r'-?\d+(?:[.,]\d+)?')
        .firstMatch(raw.toString().replaceAll(' ', ''));
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  DateTime? _parseDateTime(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is num) {
      final DateTime origin = DateTime.utc(1899, 12, 30);
      return origin
          .add(Duration(milliseconds: (raw * 86400000).round()))
          .toLocal();
    }
    final String value = (raw ?? '').toString().trim();
    if (value.isEmpty) return null;
    final DateTime? direct = DateTime.tryParse(value);
    if (direct != null) return direct;
    const List<String> patterns = <String>[
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'yyyy/MM/dd HH:mm:ss',
      'yyyy/MM/dd HH:mm',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
    ];
    for (final String pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(value);
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}
