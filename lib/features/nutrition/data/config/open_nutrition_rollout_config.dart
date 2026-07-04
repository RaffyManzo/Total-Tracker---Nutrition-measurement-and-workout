class OpenNutritionRolloutConfig {
  const OpenNutritionRolloutConfig._();

  /// Legacy full-dataset import and local catalog search.
  ///
  /// Disabled by default while the static sharded index is implemented.
  /// It can be re-enabled temporarily for diagnostics with:
  /// --dart-define=OPENNUTRITION_ENABLE_LEGACY_LOCAL_CATALOG=true
  static const bool legacyLocalCatalogEnabled = bool.fromEnvironment(
    'OPENNUTRITION_ENABLE_LEGACY_LOCAL_CATALOG',
    defaultValue: false,
  );

  /// Legacy signed MCP/gateway search.
  ///
  /// The production direction does not publish this service. The switch is
  /// retained only as a reversible development escape hatch.
  static const bool legacyGatewayEnabled = bool.fromEnvironment(
    'OPENNUTRITION_ENABLE_LEGACY_GATEWAY',
    defaultValue: false,
  );

  /// Static CDN index rollout switch.
  ///
  /// It is intentionally disabled by default. Production builds must provide
  /// the immutable CDN base URL and the SHA-256 of manifest.json.
  static const bool staticIndexEnabled = bool.fromEnvironment(
    'OPENNUTRITION_ENABLE_STATIC_INDEX',
    defaultValue: false,
  );

  static const String staticIndexBaseUrl = String.fromEnvironment(
    'OPENNUTRITION_STATIC_INDEX_BASE_URL',
    defaultValue: '',
  );

  static const String staticIndexManifestSha256 = String.fromEnvironment(
    'OPENNUTRITION_STATIC_INDEX_MANIFEST_SHA256',
    defaultValue: '',
  );

  static bool get staticIndexConfigured {
    if (!staticIndexEnabled ||
        staticIndexBaseUrl.trim().isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(
          staticIndexManifestSha256.trim(),
        )) {
      return false;
    }

    final Uri? uri = Uri.tryParse(staticIndexBaseUrl.trim());
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
  }

  static Uri get staticIndexBaseUri {
    if (!staticIndexConfigured) {
      throw StateError(
        'Indice statico OpenNutrition non configurato nella build.',
      );
    }

    final String value = staticIndexBaseUrl.trim();
    return Uri.parse(value.endsWith('/') ? value : '$value/');
  }
}
