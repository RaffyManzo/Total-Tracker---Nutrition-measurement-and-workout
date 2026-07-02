import 'dart:async';
import 'dart:convert';

import '../entities/open_nutrition_food_entity.dart';

class OpenNutritionSchemaException implements Exception {
  OpenNutritionSchemaException(this.message);
  final String message;

  @override
  String toString() => 'OpenNutritionSchemaException: $message';
}

class OpenNutritionParsedRow {
  const OpenNutritionParsedRow({required this.entity, required this.warning});

  final OpenNutritionFoodEntity? entity;
  final String warning;

  bool get isValid => entity != null;
}

/// Streaming RFC-4180-like TSV decoder. It keeps quote state across chunks,
/// therefore quoted tabs and quoted CR/LF do not desynchronise subsequent rows.
class OpenNutritionTsvRecordDecoder
    extends StreamTransformerBase<String, List<String>> {
  const OpenNutritionTsvRecordDecoder();

  @override
  Stream<List<String>> bind(Stream<String> stream) async* {
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var quotePending = false;
    var firstCharacter = true;
    var skipLfAfterCr = false;

    await for (final chunk in stream) {
      for (var index = 0; index < chunk.length; index += 1) {
        final char = chunk[index];
        if (firstCharacter) {
          firstCharacter = false;
          if (char == '\uFEFF') continue;
        }
        if (skipLfAfterCr) {
          skipLfAfterCr = false;
          if (char == '\n') continue;
        }

        if (quotePending) {
          quotePending = false;
          if (char == '"') {
            field.write('"');
            continue;
          }
          inQuotes = false;
        }

        if (inQuotes) {
          if (char == '"') {
            quotePending = true;
          } else {
            field.write(char);
          }
          continue;
        }

        if (char == '"' && field.isEmpty) {
          inQuotes = true;
        } else if (char == '\t') {
          row.add(field.toString());
          field.clear();
        } else if (char == '\r' || char == '\n') {
          row.add(field.toString());
          field.clear();
          yield List<String>.unmodifiable(row);
          row.clear();
          if (char == '\r') skipLfAfterCr = true;
        } else {
          field.write(char);
        }
      }
    }

    if (quotePending) inQuotes = false;
    if (inQuotes) {
      throw const FormatException('Campo TSV quotato non terminato.');
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      yield List<String>.unmodifiable(row);
    }
  }
}

class OpenNutritionTsvParser {
  OpenNutritionTsvParser({
    required this.datasetVersion,
    required this.importBatchId,
    required this.importedAtEpochMs,
  });

  final String datasetVersion;
  final String importBatchId;
  final int importedAtEpochMs;

  late final List<String> headers;
  late final Map<String, int> _index;

  static const List<String> idAliases = <String>[
    'id',
    'food_id',
    'uuid',
    'fdc_id',
    'external_id',
  ];
  static const List<String> nameAliases = <String>[
    'name',
    'food_name',
    'display_name',
  ];

  void readHeader(String line) => readHeaderRecord(parseTsvLine(line));

  void readHeaderRecord(List<String> values) {
    headers = values
        .map((String value) => value.replaceFirst('\uFEFF', '').trim())
        .toList(growable: false);
    _index = <String, int>{
      for (var index = 0; index < headers.length; index += 1)
        _normalizeKey(headers[index]): index,
    };
    if (!_hasAny(idAliases)) {
      throw OpenNutritionSchemaException(
        'Nessuna colonna identificativa supportata. Intestazioni: $headers',
      );
    }
    if (!_hasAny(nameAliases) && !_index.containsKey('alternate_names')) {
      throw OpenNutritionSchemaException(
        'Nessuna colonna nome supportata. Intestazioni: $headers',
      );
    }
  }

  OpenNutritionParsedRow parseRow(String line) {
    return parseRecord(parseTsvLine(line));
  }

  OpenNutritionParsedRow parseRecord(List<String> fields) {
    if (fields.every((String value) => value.trim().isEmpty)) {
      return const OpenNutritionParsedRow(entity: null, warning: 'Riga vuota');
    }

    final externalId = _first(fields, idAliases);
    if (externalId.isEmpty) {
      return const OpenNutritionParsedRow(
        entity: null,
        warning: 'Identificativo mancante',
      );
    }

    final alternateNames = _decodeStringList(_value(fields, 'alternate_names'));
    final rawName = _first(fields, nameAliases);
    final description = _scalar(_value(fields, 'description'));
    final name = _safeName(rawName).isNotEmpty
        ? _safeName(rawName)
        : alternateNames.map(_safeName).firstWhere(
              (String value) => value.isNotEmpty,
              orElse: () => _safeDescription(description),
            );
    if (name.isEmpty) {
      return const OpenNutritionParsedRow(
        entity: null,
        warning: 'Nome assente o strutturato',
      );
    }

    final nutritionRaw = _value(fields, 'nutrition_100g');
    final nutrition = _decodeJsonMap(nutritionRaw);
    final kcal = _nutrient(
      fields,
      nutrition,
      const <String>['energy', 'energy_kcal', 'energy-kcal', 'calories', 'kcal'],
      energy: true,
    );
    final protein = _nutrient(
      fields,
      nutrition,
      const <String>['protein', 'proteins'],
    );
    final carbs = _nutrient(
      fields,
      nutrition,
      const <String>['carbohydrate', 'carbohydrates', 'carbs'],
    );
    final fat = _nutrient(
      fields,
      nutrition,
      const <String>['fat', 'total_fat'],
    );
    final fiber = _nutrient(
      fields,
      nutrition,
      const <String>['fiber', 'fibre', 'dietary_fiber'],
    );
    final sugar = _nutrient(
      fields,
      nutrition,
      const <String>['sugar', 'sugars'],
    );
    final saturated = _nutrient(
      fields,
      nutrition,
      const <String>['saturated_fat', 'saturated-fat', 'saturates'],
    );
    final trans = _nutrient(
      fields,
      nutrition,
      const <String>['trans_fat', 'trans-fat'],
    );
    final salt = _nutrient(fields, nutrition, const <String>['salt']);
    final sodium = _nutrient(fields, nutrition, const <String>['sodium']);

    final sourceRaw = _value(fields, 'source');
    final source = _decodeJson(sourceRaw);
    final additional = _unknownFields(fields);
    final imageUrl = _firstNonEmpty(<String>[
      _first(fields, const <String>[
        'image_url',
        'image_front_url',
        'image',
        'photo_url',
      ]),
      _findStringByKeys(source, const <String>[
        'image_url',
        'image_front_url',
        'image',
      ]),
      _findStringByKeys(additional, const <String>[
        'image_url',
        'image_front_url',
        'image',
      ]),
    ]);
    final imageSmallUrl = _firstNonEmpty(<String>[
      _first(fields, const <String>['image_small_url', 'thumbnail_url']),
      _findStringByKeys(source, const <String>[
        'image_small_url',
        'thumbnail_url',
      ]),
    ]);

    final brand = _first(fields, const <String>['brand', 'brands']);
    final labelsRaw = _value(fields, 'labels');
    final ingredientsRaw = _value(fields, 'ingredients');
    final ingredientAnalysisRaw = _value(fields, 'ingredient_analysis');
    final servingRaw = _value(fields, 'serving');
    final packageSizeRaw = _value(fields, 'package_size');
    final barcode = _first(fields, const <String>[
      'ean_13',
      'ean13',
      'ean',
      'barcode',
      'gtin',
      'code',
    ]).replaceAll(RegExp(r'[^0-9A-Za-z]'), '');

    final nutritionValues = <double?>[
      kcal,
      protein,
      carbs,
      fat,
      fiber,
      sugar,
      saturated,
      trans,
      salt,
      sodium,
    ];
    final hasNutritionData = nutritionValues.any((double? value) => value != null);
    final hasCompleteMacros =
        protein != null && carbs != null && fat != null && kcal != null;
    final sourceText = jsonEncode(source).toLowerCase();
    final hasEstimatedValues = sourceText.contains('estimated') ||
        sourceText.contains('derived') ||
        nutritionRaw.toLowerCase().contains('estimated');

    final normalizedName = normalizeSearch(name);
    final normalizedBrand = normalizeSearch(brand);
    final normalizedSearchText = normalizeSearch(
      <String>[
        name,
        brand,
        barcode,
        ...alternateNames,
        description,
      ].join(' '),
    );

    return OpenNutritionParsedRow(
      warning: hasNutritionData ? '' : 'Nutrienti assenti',
      entity: OpenNutritionFoodEntity(
        externalFoodId: externalId,
        importBatchId: importBatchId,
        datasetVersion: datasetVersion,
        name: name,
        normalizedName: normalizedName,
        alternateNamesJson: jsonEncode(alternateNames),
        description: description,
        typeCode: _value(fields, 'type').trim(),
        brand: brand,
        normalizedBrand: normalizedBrand,
        barcode: barcode,
        imageUrl: _validUrl(imageUrl),
        imageSmallUrl: _validUrl(imageSmallUrl),
        labelsJson: _jsonString(labelsRaw, fallback: '[]'),
        ingredientsText: _ingredientsText(ingredientsRaw),
        ingredientAnalysisJson:
            _jsonString(ingredientAnalysisRaw, fallback: '{}'),
        sourceJson: jsonEncode(source),
        servingJson: _jsonString(servingRaw, fallback: '{}'),
        packageSizeJson: _jsonString(packageSizeRaw, fallback: '{}'),
        nutrition100gJson: jsonEncode(nutrition),
        additionalFieldsJson: jsonEncode(additional),
        normalizedSearchText: normalizedSearchText,
        kcalPer100g: kcal ?? 0,
        proteinPer100g: protein ?? 0,
        carbsPer100g: carbs ?? 0,
        fatPer100g: fat ?? 0,
        fiberPer100g: fiber ?? 0,
        sugarPer100g: sugar ?? 0,
        saturatedFatPer100g: saturated ?? 0,
        transFatPer100g: trans ?? 0,
        saltPer100g: salt ?? 0,
        sodiumPer100g: sodium ?? 0,
        hasNutritionData: hasNutritionData,
        hasCompleteMacros: hasCompleteMacros,
        hasEstimatedValues: hasEstimatedValues,
        fromOpenFoodFacts: sourceText.contains('open food facts') ||
            sourceText.contains('openfoodfacts'),
        importedAtEpochMs: importedAtEpochMs,
      ),
    );
  }

  static String normalizeSearch(String input) {
    var value = input.toLowerCase().trim();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
    };
    replacements.forEach((String from, String to) {
      value = value.replaceAll(from, to);
    });
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  bool _hasAny(List<String> aliases) =>
      aliases.any((String key) => _index.containsKey(_normalizeKey(key)));

  String _value(List<String> fields, String key) {
    final position = _index[_normalizeKey(key)];
    if (position == null || position >= fields.length) return '';
    return fields[position].trim();
  }

  String _first(List<String> fields, List<String> aliases) {
    for (final alias in aliases) {
      final value = _value(fields, alias);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Map<String, Object?> _unknownFields(List<String> fields) {
    const known = <String>{
      'id',
      'name',
      'description',
      'type',
      'labels',
      'nutrition_100g',
      'alternate_names',
      'source',
      'serving',
      'package_size',
      'ingredient_analysis',
      'ean_13',
      'ingredients',
    };
    final result = <String, Object?>{};
    for (var index = 0; index < headers.length; index += 1) {
      final key = _normalizeKey(headers[index]);
      if (known.contains(key) || index >= fields.length) continue;
      final value = fields[index].trim();
      if (value.isNotEmpty) result[headers[index]] = _decodeJson(value);
    }
    return result;
  }

  double? _nutrient(
    List<String> fields,
    Map<String, Object?> nutrition,
    List<String> aliases, {
    bool energy = false,
  }) {
    for (final alias in aliases) {
      for (final variant in <String>[
        alias,
        '${alias}_100g',
        alias.replaceAll('_', '-'),
        '${alias.replaceAll('_', '-')}_100g',
      ]) {
        final flat = _numberWithUnit(_value(fields, variant));
        if (flat.value != null) {
          return energy ? _energyToKcal(flat.value!, flat.unit) : flat.value;
        }
      }
    }
    final match = _findNutrient(nutrition, aliases);
    if (match.value == null) return null;
    return energy ? _energyToKcal(match.value!, match.unit) : match.value;
  }

  _NumberWithUnit _findNutrient(Object? value, List<String> aliases) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = _normalizeKey(entry.key.toString())
            .replaceAll(RegExp(r'_?100g$'), '');
        if (aliases.any((String alias) =>
            key == _normalizeKey(alias).replaceAll(RegExp(r'_?100g$'), ''))) {
          final parsed = _numberWithUnit(entry.value);
          if (parsed.value != null) return parsed;
        }
      }
      for (final entry in value.entries) {
        final nested = _findNutrient(entry.value, aliases);
        if (nested.value != null) return nested;
      }
    } else if (value is List) {
      for (final item in value) {
        final nested = _findNutrient(item, aliases);
        if (nested.value != null) return nested;
      }
    }
    return const _NumberWithUnit(null, '');
  }

  _NumberWithUnit _numberWithUnit(Object? value) {
    if (value is num) return _NumberWithUnit(value.toDouble(), '');
    if (value is Map) {
      final rawValue = value['value'] ?? value['amount'] ?? value['quantity'];
      final unit = (value['unit'] ?? value['units'] ?? '').toString();
      final parsed = _asDouble(rawValue);
      return _NumberWithUnit(parsed, unit);
    }
    if (value is String) {
      final clean = value.trim();
      if (clean.isEmpty) return const _NumberWithUnit(null, '');
      final decoded = _decodeJson(clean);
      if (decoded is! String) return _numberWithUnit(decoded);
      final match = RegExp(
        r'(-?\d+(?:[\.,]\d+)?)\s*([a-zA-Zµμ]*)',
      ).firstMatch(clean);
      if (match == null) return const _NumberWithUnit(null, '');
      return _NumberWithUnit(
        double.tryParse(match.group(1)!.replaceAll(',', '.')),
        match.group(2) ?? '',
      );
    }
    return const _NumberWithUnit(null, '');
  }

  double _energyToKcal(double value, String unit) {
    final normalizedUnit = unit.toLowerCase().replaceAll(' ', '');
    if (normalizedUnit == 'kj' || normalizedUnit == 'kilojoule') {
      return value / 4.184;
    }
    return value;
  }

  Object? _decodeJson(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return <String, Object?>{};
    if (!(clean.startsWith('{') || clean.startsWith('['))) return clean;
    try {
      return jsonDecode(clean);
    } catch (_) {
      return clean;
    }
  }

  Map<String, Object?> _decodeJsonMap(String value) {
    final decoded = _decodeJson(value);
    if (decoded is Map) {
      return decoded.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
    }
    return <String, Object?>{};
  }

  List<String> _decodeStringList(String value) {
    final decoded = _decodeJson(value);
    if (decoded is List) {
      return decoded
          .map((Object? item) => _scalar(item))
          .where((String item) => item.isNotEmpty)
          .toList();
    }
    final scalar = _scalar(decoded);
    if (scalar.isEmpty) return const <String>[];
    return scalar
        .split(RegExp(r'[|;,]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  String _scalar(Object? value) {
    if (value == null || value is Map || value is List) return '';
    return value.toString().trim();
  }

  String _safeName(String value) {
    final clean = value.trim();
    if (clean.isEmpty || clean.length > 240) return '';
    if (clean.startsWith('{') || clean.startsWith('[')) return '';
    if (clean.contains('nutrition_100g') || clean.contains('ingredient_analysis')) {
      return '';
    }
    return clean;
  }

  String _safeDescription(String value) {
    final clean = _safeName(value);
    return clean.length <= 120 ? clean : '';
  }

  String _ingredientsText(String value) {
    final decoded = _decodeJson(value);
    if (decoded is String) return decoded.trim();
    if (decoded is List) {
      return decoded.map(_scalar).where((String item) => item.isNotEmpty).join(', ');
    }
    return '';
  }

  String _jsonString(String value, {required String fallback}) {
    final clean = value.trim();
    if (clean.isEmpty) return fallback;
    final decoded = _decodeJson(clean);
    return jsonEncode(decoded);
  }

  String _findStringByKeys(Object? value, List<String> keys) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (keys.map(_normalizeKey).contains(key)) {
          final scalar = _scalar(entry.value);
          if (scalar.isNotEmpty) return scalar;
        }
      }
      for (final nested in value.values) {
        final result = _findStringByKeys(nested, keys);
        if (result.isNotEmpty) return result;
      }
    } else if (value is List) {
      for (final nested in value) {
        final result = _findStringByKeys(nested, keys);
        if (result.isNotEmpty) return result;
      }
    }
    return '';
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _validUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return '';
    }
    return uri.toString();
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static String _normalizeKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static List<String> parseTsvLine(String line) {
    final result = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var index = 0; index < line.length; index += 1) {
      final char = line[index];
      if (char == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          field.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == '\t' && !inQuotes) {
        result.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    result.add(field.toString());
    return result;
  }
}

class _NumberWithUnit {
  const _NumberWithUnit(this.value, this.unit);
  final double? value;
  final String unit;
}
