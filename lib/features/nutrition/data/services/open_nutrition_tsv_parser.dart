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
    'description',
    'display_name',
  ];

  void readHeader(String line) {
    headers = parseTsvLine(line).map((value) => value.trim()).toList();
    _index = <String, int>{
      for (var index = 0; index < headers.length; index += 1)
        _normalizeKey(headers[index]): index,
    };
    if (!_hasAny(idAliases)) {
      throw OpenNutritionSchemaException(
        'Nessuna colonna identificativa supportata. Intestazioni: $headers',
      );
    }
    if (!_hasAny(nameAliases)) {
      throw OpenNutritionSchemaException(
        'Nessuna colonna nome supportata. Intestazioni: $headers',
      );
    }
  }

  OpenNutritionParsedRow parseRow(String line) {
    final values = parseTsvLine(line);
    if (values.length > headers.length) {
      return const OpenNutritionParsedRow(
        entity: null,
        warning: 'Numero di colonne superiore allo schema.',
      );
    }
    final row = <String, String>{};
    for (var index = 0; index < headers.length; index += 1) {
      row[headers[index]] = index < values.length ? values[index].trim() : '';
    }

    final externalId = _first(row, idAliases);
    final name = _first(row, nameAliases);
    if (externalId.isEmpty || name.isEmpty) {
      return const OpenNutritionParsedRow(
        entity: null,
        warning: 'ID o nome mancante.',
      );
    }

    final nutritionRaw = _first(row, const <String>[
      'nutrition_100g',
      'nutrients_100g',
      'nutrition',
      'nutrients',
    ]);
    final nutrition = _decodeJsonMap(nutritionRaw);
    final brand = _first(row, const <String>['brand', 'brand_name', 'brands']);
    final barcode = _first(row, const <String>[
      'barcode',
      'ean',
      'ean13',
      'code',
      'gtin',
    ]);
    final alternateNames = _jsonOrDefault(
      _first(row, const <String>['alternate_names', 'aliases']),
      '[]',
    );
    final labels = _jsonOrDefault(
      _first(row, const <String>['labels', 'tags']),
      '[]',
    );
    final source = _jsonOrDefault(
      _first(row, const <String>['source', 'sources']),
      '{}',
    );
    final ingredientAnalysis = _jsonOrDefault(
      _first(row, const <String>['ingredient_analysis']),
      '{}',
    );

    final kcal = _nutrient(nutrition, const <String>[
      'kcal',
      'calories',
      'energy_kcal',
      'energy-kcal',
    ]);
    final protein = _nutrient(nutrition, const <String>['protein', 'proteins']);
    final carbs = _nutrient(nutrition, const <String>[
      'carbohydrates',
      'carbs',
      'carbohydrate',
    ]);
    final fat = _nutrient(nutrition, const <String>['fat', 'total_fat']);
    final fiber = _nutrient(nutrition, const <String>['fiber', 'fibre']);
    final sugar = _nutrient(nutrition, const <String>['sugars', 'sugar']);
    final saturated = _nutrient(nutrition, const <String>[
      'saturated_fat',
      'saturated-fat',
      'saturates',
    ]);
    final trans = _nutrient(nutrition, const <String>[
      'trans_fat',
      'trans-fat',
    ]);
    final salt = _nutrient(nutrition, const <String>['salt']);
    final sodium = _nutrient(nutrition, const <String>['sodium']);

    final knownNormalized = <String>{
      ...idAliases,
      ...nameAliases,
      'brand',
      'brand_name',
      'brands',
      'barcode',
      'ean',
      'ean13',
      'code',
      'gtin',
      'alternate_names',
      'aliases',
      'description',
      'type',
      'food_type',
      'category',
      'labels',
      'tags',
      'ingredients',
      'ingredients_text',
      'ingredient_analysis',
      'source',
      'sources',
      'serving',
      'package_size',
      'nutrition_100g',
      'nutrients_100g',
      'nutrition',
      'nutrients',
    }.map(_normalizeKey).toSet();
    final additional = <String, String>{
      for (final entry in row.entries)
        if (!knownNormalized.contains(_normalizeKey(entry.key)) &&
            entry.value.isNotEmpty)
          entry.key: entry.value,
    };

    final sourceText = '$source $labels $ingredientAnalysis'.toLowerCase();
    final fromOff = sourceText.contains('open food facts') ||
        sourceText.contains('openfoodfacts');
    final estimated = sourceText.contains('estimated') ||
        sourceText.contains('estimate') ||
        sourceText.contains('model') ||
        sourceText.contains('generated');
    final normalizedName = normalizeSearch(name);
    final normalizedBrand = normalizeSearch(brand);

    return OpenNutritionParsedRow(
      warning: '',
      entity: OpenNutritionFoodEntity(
        externalFoodId: externalId,
        importBatchId: importBatchId,
        datasetVersion: datasetVersion,
        name: name,
        normalizedName: normalizedName,
        alternateNamesJson: alternateNames,
        description: _first(row, const <String>['description']),
        typeCode: _first(row, const <String>['type', 'food_type', 'category']),
        brand: brand,
        normalizedBrand: normalizedBrand,
        barcode: barcode,
        labelsJson: labels,
        ingredientsText: _first(row, const <String>[
          'ingredients',
          'ingredients_text',
        ]),
        ingredientAnalysisJson: ingredientAnalysis,
        sourceJson: source,
        servingJson: _jsonOrDefault(
          _first(row, const <String>['serving']),
          '{}',
        ),
        packageSizeJson: _jsonOrDefault(
          _first(row, const <String>['package_size']),
          '{}',
        ),
        nutrition100gJson: nutritionRaw.isEmpty ? '{}' : nutritionRaw,
        additionalFieldsJson: jsonEncode(additional),
        normalizedSearchText: <String>[
          normalizedName,
          normalizedBrand,
          normalizeSearch(barcode),
          normalizeSearch(alternateNames),
        ].where((part) => part.isNotEmpty).join(' '),
        kcalPer100g: kcal,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        fiberPer100g: fiber,
        sugarPer100g: sugar,
        saturatedFatPer100g: saturated,
        transFatPer100g: trans,
        saltPer100g: salt,
        sodiumPer100g: sodium,
        hasCompleteMacros: kcal > 0 && protein >= 0 && carbs >= 0 && fat >= 0,
        hasEstimatedValues: estimated,
        fromOpenFoodFacts: fromOff,
        importedAtEpochMs: importedAtEpochMs,
      ),
    );
  }

  bool _hasAny(List<String> aliases) => aliases.any(_index.containsKey);

  String _first(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final normalized = _normalizeKey(alias);
      for (final entry in row.entries) {
        if (_normalizeKey(entry.key) == normalized && entry.value.isNotEmpty) {
          return entry.value;
        }
      }
    }
    return '';
  }

  static List<String> parseTsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index += 1) {
      final character = line[index];
      if (character == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          quoted = !quoted;
        }
      } else if (character == '\t' && !quoted) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  static String normalizeSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9à-ÿ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalizeKey(String value) =>
      value.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_').trim();

  static String _jsonOrDefault(String value, String fallback) {
    if (value.trim().isEmpty) return fallback;
    try {
      jsonDecode(value);
      return value;
    } catch (_) {
      return jsonEncode(value);
    }
  }

  static Map<String, dynamic> _decodeJsonMap(String value) {
    if (value.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static double _nutrient(Map<String, dynamic> map, List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeKey).toSet();
    double? visit(dynamic value, [String key = '']) {
      final normalizedKey = _normalizeKey(key);
      if (normalizedAliases.contains(normalizedKey)) {
        final number = _numberFrom(value);
        if (number != null) return number;
      }
      if (value is Map) {
        for (final entry in value.entries) {
          final result = visit(entry.value, entry.key.toString());
          if (result != null) return result;
        }
      } else if (value is List) {
        for (final item in value) {
          final result = visit(item, key);
          if (result != null) return result;
        }
      }
      return null;
    }

    final result = visit(map) ?? 0;
    if (!result.isFinite || result < 0) return 0;
    return result;
  }

  static double? _numberFrom(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitized =
          value.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(sanitized);
    }
    if (value is Map) {
      for (final key in const <String>[
        'value',
        'amount',
        'per_100g',
        'quantity',
      ]) {
        if (value.containsKey(key)) {
          final result = _numberFrom(value[key]);
          if (result != null) return result;
        }
      }
    }
    return null;
  }
}
