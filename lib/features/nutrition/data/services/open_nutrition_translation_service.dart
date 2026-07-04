import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../entities/open_nutrition_food_entity.dart';

class OpenNutritionTranslationException implements Exception {
  const OpenNutritionTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenNutritionTranslationStatus {
  const OpenNutritionTranslationStatus({
    required this.platformSupported,
    required this.localeSupported,
    required this.localeCode,
    required this.translationRequired,
    required this.englishModelDownloaded,
    required this.localeModelDownloaded,
  });

  final bool platformSupported;
  final bool localeSupported;
  final String localeCode;
  final bool translationRequired;
  final bool englishModelDownloaded;
  final bool localeModelDownloaded;

  bool get ready =>
      platformSupported &&
      localeSupported &&
      (!translationRequired ||
          (englishModelDownloaded && localeModelDownloaded));
}

class OpenNutritionTranslationService {
  OpenNutritionTranslationService({
    OnDeviceTranslatorModelManager? modelManager,
  }) : _modelManager = modelManager ?? OnDeviceTranslatorModelManager();

  static const int _maximumTextLength = 512;
  static const int _maximumCacheEntries = 512;

  final OnDeviceTranslatorModelManager _modelManager;
  final Map<String, Future<void>> _pendingModelDownloads =
      <String, Future<void>>{};
  final LinkedHashMap<String, String> _translationCache =
      LinkedHashMap<String, String>();

  bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String get localeCode {
    final String code =
        PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return code == 'iw' ? 'he' : code;
  }

  TranslateLanguage? get localeLanguage => _languageForCode(localeCode);

  bool get translationRequired {
    final TranslateLanguage? language = localeLanguage;
    return language != null && language != TranslateLanguage.english;
  }

  Future<OpenNutritionTranslationStatus> readStatus() async {
    final String currentLocaleCode = localeCode;
    final TranslateLanguage? language = localeLanguage;

    if (!platformSupported) {
      return OpenNutritionTranslationStatus(
        platformSupported: false,
        localeSupported: language != null,
        localeCode: currentLocaleCode,
        translationRequired:
            language != null && language != TranslateLanguage.english,
        englishModelDownloaded: false,
        localeModelDownloaded: false,
      );
    }

    if (language == null) {
      return OpenNutritionTranslationStatus(
        platformSupported: true,
        localeSupported: false,
        localeCode: currentLocaleCode,
        translationRequired: false,
        englishModelDownloaded: false,
        localeModelDownloaded: false,
      );
    }

    if (language == TranslateLanguage.english) {
      return OpenNutritionTranslationStatus(
        platformSupported: true,
        localeSupported: true,
        localeCode: currentLocaleCode,
        translationRequired: false,
        englishModelDownloaded: true,
        localeModelDownloaded: true,
      );
    }

    try {
      final bool englishDownloaded = await _modelManager.isModelDownloaded(
        TranslateLanguage.english.bcpCode,
      );
      final bool localeDownloaded =
          await _modelManager.isModelDownloaded(language.bcpCode);

      return OpenNutritionTranslationStatus(
        platformSupported: true,
        localeSupported: true,
        localeCode: currentLocaleCode,
        translationRequired: true,
        englishModelDownloaded: englishDownloaded,
        localeModelDownloaded: localeDownloaded,
      );
    } catch (error) {
      throw OpenNutritionTranslationException(
        'Impossibile verificare i modelli di traduzione: $error',
      );
    }
  }

  Future<String> translateQueryToEnglish(String query) async {
    final String input = _validatedText(query);
    final TranslateLanguage language = _requireLocaleLanguage();

    if (language == TranslateLanguage.english) return input;

    await _ensureLanguagePair(
      source: language,
      target: TranslateLanguage.english,
    );

    return _translate(
      text: input,
      source: language,
      target: TranslateLanguage.english,
    );
  }

  Future<List<OpenNutritionFoodEntity>> translateFoodsFromEnglish(
    List<OpenNutritionFoodEntity> foods,
  ) async {
    if (foods.isEmpty) return foods;

    final TranslateLanguage target = _requireLocaleLanguage();
    if (target == TranslateLanguage.english) return foods;

    await _ensureLanguagePair(
      source: TranslateLanguage.english,
      target: target,
    );

    final OnDeviceTranslator translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: target,
    );

    try {
      for (final OpenNutritionFoodEntity food in foods) {
        await _translateFood(
          food: food,
          translator: translator,
          target: target,
        );
      }
      return foods;
    } finally {
      await translator.close();
    }
  }

  TranslateLanguage _requireLocaleLanguage() {
    if (!platformSupported) {
      throw const OpenNutritionTranslationException(
        'La traduzione OpenNutrition è disponibile solo su Android e iOS.',
      );
    }

    final TranslateLanguage? language = localeLanguage;
    if (language == null) {
      throw OpenNutritionTranslationException(
        'La lingua del dispositivo "$localeCode" non è supportata '
        'dalla traduzione on-device.',
      );
    }
    return language;
  }

  Future<void> _translateFood({
    required OpenNutritionFoodEntity food,
    required OnDeviceTranslator translator,
    required TranslateLanguage target,
  }) async {
    final String originalName = _validatedText(food.name);
    final String translatedName = await _translateWithTranslator(
      text: originalName,
      translator: translator,
      cacheKey:
          '${TranslateLanguage.english.bcpCode}>${target.bcpCode}:$originalName',
    );

    String translatedDescription = food.description.trim();
    if (translatedDescription.isNotEmpty) {
      translatedDescription = await _translateWithTranslator(
        text: _validatedText(translatedDescription),
        translator: translator,
        cacheKey: '${TranslateLanguage.english.bcpCode}>${target.bcpCode}:'
            '$translatedDescription',
      );
    }

    final List<String> aliases = _readStringList(
      food.alternateNamesJson,
    );
    final Map<String, Object?> additional = _readObject(
      food.additionalFieldsJson,
    );

    additional
      ..['machineTranslated'] = true
      ..['translationProvider'] = 'Google Translate'
      ..['translationSourceLanguage'] = TranslateLanguage.english.bcpCode
      ..['translationTargetLanguage'] = target.bcpCode
      ..['originalName'] = originalName;

    food
      ..name = translatedName
      ..normalizedName = _normalize(translatedName)
      ..description = translatedDescription
      ..alternateNamesJson = jsonEncode(
        <String>{
          ...aliases,
          originalName,
        }.toList(growable: false),
      )
      ..additionalFieldsJson = jsonEncode(additional)
      ..normalizedSearchText = _normalize(
        <String>[
          translatedName,
          originalName,
          ...aliases,
        ].join(' '),
      );
  }

  Future<void> _ensureLanguagePair({
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    await Future.wait<void>(
      <Future<void>>[
        _ensureModel(source),
        _ensureModel(target),
      ],
    );
  }

  Future<void> _ensureModel(TranslateLanguage language) async {
    final String code = language.bcpCode;
    final Future<void>? pending = _pendingModelDownloads[code];
    if (pending != null) {
      await pending;
      return;
    }

    final Future<void> operation = _downloadModelIfNeeded(language);
    _pendingModelDownloads[code] = operation;
    try {
      await operation;
    } finally {
      if (identical(_pendingModelDownloads[code], operation)) {
        _pendingModelDownloads.remove(code);
      }
    }
  }

  Future<void> _downloadModelIfNeeded(
    TranslateLanguage language,
  ) async {
    try {
      final bool alreadyDownloaded =
          await _modelManager.isModelDownloaded(language.bcpCode);
      if (alreadyDownloaded) return;

      final bool downloaded = await _modelManager.downloadModel(
        language.bcpCode,
        isWifiRequired: true,
      );

      if (!downloaded) {
        throw OpenNutritionTranslationException(
          'Il modello ${language.bcpCode} non è stato scaricato. '
          'Connettiti a una rete Wi-Fi e riprova.',
        );
      }
    } on OpenNutritionTranslationException {
      rethrow;
    } catch (error) {
      throw OpenNutritionTranslationException(
        'Download del modello ${language.bcpCode} non riuscito. '
        'Connettiti a una rete Wi-Fi e riprova: $error',
      );
    }
  }

  Future<String> _translate({
    required String text,
    required TranslateLanguage source,
    required TranslateLanguage target,
  }) async {
    final String cacheKey = '${source.bcpCode}>${target.bcpCode}:$text';
    final String? cached = _translationCache[cacheKey];
    if (cached != null) {
      _touchCache(cacheKey, cached);
      return cached;
    }

    final OnDeviceTranslator translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    try {
      return await _translateWithTranslator(
        text: text,
        translator: translator,
        cacheKey: cacheKey,
      );
    } finally {
      await translator.close();
    }
  }

  Future<String> _translateWithTranslator({
    required String text,
    required OnDeviceTranslator translator,
    required String cacheKey,
  }) async {
    final String? cached = _translationCache[cacheKey];
    if (cached != null) {
      _touchCache(cacheKey, cached);
      return cached;
    }

    try {
      final String translated =
          (await translator.translateText(text)).toString().trim();
      final String result = translated.isEmpty ? text : translated;
      _touchCache(cacheKey, result);
      return result;
    } catch (error) {
      throw OpenNutritionTranslationException(
        'Traduzione on-device non riuscita: $error',
      );
    }
  }

  void _touchCache(String key, String value) {
    _translationCache
      ..remove(key)
      ..[key] = value;

    while (_translationCache.length > _maximumCacheEntries) {
      _translationCache.remove(_translationCache.keys.first);
    }
  }

  TranslateLanguage? _languageForCode(String code) {
    for (final TranslateLanguage language in TranslateLanguage.values) {
      if (language.bcpCode == code) return language;
    }
    return null;
  }

  String _validatedText(String input) {
    final String value = input.trim();
    if (value.isEmpty) {
      throw const OpenNutritionTranslationException(
        'Testo da tradurre vuoto.',
      );
    }
    if (value.length > _maximumTextLength) {
      throw const OpenNutritionTranslationException(
        'Testo da tradurre oltre il limite consentito.',
      );
    }
    return value;
  }

  List<String> _readStringList(String rawJson) {
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! List) return const <String>[];

      return decoded
          .map((Object? value) => value?.toString().trim() ?? '')
          .where((String value) => value.isNotEmpty)
          .take(24)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Map<String, Object?> _readObject(String rawJson) {
    try {
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map) return <String, Object?>{};

      return decoded.map<String, Object?>(
        (dynamic key, dynamic value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    } catch (_) {
      return <String, Object?>{};
    }
  }

  String _normalize(String input) {
    String value = input.toLowerCase().trim();
    const Map<String, String> replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    replacements.forEach((String from, String to) {
      value = value.replaceAll(from, to);
    });

    return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }
}
