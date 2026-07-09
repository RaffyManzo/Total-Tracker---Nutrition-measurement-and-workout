import 'dart:collection';

/// Central privacy boundary for diagnostic payloads.
///
/// Diagnostics remain useful for causality and timing, but values likely to
/// identify a person, reveal body measurements, nutrition, workout details,
/// free text, or full filesystem paths are removed before JSON serialization.
/// String values are denied by default and preserved only for a narrow set of
/// technical keys whose values are controlled identifiers or enum-like codes.
class DiagnosticPrivacy {
  DiagnosticPrivacy._();

  static const Set<String> _sensitiveTokens = <String>{
    'name',
    'note',
    'notes',
    'body',
    'weight',
    'load',
    'rep',
    'reps',
    'repetition',
    'repetitions',
    'query',
    'search',
    'searchtext',
    'value',
    'message',
    'description',
    'label',
    'title',
    'text',
    'information',
    'context',
    'library',
    'calorie',
    'calories',
    'kcal',
    'protein',
    'carb',
    'carbs',
    'carbohydrate',
    'carbohydrates',
    'fat',
    'fiber',
    'sugar',
    'measurement',
    'measurements',
    'waist',
    'muscle',
    'bone',
    'visceral',
    'water',
    'bmi',
    'metabolic',
    'heart',
    'sleep',
    'step',
    'steps',
    'age',
    'height',
    'gender',
    'sex',
  };
  static const Set<String> _pathTokens = <String>{
    'path',
    'directory',
    'folder',
  };
  static const Set<String> _safeTextKeys = <String>{
    'appversion',
    'buildmode',
    'buildnumber',
    'causeeventid',
    'code',
    'datefrom',
    'datekey',
    'dateto',
    'eventid',
    'kind',
    'mode',
    'operationid',
    'platform',
    'reason',
    'reasoncode',
    'reasoncodes',
    'scope',
    'sessionid',
    'sourceuuidhash',
    'state',
    'status',
    'triggerreasons',
    'type',
    'eventtype',
  };
  static final RegExp _camelBoundary = RegExp(r'([a-z0-9])([A-Z])');
  static final RegExp _tokenSeparator = RegExp(r'[^a-z0-9]+');
  static final RegExp _windowsPath = RegExp(
    r'''[A-Za-z]:\\[^\s"']+''',
  );
  static final RegExp _unixPath = RegExp(
    r'''/(?:[^/\s]+/)+[^/\s"']*''',
  );

  static Map<String, Object?> sanitizeData(Map<Object?, Object?> data) {
    final LinkedHashMap<String, Object?> output = LinkedHashMap();
    for (final MapEntry<Object?, Object?> entry in data.entries.take(100)) {
      final String key = entry.key.toString();
      if (_containsToken(key, _sensitiveTokens)) {
        output[key] = '<redacted>';
      } else if (_containsToken(key, _pathTokens)) {
        output[key] = '<redacted-path>';
      } else {
        output[key] = _sanitizeForKey(key, entry.value);
      }
    }
    return output;
  }

  static Object? sanitizeValue(Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is String) {
      return '<redacted-text>';
    }
    if (value is Iterable) {
      return value.take(100).map(sanitizeValue).toList(growable: false);
    }
    if (value is Map) {
      return sanitizeData(value);
    }
    return '<redacted-type:${value.runtimeType}>';
  }

  /// Returns only the exception type. Exception messages can contain user-entered
  /// names, search terms, measurements, notes or local paths and are therefore
  /// not suitable for diagnostic logs.
  static String sanitizeError(Object error) {
    return '<redacted-error:${error.runtimeType}>';
  }

  static String sanitizeText(String value) {
    return value
        .replaceAll(_windowsPath, '<redacted-path>')
        .replaceAll(_unixPath, '<redacted-path>');
  }

  static Object? _sanitizeForKey(String key, Object? value) {
    if (value == null || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    final bool allowText = _safeTextKeys.contains(_canonicalKey(key));
    if (value is String) {
      return allowText ? sanitizeText(value) : '<redacted-text>';
    }
    if (value is Iterable) {
      return value
          .take(100)
          .map(
            (Object? item) => item is String
                ? (allowText ? sanitizeText(item) : '<redacted-text>')
                : sanitizeValue(item),
          )
          .toList(growable: false);
    }
    if (value is Map) {
      return sanitizeData(value);
    }
    return '<redacted-type:${value.runtimeType}>';
  }

  static String _canonicalKey(String key) {
    return key.toLowerCase().replaceAll(_tokenSeparator, '');
  }

  static bool _containsToken(String key, Set<String> candidates) {
    final String expanded = key.replaceAllMapped(
      _camelBoundary,
      (Match match) => '${match.group(1)}_${match.group(2)}',
    );
    final Iterable<String> tokens = expanded
        .toLowerCase()
        .split(_tokenSeparator)
        .where((String token) => token.isNotEmpty);
    return tokens.any(candidates.contains);
  }
}
