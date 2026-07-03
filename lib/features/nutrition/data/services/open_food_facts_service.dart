import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/preferences/food_service_preferences.dart';
import '../../domain/nutrition_codes.dart';
import '../entities/ingredient_entity.dart';

class FoodServiceDisabledException implements Exception {
  const FoodServiceDisabledException(this.serviceName);

  final String serviceName;

  @override
  String toString() => '$serviceName è disabilitato nelle impostazioni.';
}

class OpenFoodFactsSearchResponse {
  const OpenFoodFactsSearchResponse({
    required this.products,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<OpenFoodFactsProduct> products;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasNext {
    if (totalCount > 0) return page * pageSize < totalCount;
    return products.length >= pageSize;
  }
}

class OpenFoodFactsProduct {
  const OpenFoodFactsProduct({
    required this.code,
    required this.name,
    required this.brand,
    required this.quantity,
    required this.imageUrl,
    required this.imageSmallUrl,
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

  factory OpenFoodFactsProduct.fromJson(
    Map<String, dynamic> json, {
    String fallbackCode = '',
  }) {
    final Object? rawNutriments = json['nutriments'];
    final Map<String, dynamic> nutriments = rawNutriments is Map
        ? Map<String, dynamic>.from(rawNutriments)
        : const <String, dynamic>{};

    final String rawCode = _string(json['code']);
    final String code = rawCode.isEmpty ? fallbackCode : rawCode;
    final List<String> selectedImages =
        _selectedImageUrls(json['selected_images']);
    final String directSmall =
        _httpsUrl(_string(json['image_front_small_url']));
    final String directFront = _httpsUrl(_string(json['image_front_url']));
    final String directGeneric = _httpsUrl(_string(json['image_url']));

    final String smallImage = <String>[
      directSmall,
      ...selectedImages.where(_looksLikeSmallImage),
      directFront,
      directGeneric,
      ...selectedImages,
    ].firstWhere((String value) => value.isNotEmpty, orElse: () => '');

    final String image = <String>[
      directFront,
      ...selectedImages.where(
        (String value) => !_looksLikeSmallImage(value),
      ),
      directGeneric,
      smallImage,
    ].firstWhere((String value) => value.isNotEmpty, orElse: () => '');

    final String productName = <String>[
      _string(json['product_name_it']),
      _string(json['product_name']),
      _string(json['generic_name_it']),
      _string(json['generic_name']),
    ].firstWhere((String value) => value.isNotEmpty, orElse: () => '');

    final String explicitSourceUrl = _httpsUrl(_string(json['url']));

    return OpenFoodFactsProduct(
      code: code,
      name: productName,
      brand: _string(json['brands']),
      quantity: _string(json['quantity']),
      imageUrl: image,
      imageSmallUrl: smallImage,
      categories: _string(json['categories']),
      sourceUrl: explicitSourceUrl.isNotEmpty
          ? explicitSourceUrl
          : 'https://world.openfoodfacts.org/product/$code',
      kcal100: _nutrition(
        nutriments,
        const <String>['energy-kcal_100g', 'energy-kcal'],
      ),
      protein100: _nutrition(
        nutriments,
        const <String>['proteins_100g', 'proteins'],
      ),
      carbs100: _nutrition(
        nutriments,
        const <String>['carbohydrates_100g', 'carbohydrates'],
      ),
      fat100: _nutrition(
        nutriments,
        const <String>['fat_100g', 'fat'],
      ),
      fiber100: _nutrition(
        nutriments,
        const <String>['fiber_100g', 'fiber'],
      ),
      sugar100: _nutrition(
        nutriments,
        const <String>['sugars_100g', 'sugars'],
      ),
      salt100: _nutrition(
        nutriments,
        const <String>['salt_100g', 'salt'],
      ),
    );
  }

  final String code;
  final String name;
  final String brand;
  final String quantity;
  final String imageUrl;
  final String imageSmallUrl;
  final String categories;
  final String sourceUrl;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double fiber100;
  final double sugar100;
  final double salt100;

  String get preferredImageUrl =>
      imageSmallUrl.isNotEmpty ? imageSmallUrl : imageUrl;

  double? get packageQuantity => _parsePackageQuantity(quantity);

  bool get hasUsefulNutrition =>
      kcal100 > 0 ||
      protein100 > 0 ||
      carbs100 > 0 ||
      fat100 > 0 ||
      fiber100 > 0 ||
      sugar100 > 0;

  IngredientEntity toIngredientEntity() {
    return IngredientEntity(
      uuid: '',
      name: name,
      brand: brand,
      barcode: code,
      packageQuantity: packageQuantity,
      sourceTypeCode: IngredientSourceTypeCodes.openFoodFacts,
      sourceName: 'Open Food Facts',
      sourceUrl: sourceUrl,
      sourceExternalId: code,
      sourceDatasetVersion: 'api-v2',
      sourceLicenseCode: 'ODbL-1.0',
      sourceAttribution: '© Open Food Facts contributors',
      imageUrl: preferredImageUrl,
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

  static const int defaultPageSize = 20;
  static const String _fields =
      'code,product_name,product_name_it,generic_name,generic_name_it,'
      'brands,quantity,image_front_small_url,image_front_url,image_url,'
      'selected_images,categories,nutriments,url';
  static const Map<String, String> _headers = <String, String>{
    'User-Agent': 'TotalTracker/0.2.0 (Android; project repository contact)',
    'Accept': 'application/json',
  };

  Future<void> _guardEnabled() async {
    if (!await FoodServicePreferences.isOpenFoodFactsEnabled()) {
      throw const FoodServiceDisabledException('Open Food Facts');
    }
  }

  Future<OpenFoodFactsProduct?> findByBarcode(String barcode) async {
    await _guardEnabled();
    final String clean = barcode.trim();
    if (clean.isEmpty) return null;

    final Uri uri = _baseUri.replace(
      path: '/api/v2/product/$clean.json',
      queryParameters: const <String, String>{'fields': _fields},
    );
    final http.Response response = await _client.get(uri, headers: _headers);
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Open Food Facts HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Risposta Open Food Facts non valida.',
      );
    }
    final Object? product = decoded['product'];
    if (product is! Map) return null;

    return OpenFoodFactsProduct.fromJson(
      Map<String, dynamic>.from(product),
      fallbackCode: clean,
    );
  }

  Future<List<OpenFoodFactsProduct>> searchText(
    String query, {
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final OpenFoodFactsSearchResponse response = await searchTextPage(
      query,
      page: page,
      pageSize: pageSize,
    );
    return response.products;
  }

  Future<OpenFoodFactsSearchResponse> searchTextPage(
    String query, {
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    await _guardEnabled();
    final String clean = query.trim();
    final int safePage = page < 1 ? 1 : page;
    final int safePageSize = pageSize.clamp(1, 50).toInt();

    if (clean.length < 3) {
      return OpenFoodFactsSearchResponse(
        products: const <OpenFoodFactsProduct>[],
        page: safePage,
        pageSize: safePageSize,
        totalCount: 0,
      );
    }

    final Uri uri = _baseUri.replace(
      path: '/cgi/search.pl',
      queryParameters: <String, String>{
        'search_terms': clean,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page': '$safePage',
        'page_size': '$safePageSize',
        'fields': _fields,
      },
    );
    final http.Response response = await _client.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Open Food Facts HTTP ${response.statusCode}',
      );
    }

    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Risposta di ricerca Open Food Facts non valida.',
      );
    }

    final Object? products = decoded['products'];
    final List<OpenFoodFactsProduct> mapped = products is List
        ? products
            .whereType<Map>()
            .map(
              (Map value) => Map<String, dynamic>.from(value),
            )
            .map(OpenFoodFactsProduct.fromJson)
            .where(
              (OpenFoodFactsProduct product) =>
                  product.name.isNotEmpty && product.code.isNotEmpty,
            )
            .toList()
        : const <OpenFoodFactsProduct>[];

    return OpenFoodFactsSearchResponse(
      products: mapped,
      page: _int(decoded['page']) ?? safePage,
      pageSize: _int(decoded['page_size']) ?? safePageSize,
      totalCount: _int(decoded['count']) ?? 0,
    );
  }

  void dispose() => _client.close();
}

List<String> _selectedImageUrls(Object? raw) {
  final List<String> values = <String>[];

  void visit(Object? value) {
    if (value is String) {
      final String url = _httpsUrl(value);
      if (url.isNotEmpty && !values.contains(url)) {
        values.add(url);
      }
      return;
    }
    if (value is Map) {
      for (final Object? child in value.values) {
        visit(child);
      }
      return;
    }
    if (value is List) {
      for (final Object? child in value) {
        visit(child);
      }
    }
  }

  visit(raw);
  return values;
}

bool _looksLikeSmallImage(String value) {
  final String lower = value.toLowerCase();
  return lower.contains('.200.') ||
      lower.contains('.100.') ||
      lower.contains('/small/') ||
      lower.contains('small');
}

String _httpsUrl(String value) {
  final String clean = value.trim();
  if (clean.isEmpty) return '';
  final Uri? uri = Uri.tryParse(clean);
  if (uri == null || !uri.hasAuthority) return '';
  if (uri.scheme == 'https') return uri.toString();
  if (uri.scheme == 'http') {
    return uri.replace(scheme: 'https').toString();
  }
  return '';
}

String _string(Object? value) => value == null ? '' : value.toString().trim();

double _nutrition(
  Map<String, dynamic> nutriments,
  List<String> keys,
) {
  for (final String key in keys) {
    final double? value = _double(nutriments[key]);
    if (value != null) return value;
  }
  return 0;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(
      value.trim().replaceAll(',', '.'),
    );
  }
  return null;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value));
}

double? _parsePackageQuantity(String quantity) {
  if (quantity.trim().isEmpty) return null;
  final RegExpMatch? match =
      RegExp(r'(\\d+(?:[\\.,]\\d+)?)').firstMatch(quantity);
  if (match == null) return null;
  return double.tryParse(
    match.group(1)!.replaceAll(',', '.'),
  );
}
