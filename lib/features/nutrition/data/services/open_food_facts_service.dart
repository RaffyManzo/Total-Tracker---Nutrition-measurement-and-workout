import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';

class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.imageUrl,
    required this.categories,
    required this.sourceUrl,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.fiber100,
    required this.sugar100,
    required this.salt100,
  });

  final String code;
  final String name;
  final String brand;
  final String quantity;
  final String imageUrl;
  final String categories;
  final String sourceUrl;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final double sugar100;
  final double salt100;

  bool get hasUsefulNutrition {
    return kcal100 > 0 ||
        protein100 > 0 ||
        carbs100 > 0 ||
        fat100 > 0 ||
        fiber100 > 0 ||
        sugar100 > 0;
  }

  IngredientEntity toIngredientEntity() {
    return IngredientEntity(
      uuid: '',
      name: name,
      brand: brand,
      barcode: code,
      packageQuantity: _parsePackageQuantity(quantity),
      sourceTypeCode: IngredientSourceTypeCodes.openFoodFacts,
      sourceName: 'Open Food Facts',
      sourceUrl: sourceUrl,
      imageUrl: imageUrl,
      categories: categories,
      nutritionReferenceAmount: 100,
      nutritionReferenceUnitCode: NutritionUnitCodes.grams,
      kcalPerReference: kcal100,
      proteinPerReference: protein100,
      carbsPerReference: carbs100,
      fatPerReference: fat100,
      fiberPerReference: fiber100,
      sugarPerReference: sugar100,
      saltPerReference: salt100,
      createdAtEpochMs: 0,
      updatedAtEpochMs: 0,
    );
  }
}

class OpenFoodFactsService {
  OpenFoodFactsService({
    http.Client? client,
    Uri? baseUri,
  })  : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.parse('https://world.openfoodfacts.org');

  final http.Client _client;
  final Uri _baseUri;

  static const String _fields =
      'code,product_name,brands,quantity,image_front_url,'
      'image_url,categories,nutriments,url';
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'TotalTracker/0.1 (local-development)',
    'Accept': 'application/json',
  };

  Future<OpenFoodFactsProduct?> findByBarcode(String barcode) async {
    final String clean = barcode.trim();
    if (clean.isEmpty) {
      return null;
    }
    final Uri uri = _baseUri.replace(
      path: '/api/v2/product/$clean.json',
      queryParameters: <String, String>{'fields': _fields},
    );
    final http.Response response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Open Food Facts HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid Open Food Facts response.');
    }
    final Object? product = decoded['product'];
    if (product is! Map<String, Object?>) {
      return null;
    }
    return _productFromJson(product, fallbackCode: clean);
  }

  Future<List<OpenFoodFactsProduct>> searchText(String query) async {
    final String clean = query.trim();
    if (clean.isEmpty) {
      return const <OpenFoodFactsProduct>[];
    }
    final Uri uri = _baseUri.replace(
      path: '/cgi/search.pl',
      queryParameters: <String, String>{
        'search_terms': clean,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '20',
        'fields': _fields,
      },
    );
    final http.Response response = await _client.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Open Food Facts HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid Open Food Facts search response.');
    }
    final Object? products = decoded['products'];
    if (products is! List<Object?>) {
      return const <OpenFoodFactsProduct>[];
    }
    return products
        .whereType<Map<String, Object?>>()
        .map(_productFromJson)
        .where((OpenFoodFactsProduct product) => product.name.isNotEmpty)
        .toList();
  }

  OpenFoodFactsProduct _productFromJson(
    Map<String, Object?> json, {
    String? fallbackCode,
  }) {
    final Object? rawNutriments = json['nutriments'];
    final Map<String, Object?> nutriments =
        rawNutriments is Map<String, Object?>
            ? rawNutriments
            : const <String, Object?>{};
    final String code = _string(json['code']).isEmpty
        ? fallbackCode ?? ''
        : _string(json['code']);
    return OpenFoodFactsProduct(
      code: code,
      name: _string(json['product_name']),
      brand: _string(json['brands']),
      quantity: _string(json['quantity']),
      imageUrl: _string(json['image_front_url']).isEmpty
          ? _string(json['image_url'])
          : _string(json['image_front_url']),
      categories: _string(json['categories']),
      sourceUrl: _string(json['url']).isEmpty
          ? 'https://world.openfoodfacts.org/product/$code'
          : _string(json['url']),
      kcal100: _nutrition(nutriments, const <String>[
        'energy-kcal_100g',
        'energy-kcal',
      ]),
      protein100: _nutrition(nutriments, const <String>['proteins_100g']),
      carbs100: _nutrition(nutriments, const <String>['carbohydrates_100g']),
      fat100: _nutrition(nutriments, const <String>['fat_100g']),
      fiber100: _nutrition(nutriments, const <String>['fiber_100g']),
      sugar100: _nutrition(nutriments, const <String>['sugars_100g']),
      salt100: _nutrition(nutriments, const <String>['salt_100g']),
    );
  }
}

String _string(Object? value) {
  return value == null ? '' : value.toString().trim();
}

double _nutrition(Map<String, Object?> nutriments, List<String> keys) {
  for (final String key in keys) {
    final double? value = _double(nutriments[key]);
    if (value != null) {
      return value;
    }
  }
  return 0;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
  return null;
}

double? _parsePackageQuantity(String quantity) {
  if (quantity.trim().isEmpty) {
    return null;
  }
  final RegExpMatch? match = RegExp(r'(\d+(?:[\.,]\d+)?)').firstMatch(quantity);
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(1)!.replaceAll(',', '.'));
}
