import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../../core/preferences/food_service_preferences.dart';
import '../entities/open_nutrition_food_entity.dart';

class OpenNutritionGatewayException implements Exception {
  const OpenNutritionGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenNutritionGatewayConfig {
  const OpenNutritionGatewayConfig({
    required this.baseUri,
    required this.publicKeyBytes,
    required this.keyId,
  });

  static const String _compiledUrl = String.fromEnvironment(
    'OPENNUTRITION_GATEWAY_URL',
  );
  static const String _compiledPublicKey = String.fromEnvironment(
    'OPENNUTRITION_GATEWAY_ED25519_PUBLIC_KEY',
  );
  static const String _compiledKeyId = String.fromEnvironment(
    'OPENNUTRITION_GATEWAY_KEY_ID',
    defaultValue: 'primary',
  );
  static const bool _allowCustomGateway = bool.fromEnvironment(
    'OPENNUTRITION_ALLOW_CUSTOM_GATEWAY',
    defaultValue: true,
  );

  final Uri baseUri;
  final Uint8List publicKeyBytes;
  final String keyId;

  static bool get allowsRuntimeConfiguration =>
      kDebugMode || _allowCustomGateway;

  static Future<OpenNutritionGatewayConfig?> load() async {
    String rawUrl = _compiledUrl.trim();
    String rawKey = _compiledPublicKey.trim();
    String keyId = _compiledKeyId.trim();

    if ((rawUrl.isEmpty || rawKey.isEmpty) && allowsRuntimeConfiguration) {
      rawUrl = await FoodServicePreferences.getString(
        FoodServicePreferenceKeys.openNutritionGatewayUrl,
      );
      rawKey = await FoodServicePreferences.getString(
        FoodServicePreferenceKeys.openNutritionGatewayPublicKey,
      );
      keyId = await FoodServicePreferences.getString(
        FoodServicePreferenceKeys.openNutritionGatewayKeyId,
      );
    }

    if (rawUrl.isEmpty && rawKey.isEmpty) return null;
    return validate(
      rawUrl: rawUrl,
      rawPublicKey: rawKey,
      rawKeyId: keyId,
    );
  }

  static OpenNutritionGatewayConfig validate({
    required String rawUrl,
    required String rawPublicKey,
    required String rawKeyId,
  }) {
    final Uri? uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        uri.port != 443) {
      throw const OpenNutritionGatewayException(
        'Il gateway deve usare HTTPS, porta 443 e nessun userinfo, query o fragment.',
      );
    }

    final String host = uri.host.toLowerCase();
    if (!_isAllowedPublicHostname(host)) {
      throw const OpenNutritionGatewayException(
        'Hostname gateway non consentito.',
      );
    }

    Uint8List publicKey;
    try {
      publicKey = Uint8List.fromList(base64Decode(rawPublicKey.trim()));
    } catch (_) {
      throw const OpenNutritionGatewayException(
        'Chiave pubblica Ed25519 non valida.',
      );
    }
    if (publicKey.length != 32) {
      throw const OpenNutritionGatewayException(
        'La chiave pubblica Ed25519 deve essere di 32 byte.',
      );
    }

    final String keyId = rawKeyId.trim().isEmpty ? 'primary' : rawKeyId.trim();
    if (!RegExp(r'^[A-Za-z0-9._-]{1,64}$').hasMatch(keyId)) {
      throw const OpenNutritionGatewayException(
        'Identificativo della chiave non valido.',
      );
    }

    final String normalizedPath = uri.path.isEmpty || uri.path == '/'
        ? ''
        : uri.path.replaceAll(
            RegExp(r'/+$'),
            '',
          );

    return OpenNutritionGatewayConfig(
      baseUri: uri.replace(path: normalizedPath),
      publicKeyBytes: publicKey,
      keyId: keyId,
    );
  }
}

bool _looksLikeIpLiteral(String host) {
  if (host.contains(':')) return true;
  final List<String> parts = host.split('.');
  if (parts.length != 4) return false;
  for (final String part in parts) {
    final int? value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) return false;
  }
  return true;
}

bool _isAllowedPublicHostname(String host) {
  if (host.isEmpty ||
      host.length > 253 ||
      host.endsWith('.') ||
      host.contains('..') ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host.endsWith('.local') ||
      _looksLikeIpLiteral(host) ||
      !RegExp(r'^[a-z0-9.-]+$').hasMatch(host)) {
    return false;
  }

  final List<String> labels = host.split('.');
  if (labels.length < 2) return false;
  for (final String label in labels) {
    if (label.isEmpty ||
        label.length > 63 ||
        label.startsWith('-') ||
        label.endsWith('-') ||
        !RegExp(r'^[a-z0-9-]+$').hasMatch(label)) {
      return false;
    }
  }
  return true;
}

class OpenNutritionQueryPolicy {
  const OpenNutritionQueryPolicy._();

  static const int maximumCharacters = 80;
  static const int maximumUtf8Bytes = 160;
  static const int maximumWords = 12;

  static String validate(String query) {
    final String raw = query.trim();
    if (raw.runes.any(_isForbiddenControlRune)) {
      throw const OpenNutritionGatewayException(
        'La ricerca contiene caratteri di controllo o direzionali.',
      );
    }
    if (raw.contains(RegExp(r'[<>{}\[\]\\|^`~;]')) ||
        raw.contains('://') ||
        raw.toLowerCase().contains('www.') ||
        raw.contains('--') ||
        raw.contains('/*') ||
        raw.contains('*/')) {
      throw const OpenNutritionGatewayException(
        'La ricerca contiene sequenze non consentite.',
      );
    }

    final String clean = raw.replaceAll(RegExp(r'\s+'), ' ');
    if (clean.length < 2 || clean.length > maximumCharacters) {
      throw const OpenNutritionGatewayException(
        'La ricerca OpenNutrition deve contenere da 2 a 80 caratteri.',
      );
    }
    if (utf8.encode(clean).length > maximumUtf8Bytes) {
      throw const OpenNutritionGatewayException(
        'La ricerca OpenNutrition supera il limite in byte.',
      );
    }

    final List<String> words = clean
        .split(' ')
        .where((String word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length > maximumWords ||
        words.any((String word) => word.length > 40)) {
      throw const OpenNutritionGatewayException(
        'La ricerca contiene troppi termini o termini troppo lunghi.',
      );
    }
    if (!clean.runes.any((int rune) => _isLetterOrDigitLike(rune))) {
      throw const OpenNutritionGatewayException(
        'La ricerca deve contenere lettere o numeri.',
      );
    }
    return clean;
  }

  static bool _isForbiddenControlRune(int rune) {
    return rune < 0x20 ||
        rune == 0x7F ||
        rune == 0x200E ||
        rune == 0x200F ||
        (rune >= 0x202A && rune <= 0x202E) ||
        (rune >= 0x2066 && rune <= 0x2069);
  }

  static bool _isLetterOrDigitLike(int rune) {
    if (rune >= 0x30 && rune <= 0x39) return true;
    if (rune >= 0x41 && rune <= 0x5A) return true;
    if (rune >= 0x61 && rune <= 0x7A) return true;
    return rune > 0x7F;
  }
}

class OpenNutritionGatewaySearchPage {
  const OpenNutritionGatewaySearchPage({
    required this.foods,
    required this.page,
    required this.hasNext,
    required this.datasetVersion,
  });

  final List<OpenNutritionFoodEntity> foods;
  final int page;
  final bool hasNext;
  final String datasetVersion;
}

class OpenNutritionGatewayService {
  OpenNutritionGatewayService({
    http.Client? client,
    OpenNutritionGatewayConfig? fixedConfig,
    String? fixedInstallationId,
  })  : _client = client ?? http.Client(),
        _fixedConfig = fixedConfig,
        _fixedInstallationId = _validateFixedInstallationId(
          fixedInstallationId,
        );

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const int _maximumResponseBytes = 256 * 1024;
  static const int _maximumItems = 20;
  static const Duration _cacheDuration = Duration(minutes: 2);
  static const Duration _circuitOpenDuration = Duration(seconds: 45);
  static const bool _allowRemoteImages = bool.fromEnvironment(
    'OPENNUTRITION_GATEWAY_ALLOW_REMOTE_IMAGES',
    defaultValue: false,
  );

  final http.Client _client;
  final OpenNutritionGatewayConfig? _fixedConfig;
  final String? _fixedInstallationId;
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};
  final LinkedHashMap<String, DateTime> _acceptedResponseIds =
      LinkedHashMap<String, DateTime>();

  int _consecutiveFailures = 0;
  int _activeRequests = 0;
  DateTime? _circuitOpenUntil;

  Future<bool> isConfigured() async {
    if (!await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.openNutritionRemoteEnabled,
    )) {
      return false;
    }
    try {
      return _fixedConfig != null ||
          await OpenNutritionGatewayConfig.load() != null;
    } catch (_) {
      return false;
    }
  }

  Future<String> healthCheck() async {
    final OpenNutritionGatewayConfig config = await _requireConfig();
    final Map<String, dynamic> envelope = await _requestEnvelope(
      config: config,
      path: '/v1/health',
      queryParameters: const <String, String>{},
    );
    final String status = _requiredString(
      envelope,
      'status',
      maximumLength: 32,
    );
    if (status != 'ok') {
      throw const OpenNutritionGatewayException(
        'Il gateway non ha restituito uno stato valido.',
      );
    }
    return _requiredString(
      envelope,
      'datasetVersion',
      maximumLength: 80,
    );
  }

  Future<OpenNutritionGatewaySearchPage> search({
    required String query,
    int page = 0,
    int limit = _maximumItems,
  }) async {
    final String normalizedQuery = OpenNutritionQueryPolicy.validate(query);
    final int safePage = page.clamp(0, 19);
    final int safeLimit = limit.clamp(1, _maximumItems);
    final OpenNutritionGatewayConfig config = await _requireConfig();

    final String cacheKey =
        '${config.baseUri}|$normalizedQuery|$safePage|$safeLimit';
    final _CacheEntry? cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now().toUtc())) {
      return cached.page;
    }

    final Map<String, dynamic> envelope = await _requestEnvelope(
      config: config,
      path: '/v1/search',
      queryParameters: <String, String>{
        'q': normalizedQuery,
        'page': '${safePage + 1}',
        'limit': '$safeLimit',
      },
    );

    final String datasetVersion = _requiredString(
      envelope,
      'datasetVersion',
      maximumLength: 80,
    );
    final Object? rawItems = envelope['items'];
    if (rawItems is! List || rawItems.length > safeLimit) {
      throw const OpenNutritionGatewayException(
        'Numero di risultati non valido.',
      );
    }

    final Set<String> ids = <String>{};
    final List<OpenNutritionFoodEntity> foods = <OpenNutritionFoodEntity>[];
    for (final Object? rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const OpenNutritionGatewayException(
          'Elemento della risposta non valido.',
        );
      }
      final Map<String, dynamic> item = rawItem.map(
        (Object? key, Object? value) => MapEntry('$key', value),
      );
      final OpenNutritionFoodEntity food = _parseFood(
        item,
        datasetVersion: datasetVersion,
        gatewayHost: config.baseUri.host,
      );
      if (!ids.add(food.externalFoodId)) {
        throw const OpenNutritionGatewayException(
          'La risposta contiene identificativi duplicati.',
        );
      }
      foods.add(food);
    }

    final int responsePage = _requiredInt(
      envelope,
      'page',
      minimum: 1,
      maximum: 20,
    );
    final bool hasNext = _requiredBool(envelope, 'hasNext');
    final OpenNutritionGatewaySearchPage result =
        OpenNutritionGatewaySearchPage(
      foods: List<OpenNutritionFoodEntity>.unmodifiable(foods),
      page: responsePage - 1,
      hasNext: hasNext,
      datasetVersion: datasetVersion,
    );
    _cache[cacheKey] = _CacheEntry(
      page: result,
      expiresAt: DateTime.now().toUtc().add(_cacheDuration),
    );
    _trimCache();
    return result;
  }

  static String validateQuery(String query) {
    return OpenNutritionQueryPolicy.validate(query);
  }

  Future<OpenNutritionGatewayConfig> _requireConfig() async {
    if (!await FoodServicePreferences.getBool(
      FoodServicePreferenceKeys.openNutritionRemoteEnabled,
    )) {
      throw const OpenNutritionGatewayException(
        'La ricerca OpenNutrition online è disabilitata.',
      );
    }
    final OpenNutritionGatewayConfig? config =
        _fixedConfig ?? await OpenNutritionGatewayConfig.load();
    if (config == null) {
      throw const OpenNutritionGatewayException(
        'Gateway OpenNutrition non configurato.',
      );
    }
    return config;
  }

  Future<Map<String, dynamic>> _requestEnvelope({
    required OpenNutritionGatewayConfig config,
    required String path,
    required Map<String, String> queryParameters,
  }) async {
    if (path != '/v1/search' && path != '/v1/health') {
      throw const OpenNutritionGatewayException(
        'Endpoint gateway non consentito.',
      );
    }
    _validateRequestParameters(path, queryParameters);
    if (_activeRequests >= 2) {
      throw const OpenNutritionGatewayException(
        'Troppe richieste OpenNutrition simultanee.',
      );
    }
    _activeRequests += 1;

    try {
      final DateTime now = DateTime.now().toUtc();
      final DateTime? openUntil = _circuitOpenUntil;
      if (openUntil != null && openUntil.isAfter(now)) {
        throw const OpenNutritionGatewayException(
          'Gateway temporaneamente sospeso dopo errori ripetuti.',
        );
      }

      final String requestId = const Uuid().v4();
      final String installationId = await _installationId();
      final Uri uri = config.baseUri.replace(
        path: '${config.baseUri.path}$path',
        queryParameters: queryParameters,
      );
      final http.Request request = http.Request('GET', uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers.addAll(<String, String>{
          'Accept': 'application/json',
          'Cache-Control': 'no-store',
          'X-Request-Id': requestId,
          'X-Installation-Id': installationId,
          'X-Client-Timestamp': '${now.millisecondsSinceEpoch}',
        });

      final http.StreamedResponse response =
          await _client.send(request).timeout(_requestTimeout);
      if (response.isRedirect) {
        throw const OpenNutritionGatewayException(
          'Il gateway ha tentato un redirect non consentito.',
        );
      }

      final String contentType =
          response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.startsWith('application/json')) {
        throw const OpenNutritionGatewayException(
          'Content-Type gateway non valido.',
        );
      }

      final int? declaredLength = int.tryParse(
        response.headers['content-length'] ?? '',
      );
      if (declaredLength != null &&
          (declaredLength < 0 || declaredLength > _maximumResponseBytes)) {
        throw const OpenNutritionGatewayException(
          'Dimensione risposta gateway non consentita.',
        );
      }

      final Uint8List body = await _readBounded(response);
      _validateJsonNesting(body);
      if (response.statusCode == 429) {
        throw const OpenNutritionGatewayException(
          'Limite richieste raggiunto. Riprova più tardi.',
        );
      }
      if (response.statusCode != 200) {
        throw OpenNutritionGatewayException(
          'Gateway non disponibile (${response.statusCode}).',
        );
      }

      await _verifySignature(
        config: config,
        body: body,
        signatureHeader: response.headers['x-opennutrition-signature'] ?? '',
        keyIdHeader: response.headers['x-opennutrition-key-id'] ?? '',
      );

      final Object? decoded = jsonDecode(utf8.decode(body));
      if (decoded is! Map) {
        throw const OpenNutritionGatewayException(
          'Envelope JSON non valido.',
        );
      }
      final Map<String, dynamic> envelope = decoded.map(
        (Object? key, Object? value) => MapEntry('$key', value),
      );
      _validateEnvelope(
        envelope,
        requestId: requestId,
        path: path,
      );
      _rememberAcceptedResponse(requestId);

      _consecutiveFailures = 0;
      _circuitOpenUntil = null;
      return envelope;
    } on OpenNutritionGatewayException {
      _recordFailure();
      rethrow;
    } on TimeoutException {
      _recordFailure();
      throw const OpenNutritionGatewayException(
        'Timeout del gateway OpenNutrition.',
      );
    } on SocketException {
      _recordFailure();
      throw const OpenNutritionGatewayException(
        'Connessione al gateway OpenNutrition non disponibile.',
      );
    } on FormatException {
      _recordFailure();
      throw const OpenNutritionGatewayException(
        'Risposta OpenNutrition non valida.',
      );
    } catch (_) {
      _recordFailure();
      throw const OpenNutritionGatewayException(
        'Errore sicuro durante la ricerca OpenNutrition.',
      );
    } finally {
      _activeRequests -= 1;
    }
  }

  Future<Uint8List> _readBounded(http.StreamedResponse response) async {
    final BytesBuilder builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final List<int> chunk
        in response.stream.timeout(_requestTimeout)) {
      total += chunk.length;
      if (total > _maximumResponseBytes) {
        throw const OpenNutritionGatewayException(
          'Risposta gateway troppo grande.',
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<void> _verifySignature({
    required OpenNutritionGatewayConfig config,
    required Uint8List body,
    required String signatureHeader,
    required String keyIdHeader,
  }) async {
    if (keyIdHeader != config.keyId) {
      throw const OpenNutritionGatewayException(
        'Identificativo della firma non riconosciuto.',
      );
    }

    Uint8List signatureBytes;
    try {
      signatureBytes = Uint8List.fromList(base64Decode(signatureHeader));
    } catch (_) {
      throw const OpenNutritionGatewayException(
        'Firma gateway non valida.',
      );
    }
    if (signatureBytes.length != 64) {
      throw const OpenNutritionGatewayException(
        'Lunghezza firma gateway non valida.',
      );
    }

    final SimplePublicKey publicKey = SimplePublicKey(
      config.publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final bool valid = await Ed25519().verify(
      body,
      signature: Signature(
        signatureBytes,
        publicKey: publicKey,
      ),
    );
    if (!valid) {
      throw const OpenNutritionGatewayException(
        'Firma gateway non verificata.',
      );
    }
  }

  void _validateEnvelope(
    Map<String, dynamic> envelope, {
    required String requestId,
    required String path,
  }) {
    final Set<String> allowedKeys = path == '/v1/health'
        ? <String>{
            'schemaVersion',
            'requestId',
            'issuedAt',
            'expiresAt',
            'status',
            'datasetVersion',
          }
        : <String>{
            'schemaVersion',
            'requestId',
            'issuedAt',
            'expiresAt',
            'datasetVersion',
            'page',
            'hasNext',
            'items',
          };
    _rejectUnknownKeys(envelope, allowedKeys, 'envelope');
    final int schemaVersion = _requiredInt(
      envelope,
      'schemaVersion',
      minimum: 1,
      maximum: 1,
    );
    if (schemaVersion != 1) {
      throw const OpenNutritionGatewayException(
        'Versione schema gateway non supportata.',
      );
    }
    if (_requiredString(
          envelope,
          'requestId',
          maximumLength: 64,
        ) !=
        requestId) {
      throw const OpenNutritionGatewayException(
        'Request ID gateway non corrispondente.',
      );
    }

    final DateTime issuedAt = _requiredUtcDate(envelope, 'issuedAt');
    final DateTime expiresAt = _requiredUtcDate(envelope, 'expiresAt');
    final DateTime now = DateTime.now().toUtc();

    if (issuedAt.isAfter(now.add(const Duration(minutes: 2))) ||
        issuedAt.isBefore(now.subtract(const Duration(minutes: 10))) ||
        !expiresAt.isAfter(now) ||
        expiresAt.difference(issuedAt) > const Duration(minutes: 10)) {
      throw const OpenNutritionGatewayException(
        'Finestra temporale della risposta non valida.',
      );
    }
  }

  OpenNutritionFoodEntity _parseFood(
    Map<String, dynamic> item, {
    required String datasetVersion,
    required String gatewayHost,
  }) {
    _rejectUnknownKeys(
      item,
      const <String>{
        'externalId',
        'name',
        'brand',
        'barcode',
        'imageUrl',
        'imageSmallUrl',
        'kcal100g',
        'protein100g',
        'carbs100g',
        'fat100g',
        'fiber100g',
        'sugar100g',
        'salt100g',
        'sodium100g',
        'estimated',
        'fromOpenFoodFacts',
      },
      'alimento',
    );

    final String externalId = _requiredString(
      item,
      'externalId',
      maximumLength: 128,
    );
    if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(externalId)) {
      throw const OpenNutritionGatewayException(
        'Identificativo alimento non valido.',
      );
    }

    final String name = _requiredString(
      item,
      'name',
      maximumLength: 200,
    );
    final String brand = _optionalString(
      item,
      'brand',
      maximumLength: 160,
    );
    final String barcode = _optionalString(
      item,
      'barcode',
      maximumLength: 18,
    );
    if (barcode.isNotEmpty && !RegExp(r'^\d{6,18}$').hasMatch(barcode)) {
      throw const OpenNutritionGatewayException(
        'Barcode remoto non valido.',
      );
    }

    final String imageUrl = _allowRemoteImages
        ? _validatedImageUrl(
            _optionalString(item, 'imageUrl', maximumLength: 2048),
            gatewayHost: gatewayHost,
          )
        : '';
    final String imageSmallUrl = _allowRemoteImages
        ? _validatedImageUrl(
            _optionalString(item, 'imageSmallUrl', maximumLength: 2048),
            gatewayHost: gatewayHost,
          )
        : '';

    final double kcal = _boundedNumber(item, 'kcal100g', 0, 900);
    final double protein = _boundedNumber(item, 'protein100g', 0, 100);
    final double carbs = _boundedNumber(item, 'carbs100g', 0, 100);
    final double fat = _boundedNumber(item, 'fat100g', 0, 100);
    final double fiber = _boundedNumber(item, 'fiber100g', 0, 100);
    final double sugar = _boundedNumber(item, 'sugar100g', 0, 100);
    final double salt = _boundedNumber(item, 'salt100g', 0, 100);
    final double sodium = _boundedNumber(item, 'sodium100g', 0, 100);
    if (protein + carbs + fat + fiber > 140 ||
        sugar > carbs + 0.001 ||
        (salt > 0 && sodium > salt + 0.001)) {
      throw const OpenNutritionGatewayException(
        'Combinazione nutrizionale remota non plausibile.',
      );
    }

    return OpenNutritionFoodEntity(
      externalFoodId: externalId,
      importBatchId: 'remote:$datasetVersion',
      datasetVersion: datasetVersion,
      name: name,
      normalizedName: name.toLowerCase(),
      brand: brand,
      normalizedBrand: brand.toLowerCase(),
      barcode: barcode,
      imageUrl: imageUrl,
      imageSmallUrl: imageSmallUrl,
      normalizedSearchText: '$name $brand $barcode'.toLowerCase(),
      kcalPer100g: kcal,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fiberPer100g: fiber,
      sugarPer100g: sugar,
      saltPer100g: salt,
      sodiumPer100g: sodium,
      hasNutritionData: true,
      hasCompleteMacros: protein >= 0 && carbs >= 0 && fat >= 0 && kcal >= 0,
      hasEstimatedValues: _optionalBool(item, 'estimated'),
      fromOpenFoodFacts: _optionalBool(item, 'fromOpenFoodFacts'),
      sourceJson: jsonEncode(<String, Object?>{
        'gateway': true,
        'gatewayHost': gatewayHost,
      }),
      importedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  String _validatedImageUrl(
    String value, {
    required String gatewayHost,
  }) {
    if (value.isEmpty) return '';
    final Uri? uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      return '';
    }
    final String host = uri.host.toLowerCase();
    final Set<String> allowedHosts = <String>{
      gatewayHost.toLowerCase(),
      'images.openfoodfacts.org',
      'static.openfoodfacts.org',
    };
    return allowedHosts.contains(host) ? uri.toString() : '';
  }

  Future<String> _installationId() async {
    final String? fixed = _fixedInstallationId;
    if (fixed != null) return fixed;

    try {
      String value = await FoodServicePreferences.getString(
        FoodServicePreferenceKeys.gatewayInstallationId,
      );
      if (!_isValidInstallationId(value)) {
        value = const Uuid().v4();
        await FoodServicePreferences.setString(
          FoodServicePreferenceKeys.gatewayInstallationId,
          value,
        );
      }
      return value;
    } catch (_) {
      // L'identificativo non è un segreto né un fattore di autenticazione.
      // Se lo storage non è disponibile, la richiesta usa un ID effimero
      // senza indebolire firma, timestamp, anti-replay o validazione JSON.
      return const Uuid().v4();
    }
  }

  static String? _validateFixedInstallationId(String? value) {
    if (value == null) return null;
    final String clean = value.trim().toLowerCase();
    if (!_isValidInstallationId(clean)) {
      throw const OpenNutritionGatewayException(
        'Identificativo installazione di test non valido.',
      );
    }
    return clean;
  }

  static bool _isValidInstallationId(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
      r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(value);
  }

  void _recordFailure() {
    _consecutiveFailures += 1;
    if (_consecutiveFailures >= 3) {
      final int jitterSeconds = Random.secure().nextInt(15);
      _circuitOpenUntil = DateTime.now().toUtc().add(
            _circuitOpenDuration + Duration(seconds: jitterSeconds),
          );
    }
  }

  void _trimCache() {
    final DateTime now = DateTime.now().toUtc();
    _cache.removeWhere(
      (String key, _CacheEntry value) => value.expiresAt.isBefore(now),
    );
    while (_cache.length > 40) {
      _cache.remove(_cache.keys.first);
    }
  }

  void _validateRequestParameters(
    String path,
    Map<String, String> parameters,
  ) {
    if (path == '/v1/health') {
      if (parameters.isNotEmpty) {
        throw const OpenNutritionGatewayException(
          'Parametri health non consentiti.',
        );
      }
      return;
    }

    if (parameters.keys.toSet().difference(
      const <String>{'q', 'page', 'limit'},
    ).isNotEmpty) {
      throw const OpenNutritionGatewayException(
        'Parametri gateway non consentiti.',
      );
    }
    OpenNutritionQueryPolicy.validate(parameters['q'] ?? '');
    final int? page = int.tryParse(parameters['page'] ?? '');
    final int? limit = int.tryParse(parameters['limit'] ?? '');
    if (page == null ||
        page < 1 ||
        page > 20 ||
        limit == null ||
        limit < 1 ||
        limit > _maximumItems) {
      throw const OpenNutritionGatewayException(
        'Paginazione gateway non valida.',
      );
    }
  }

  void _rememberAcceptedResponse(String requestId) {
    if (_acceptedResponseIds.containsKey(requestId)) {
      throw const OpenNutritionGatewayException(
        'Risposta gateway già utilizzata.',
      );
    }
    final DateTime now = DateTime.now().toUtc();
    _acceptedResponseIds[requestId] = now;
    _acceptedResponseIds.removeWhere(
      (String key, DateTime acceptedAt) =>
          now.difference(acceptedAt) > const Duration(minutes: 15),
    );
    while (_acceptedResponseIds.length > 128) {
      _acceptedResponseIds.remove(_acceptedResponseIds.keys.first);
    }
  }

  static void _validateJsonNesting(Uint8List body) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (final int byte in body) {
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (byte == 0x5C) {
          escaped = true;
        } else if (byte == 0x22) {
          inString = false;
        }
        continue;
      }

      if (byte == 0x22) {
        inString = true;
      } else if (byte == 0x7B || byte == 0x5B) {
        depth += 1;
        if (depth > 16) {
          throw const OpenNutritionGatewayException(
            'Struttura JSON gateway troppo profonda.',
          );
        }
      } else if (byte == 0x7D || byte == 0x5D) {
        depth -= 1;
        if (depth < 0) {
          throw const OpenNutritionGatewayException(
            'Struttura JSON gateway non valida.',
          );
        }
      } else if (byte == 0x00) {
        throw const OpenNutritionGatewayException(
          'La risposta gateway contiene byte nulli.',
        );
      }
    }
    if (inString || depth != 0) {
      throw const OpenNutritionGatewayException(
        'Struttura JSON gateway incompleta.',
      );
    }
  }

  void dispose() {
    _client.close();
    _cache.clear();
    _acceptedResponseIds.clear();
  }
}

class _CacheEntry {
  const _CacheEntry({
    required this.page,
    required this.expiresAt,
  });

  final OpenNutritionGatewaySearchPage page;
  final DateTime expiresAt;
}

void _rejectUnknownKeys(
  Map<String, dynamic> map,
  Set<String> allowed,
  String context,
) {
  final Set<String> unknown = map.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) {
    throw OpenNutritionGatewayException(
      'Campi $context non riconosciuti.',
    );
  }
}

void _validateSafeText(String value, String key) {
  if (value.runes.any(OpenNutritionQueryPolicy._isForbiddenControlRune) ||
      value.contains('<') ||
      value.contains('>')) {
    throw OpenNutritionGatewayException('Campo $key non sicuro.');
  }
  if (utf8.encode(value).length > 4096) {
    throw OpenNutritionGatewayException('Campo $key troppo grande.');
  }
}

String _requiredString(
  Map<String, dynamic> map,
  String key, {
  required int maximumLength,
}) {
  final Object? value = map[key];
  if (value is! String) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  final String clean = value.trim();
  if (clean.isEmpty || clean.length > maximumLength) {
    throw OpenNutritionGatewayException('Campo $key fuori limite.');
  }
  _validateSafeText(clean, key);
  return clean;
}

String _optionalString(
  Map<String, dynamic> map,
  String key, {
  required int maximumLength,
}) {
  final Object? value = map[key];
  if (value == null) return '';
  if (value is! String) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  final String clean = value.trim();
  if (clean.length > maximumLength) {
    throw OpenNutritionGatewayException('Campo $key fuori limite.');
  }
  _validateSafeText(clean, key);
  return clean;
}

int _requiredInt(
  Map<String, dynamic> map,
  String key, {
  required int minimum,
  required int maximum,
}) {
  final Object? value = map[key];
  if (value is! num) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  final int integer = value.toInt();
  if (integer != value || integer < minimum || integer > maximum) {
    throw OpenNutritionGatewayException('Campo $key fuori limite.');
  }
  return integer;
}

bool _requiredBool(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! bool) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  return value;
}

bool _optionalBool(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value == null) return false;
  if (value is! bool) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  return value;
}

double _boundedNumber(
  Map<String, dynamic> map,
  String key,
  double minimum,
  double maximum,
) {
  final Object? value = map[key];
  if (value == null) return 0;
  if (value is! num) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  final double number = value.toDouble();
  if (!number.isFinite || number < minimum || number > maximum) {
    throw OpenNutritionGatewayException('Campo $key fuori limite.');
  }
  return number;
}

DateTime _requiredUtcDate(Map<String, dynamic> map, String key) {
  final String value = _requiredString(map, key, maximumLength: 40);
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw OpenNutritionGatewayException('Campo $key non valido.');
  }
  return parsed;
}
