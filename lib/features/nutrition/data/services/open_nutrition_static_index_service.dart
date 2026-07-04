import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config/open_nutrition_rollout_config.dart';
import '../entities/open_nutrition_food_entity.dart';

class OpenNutritionStaticIndexException implements Exception {
  const OpenNutritionStaticIndexException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenNutritionStaticIndexStatus {
  const OpenNutritionStaticIndexStatus({
    required this.configured,
    required this.datasetVersion,
    required this.recordCount,
    required this.shardCount,
    required this.cachedShardCount,
    required this.manifestSha256,
  });

  const OpenNutritionStaticIndexStatus.notConfigured()
      : configured = false,
        datasetVersion = '',
        recordCount = 0,
        shardCount = 0,
        cachedShardCount = 0,
        manifestSha256 = '';

  final bool configured;
  final String datasetVersion;
  final int recordCount;
  final int shardCount;
  final int cachedShardCount;
  final String manifestSha256;
}

class OpenNutritionStaticSearchPage {
  const OpenNutritionStaticSearchPage({
    required this.foods,
    required this.page,
    required this.hasNext,
    required this.canonicalQuery,
  });

  final List<OpenNutritionFoodEntity> foods;
  final int page;
  final bool hasNext;
  final String canonicalQuery;
}

class OpenNutritionStaticIndexService {
  OpenNutritionStaticIndexService({
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const int _schemaVersion = 3;
  static const int _routeLength = 3;
  static const int _maximumManifestBytes = 8 * 1024 * 1024;
  static const int _maximumCompressedShardBytes = 25 * 1024 * 1024;
  static const int _maximumDecodedShardBytes = 96 * 1024 * 1024;
  static const int _maximumCacheBytes = 64 * 1024 * 1024;
  static const int _maximumResultsPerRequest = 50;
  static const Duration _requestTimeout = Duration(seconds: 25);

  final http.Client _client;
  final bool _ownsClient;

  _StaticManifest? _memoryManifest;
  Directory? _memoryCacheRoot;

  bool get isConfigured => OpenNutritionRolloutConfig.staticIndexConfigured;

  Future<OpenNutritionStaticIndexStatus> readStatus({
    bool refreshManifest = false,
  }) async {
    if (!isConfigured) {
      return const OpenNutritionStaticIndexStatus.notConfigured();
    }

    final _StaticManifest manifest = await _loadManifest(
      forceNetwork: refreshManifest,
    );
    final Directory cacheRoot = await _cacheRoot();
    final Directory shardDirectory = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}shards',
    );
    int cachedShardCount = 0;
    if (await shardDirectory.exists()) {
      await for (final FileSystemEntity entity
          in shardDirectory.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.json.gz')) {
          cachedShardCount++;
        }
      }
    }

    return OpenNutritionStaticIndexStatus(
      configured: true,
      datasetVersion: manifest.datasetVersion,
      recordCount: manifest.recordCount,
      shardCount: manifest.shards.length,
      cachedShardCount: cachedShardCount,
      manifestSha256: manifest.sha256,
    );
  }

  Future<OpenNutritionStaticSearchPage> search({
    required String query,
    int page = 0,
    int limit = 20,
  }) async {
    if (!isConfigured) {
      throw const OpenNutritionStaticIndexException(
        'Indice statico OpenNutrition non configurato nella build.',
      );
    }

    final String canonicalQuery = _normalize(query);
    if (canonicalQuery.replaceAll(' ', '').length < _routeLength) {
      return OpenNutritionStaticSearchPage(
        foods: const <OpenNutritionFoodEntity>[],
        page: page < 0 ? 0 : page,
        hasNext: false,
        canonicalQuery: canonicalQuery,
      );
    }

    final int safePage = page < 0 ? 0 : page;
    final int safeLimit = limit.clamp(1, _maximumResultsPerRequest);
    final _StaticManifest manifest = await _loadManifest();
    final String route = _routeKey(canonicalQuery);
    final _StaticShardDescriptor? descriptor = manifest.shards[route];

    if (descriptor == null) {
      return OpenNutritionStaticSearchPage(
        foods: const <OpenNutritionFoodEntity>[],
        page: safePage,
        hasNext: false,
        canonicalQuery: canonicalQuery,
      );
    }

    final List<Map<String, Object?>> records = await _loadShard(
      manifest,
      descriptor,
    );
    final List<_RankedRecord> ranked = <_RankedRecord>[];

    for (final Map<String, Object?> record in records) {
      final _RankedRecord? result = _rankRecord(
        canonicalQuery,
        record,
      );
      if (result != null) ranked.add(result);
    }

    ranked.sort((_RankedRecord a, _RankedRecord b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      final int byQuality = b.quality.compareTo(a.quality);
      if (byQuality != 0) return byQuality;

      final int byLength = a.name.length.compareTo(b.name.length);
      if (byLength != 0) return byLength;

      return a.name.compareTo(b.name);
    });

    final int offset = safePage * safeLimit;
    if (offset >= ranked.length) {
      return OpenNutritionStaticSearchPage(
        foods: const <OpenNutritionFoodEntity>[],
        page: safePage,
        hasNext: false,
        canonicalQuery: canonicalQuery,
      );
    }

    final List<_RankedRecord> visible =
        ranked.skip(offset).take(safeLimit).toList(growable: false);

    return OpenNutritionStaticSearchPage(
      foods: visible
          .map(
            (_RankedRecord value) => _toEntity(
              manifest: manifest,
              ranked: value,
            ),
          )
          .toList(growable: false),
      page: safePage,
      hasNext: offset + visible.length < ranked.length,
      canonicalQuery: canonicalQuery,
    );
  }

  Future<void> clearCache() async {
    final Directory root = await _baseCacheDirectory();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
    _memoryCacheRoot = null;
    _memoryManifest = null;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<_StaticManifest> _loadManifest({
    bool forceNetwork = false,
  }) async {
    final _StaticManifest? cachedMemory = _memoryManifest;
    if (!forceNetwork && cachedMemory != null) return cachedMemory;

    final Directory cacheRoot = await _cacheRoot();
    final File manifestFile = File(
      '${cacheRoot.path}${Platform.pathSeparator}manifest.json',
    );

    if (!forceNetwork && await manifestFile.exists()) {
      try {
        final Uint8List bytes = await manifestFile.readAsBytes();
        final _StaticManifest manifest = _parseManifest(bytes);
        _memoryManifest = manifest;
        return manifest;
      } catch (_) {
        await manifestFile.delete().catchError((_) => manifestFile);
      }
    }

    final Uri manifestUri =
        OpenNutritionRolloutConfig.staticIndexBaseUri.resolve('manifest.json');
    final Uint8List bytes = await _download(
      manifestUri,
      maximumBytes: _maximumManifestBytes,
    );
    final _StaticManifest manifest = _parseManifest(bytes);
    await _writeAtomically(manifestFile, bytes);
    _memoryManifest = manifest;
    await _trimCache(cacheRoot);
    return manifest;
  }

  _StaticManifest _parseManifest(Uint8List bytes) {
    final String actualHash = sha256.convert(bytes).toString();
    final String expectedHash =
        OpenNutritionRolloutConfig.staticIndexManifestSha256.toLowerCase();

    if (actualHash != expectedHash) {
      throw OpenNutritionStaticIndexException(
        'Hash manifest OpenNutrition non valido: $actualHash.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const OpenNutritionStaticIndexException(
        'Manifest OpenNutrition non decodificabile.',
      );
    }

    if (decoded is! Map) {
      throw const OpenNutritionStaticIndexException(
        'Schema manifest OpenNutrition non valido.',
      );
    }

    final Map<String, Object?> json =
        decoded.map<String, Object?>((dynamic key, dynamic value) {
      return MapEntry<String, Object?>(key.toString(), value);
    });

    final int schemaVersion = _readInt(json['schemaVersion']);
    final String datasetVersion = json['datasetVersion']?.toString() ?? '';
    final int recordCount = _readInt(json['recordCount']);
    final int shardCount = _readInt(json['shardCount']);
    final Object? rawShards = json['shards'];

    if (schemaVersion != _schemaVersion ||
        datasetVersion.isEmpty ||
        recordCount <= 0 ||
        shardCount <= 0 ||
        rawShards is! List ||
        rawShards.length != shardCount) {
      throw const OpenNutritionStaticIndexException(
        'Manifest OpenNutrition incompatibile.',
      );
    }

    final Map<String, _StaticShardDescriptor> shards =
        <String, _StaticShardDescriptor>{};

    for (final Object? raw in rawShards) {
      if (raw is! Map) {
        throw const OpenNutritionStaticIndexException(
          'Descrittore shard OpenNutrition non valido.',
        );
      }

      final Map<String, Object?> shard =
          raw.map<String, Object?>((dynamic key, dynamic value) {
        return MapEntry<String, Object?>(key.toString(), value);
      });

      final String route = shard['route']?.toString() ?? '';
      final String path = shard['path']?.toString() ?? '';
      final String hash = (shard['sha256']?.toString() ?? '').toLowerCase();
      final int compressedBytes = _readInt(shard['compressedBytes']);
      final int uncompressedBytes = _readInt(shard['uncompressedBytes']);

      if (!_routePattern.hasMatch(route) ||
          !_isSafeRelativeShardPath(path, route) ||
          !_sha256Pattern.hasMatch(hash) ||
          compressedBytes <= 0 ||
          compressedBytes > _maximumCompressedShardBytes ||
          uncompressedBytes <= 0 ||
          uncompressedBytes > _maximumDecodedShardBytes ||
          shards.containsKey(route)) {
        throw const OpenNutritionStaticIndexException(
          'Descrittore shard OpenNutrition non sicuro.',
        );
      }

      shards[route] = _StaticShardDescriptor(
        route: route,
        path: path,
        sha256: hash,
        compressedBytes: compressedBytes,
        uncompressedBytes: uncompressedBytes,
      );
    }

    return _StaticManifest(
      schemaVersion: schemaVersion,
      datasetVersion: datasetVersion,
      recordCount: recordCount,
      sha256: actualHash,
      shards: Map<String, _StaticShardDescriptor>.unmodifiable(shards),
    );
  }

  Future<List<Map<String, Object?>>> _loadShard(
    _StaticManifest manifest,
    _StaticShardDescriptor descriptor,
  ) async {
    final Directory root = await _cacheRoot();
    final Directory shardDirectory = Directory(
      '${root.path}${Platform.pathSeparator}shards',
    );
    await shardDirectory.create(recursive: true);

    final File shardFile = File(
      '${shardDirectory.path}${Platform.pathSeparator}'
      '${descriptor.route}.json.gz',
    );

    Uint8List bytes;
    if (await shardFile.exists()) {
      bytes = await shardFile.readAsBytes();
      if (!_validShardBytes(bytes, descriptor)) {
        await shardFile.delete();
        bytes = await _downloadShard(descriptor);
        await _writeAtomically(shardFile, bytes);
      }
    } else {
      bytes = await _downloadShard(descriptor);
      await _writeAtomically(shardFile, bytes);
    }

    try {
      final List<int> decodedBytes = gzip.decode(bytes);
      if (decodedBytes.length > _maximumDecodedShardBytes ||
          decodedBytes.length != descriptor.uncompressedBytes) {
        throw const FormatException(
            'Dimensione shard decodificato non valida.');
      }

      final Object? decoded = jsonDecode(utf8.decode(decodedBytes));
      if (decoded is! Map ||
          _readInt(decoded['schemaVersion']) != manifest.schemaVersion ||
          decoded['datasetVersion']?.toString() != manifest.datasetVersion ||
          decoded['route']?.toString() != descriptor.route ||
          decoded['records'] is! List) {
        throw const FormatException('Schema shard non valido.');
      }

      final List<Map<String, Object?>> result = <Map<String, Object?>>[];
      for (final Object? raw in decoded['records'] as List) {
        if (raw is! Map) continue;
        result.add(
          raw.map<String, Object?>((dynamic key, dynamic value) {
            return MapEntry<String, Object?>(key.toString(), value);
          }),
        );
      }

      await shardFile.setLastModified(DateTime.now());
      await _trimCache(root);
      return result;
    } catch (_) {
      await shardFile.delete().catchError((_) => shardFile);
      throw const OpenNutritionStaticIndexException(
        'Shard OpenNutrition non valido o danneggiato.',
      );
    }
  }

  Future<Uint8List> _downloadShard(
    _StaticShardDescriptor descriptor,
  ) async {
    final Uri uri =
        OpenNutritionRolloutConfig.staticIndexBaseUri.resolve(descriptor.path);
    final Uint8List bytes = await _download(
      uri,
      maximumBytes: _maximumCompressedShardBytes,
    );

    if (!_validShardBytes(bytes, descriptor)) {
      throw OpenNutritionStaticIndexException(
        'Hash o dimensione shard ${descriptor.route} non validi.',
      );
    }
    return bytes;
  }

  bool _validShardBytes(
    Uint8List bytes,
    _StaticShardDescriptor descriptor,
  ) {
    if (bytes.length != descriptor.compressedBytes ||
        bytes.length > _maximumCompressedShardBytes) {
      return false;
    }
    return sha256.convert(bytes).toString() == descriptor.sha256;
  }

  Future<Uint8List> _download(
    Uri uri, {
    required int maximumBytes,
  }) async {
    _validateRemoteUri(uri);

    final http.Request request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/json, application/gzip;q=0.9'
      ..headers['Cache-Control'] = 'no-transform';

    final http.StreamedResponse response =
        await _client.send(request).timeout(_requestTimeout);
    final Uri finalUri = response.request?.url ?? uri;
    _validateRemoteUri(finalUri);

    if (!_sameOrigin(
      OpenNutritionRolloutConfig.staticIndexBaseUri,
      finalUri,
    )) {
      throw const OpenNutritionStaticIndexException(
        'Redirect OpenNutrition verso origine non consentita.',
      );
    }

    if (response.statusCode != HttpStatus.ok) {
      throw OpenNutritionStaticIndexException(
        'Download OpenNutrition non riuscito: HTTP ${response.statusCode}.',
      );
    }

    final int? declaredLength = response.contentLength;
    if (declaredLength != null &&
        (declaredLength <= 0 || declaredLength > maximumBytes)) {
      throw const OpenNutritionStaticIndexException(
        'Dimensione risposta OpenNutrition non consentita.',
      );
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    int received = 0;

    await for (final List<int> chunk
        in response.stream.timeout(_requestTimeout)) {
      received += chunk.length;
      if (received > maximumBytes) {
        throw const OpenNutritionStaticIndexException(
          'Risposta OpenNutrition oltre il limite consentito.',
        );
      }
      builder.add(chunk);
    }

    if (received <= 0) {
      throw const OpenNutritionStaticIndexException(
        'Risposta OpenNutrition vuota.',
      );
    }

    return builder.takeBytes();
  }

  Future<Directory> _baseCacheDirectory() async {
    final Directory support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}'
      'open_nutrition_static_index',
    );
  }

  Future<Directory> _cacheRoot() async {
    final Directory? cached = _memoryCacheRoot;
    if (cached != null) return cached;

    final Directory base = await _baseCacheDirectory();
    final String manifestHash =
        OpenNutritionRolloutConfig.staticIndexManifestSha256.toLowerCase();
    final Directory root = Directory(
      '${base.path}${Platform.pathSeparator}$manifestHash',
    );
    await root.create(recursive: true);
    _memoryCacheRoot = root;
    return root;
  }

  Future<void> _trimCache(Directory currentRoot) async {
    final Directory base = await _baseCacheDirectory();
    if (!await base.exists()) return;

    final List<File> files = <File>[];
    int totalBytes = 0;

    await for (final FileSystemEntity entity
        in base.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final FileStat stat = await entity.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      files.add(entity);
      totalBytes += stat.size;
    }

    files.sort((File a, File b) {
      return a.lastModifiedSync().compareTo(b.lastModifiedSync());
    });

    for (final File file in files) {
      if (totalBytes <= _maximumCacheBytes) break;
      if (file.path ==
          '${currentRoot.path}${Platform.pathSeparator}manifest.json') {
        continue;
      }
      final int length = await file.length();
      await file.delete().catchError((_) => file);
      totalBytes -= length;
    }
  }

  Future<void> _writeAtomically(File target, Uint8List bytes) async {
    await target.parent.create(recursive: true);
    final File temporary = File('${target.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
    await temporary.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }

  OpenNutritionFoodEntity _toEntity({
    required _StaticManifest manifest,
    required _RankedRecord ranked,
  }) {
    final Map<String, Object?> values = ranked.values;
    final List<String> aliases = ranked.aliases;
    final List<String> qualityFlags = ranked.qualityFlags;
    final bool hasKcal = values['k'] is num;
    final bool hasProtein = values['p'] is num;
    final bool hasCarbs = values['c'] is num;
    final bool hasFat = values['f'] is num;

    return OpenNutritionFoodEntity(
      externalFoodId: ranked.externalId,
      importBatchId: 'static:${manifest.sha256.substring(0, 16)}',
      datasetVersion: manifest.datasetVersion,
      name: ranked.name,
      normalizedName: _normalize(ranked.name),
      alternateNamesJson: jsonEncode(aliases),
      description: 'Verified OpenNutrition static index result.',
      typeCode: ranked.typeCode,
      imageUrl: ranked.imageUrl,
      imageSmallUrl: ranked.imageUrl,
      nutrition100gJson: jsonEncode(values),
      additionalFieldsJson: jsonEncode(<String, Object?>{
        'matchedLabel': ranked.matchedLabel,
        'matchKind': ranked.matchKind,
        'score': ranked.score,
      }),
      normalizedSearchText: _normalize(
        <String>[ranked.name, ...aliases].join(' '),
      ),
      kcalPer100g: _readDouble(values['k']),
      proteinPer100g: _readDouble(values['p']),
      carbsPer100g: _readDouble(values['c']),
      fatPer100g: _readDouble(values['f']),
      fiberPer100g: _readDouble(values['fi']),
      sugarPer100g: _readDouble(values['su']),
      saltPer100g: _readDouble(values['sa']),
      hasNutritionData: hasKcal || hasProtein || hasCarbs || hasFat,
      hasCompleteMacros: hasKcal && hasProtein && hasCarbs && hasFat,
      hasEstimatedValues: qualityFlags.contains('estimated_or_derived'),
      fromOpenFoodFacts: false,
      importedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  _RankedRecord? _rankRecord(
    String canonicalQuery,
    Map<String, Object?> record,
  ) {
    final String externalId = record['id']?.toString() ?? '';
    final String name = record['n']?.toString().trim() ?? '';
    if (externalId.isEmpty || name.isEmpty || record['v'] is! Map) {
      return null;
    }

    final List<String> aliases = ((record['a'] as List?) ?? const <Object?>[])
        .map((Object? value) => value?.toString().trim() ?? '')
        .where((String value) => value.isNotEmpty)
        .take(24)
        .toList(growable: false);

    _LabelScore best = _scoreLabel(
      canonicalQuery,
      name,
      primary: true,
    );
    for (final String alias in aliases) {
      final _LabelScore candidate = _scoreLabel(
        canonicalQuery,
        alias,
        primary: false,
      );
      if (candidate.score > best.score) best = candidate;
    }

    if (best.score <= 0) return null;

    final Set<String> queryTokens =
        _tokens(canonicalQuery).map(_singularToken).toSet();
    final List<String> primaryTokens =
        _tokens(_normalize(name)).map(_singularToken).toList();
    final Set<String> primaryTokenSet = primaryTokens.toSet();
    final Set<String> matchedTokenSet =
        _tokens(_normalize(best.label)).map(_singularToken).toSet();

    final bool primaryContainsQuery =
        queryTokens.every(primaryTokenSet.contains);
    final bool matchedContainsQuery =
        queryTokens.every(matchedTokenSet.contains);

    if (!primaryContainsQuery && !matchedContainsQuery) return null;
    if (!primaryContainsQuery &&
        primaryTokenSet.intersection(queryTokens).isEmpty) {
      return null;
    }

    final Iterable<String> extraPrimaryTokens = primaryTokens.where(
      (String token) => !queryTokens.contains(token),
    );
    if (extraPrimaryTokens.any(
      (String token) => !_neutralDescriptors.contains(token),
    )) {
      return null;
    }

    final String normalizedName = _normalize(name);
    if ((normalizedName.contains(' by ') ||
            normalizedName.contains(' with ')) &&
        !canonicalQuery.contains(' by ') &&
        !canonicalQuery.contains(' with ')) {
      return null;
    }

    int score = best.score;
    score += _typeBoost(record['t']?.toString() ?? '');
    score += _quality(record) * 8;
    score -= extraPrimaryTokens.length * 120;

    final Map<String, Object?> values =
        (record['v'] as Map).map<String, Object?>(
      (dynamic key, dynamic value) {
        return MapEntry<String, Object?>(key.toString(), value);
      },
    );
    final List<String> qualityFlags =
        ((record['q'] as List?) ?? const <Object?>[])
            .map((Object? value) => value?.toString() ?? '')
            .where((String value) => value.isNotEmpty)
            .toList(growable: false);

    return _RankedRecord(
      externalId: externalId,
      name: name,
      aliases: aliases,
      typeCode: record['t']?.toString() ?? '',
      imageUrl: record['im']?.toString() ?? '',
      values: values,
      qualityFlags: qualityFlags,
      matchedLabel: best.label,
      matchKind: best.kind,
      score: score,
      quality: _quality(record),
    );
  }

  _LabelScore _scoreLabel(
    String query,
    String label, {
    required bool primary,
  }) {
    final String normalizedLabel = _normalize(label);
    if (query.isEmpty || normalizedLabel.isEmpty) {
      return _LabelScore.none(label);
    }

    final String singularQuery = _singularPhrase(query);
    final String singularLabel = _singularPhrase(normalizedLabel);
    final List<String> queryTokens = _tokens(query);
    final List<String> labelTokens = _tokens(normalizedLabel);

    int score = 0;
    String kind = 'none';

    if (normalizedLabel == query) {
      score = primary ? 30000 : 22000;
      kind = primary ? 'exact-primary' : 'exact-alias';
    } else if (singularLabel == singularQuery) {
      score = primary ? 29500 : 21500;
      kind = primary ? 'singular-primary' : 'singular-alias';
    } else if (normalizedLabel.startsWith('$query ')) {
      score = primary ? 24000 : 17000;
      kind = primary ? 'prefix-primary' : 'prefix-alias';
    } else if (_allTokensEquivalent(queryTokens, labelTokens)) {
      score = primary ? 20000 : 15000;
      kind = primary ? 'tokens-primary' : 'tokens-alias';
    } else if (normalizedLabel.contains(query)) {
      score = primary ? 10000 : 7000;
      kind = primary ? 'contains-primary' : 'contains-alias';
    }

    if (score > 0) {
      score -= (labelTokens.length - queryTokens.length).clamp(0, 20) * 35;
      score -= (normalizedLabel.length - query.length).abs().clamp(0, 220);
    }

    return _LabelScore(
      score: score,
      label: label,
      kind: kind,
    );
  }

  bool _allTokensEquivalent(
    List<String> queryTokens,
    List<String> candidateTokens,
  ) {
    return queryTokens.every((String queryToken) {
      final String singularQuery = _singularToken(queryToken);
      return candidateTokens.any(
        (String candidateToken) =>
            _singularToken(candidateToken) == singularQuery,
      );
    });
  }

  int _typeBoost(String type) {
    switch (_normalize(type)) {
      case 'everyday':
        return 500;
      case 'grocery':
        return 100;
      case 'prepared':
        return 0;
      case 'restaurant':
        return -300;
      default:
        return 0;
    }
  }

  int _quality(Map<String, Object?> record) {
    final Map<String, Object?> values =
        (record['v'] as Map?)?.map<String, Object?>(
              (dynamic key, dynamic value) =>
                  MapEntry<String, Object?>(key.toString(), value),
            ) ??
            const <String, Object?>{};

    int score = 0;
    if (values['k'] is num) score += 4;
    if (values['p'] is num) score += 2;
    if (values['c'] is num) score += 2;
    if (values['f'] is num) score += 2;
    if (values['fi'] is num) score += 1;
    if (values['su'] is num) score += 1;
    if (values['sa'] is num) score += 1;
    if ((record['im']?.toString() ?? '').isNotEmpty) score += 1;

    final Set<String> flags = ((record['q'] as List?) ?? const <Object?>[])
        .map((Object? value) => value?.toString() ?? '')
        .toSet();
    if (flags.contains('estimated_or_derived')) score -= 2;
    return score;
  }

  static String _routeKey(String query) {
    final String compact = _normalize(query).replaceAll(' ', '');
    return compact.substring(0, _routeLength);
  }

  static String _normalize(String input) {
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

  static List<String> _tokens(String value) {
    return value
        .split(' ')
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static String _singularPhrase(String value) {
    return _tokens(value).map(_singularToken).join(' ');
  }

  static String _singularToken(String token) {
    if (token.length > 4 && token.endsWith('ies')) {
      return '${token.substring(0, token.length - 3)}y';
    }
    if (token.length > 4 && token.endsWith('oes')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 4 &&
        (token.endsWith('ches') ||
            token.endsWith('shes') ||
            token.endsWith('sses') ||
            token.endsWith('xes') ||
            token.endsWith('zes'))) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s') && !token.endsWith('ss')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static void _validateRemoteUri(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw const OpenNutritionStaticIndexException(
        'URL OpenNutrition non sicuro.',
      );
    }
  }

  static bool _sameOrigin(Uri expected, Uri actual) {
    return expected.scheme == actual.scheme &&
        expected.host == actual.host &&
        expected.port == actual.port;
  }

  static bool _isSafeRelativeShardPath(String path, String route) {
    if (path != 'shards/$route.json.gz' ||
        path.startsWith('/') ||
        path.contains('\\') ||
        path.contains('..') ||
        Uri.tryParse(path)?.hasScheme == true) {
      return false;
    }
    return true;
  }

  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _routePattern = RegExp(r'^[a-z0-9_]{3}$');

  static const Set<String> _neutralDescriptors = <String>{
    'raw',
    'cooked',
    'dry',
    'dried',
    'fresh',
    'frozen',
    'whole',
    'plain',
    'canned',
    'drained',
    'boneless',
    'skinless',
    'fillet',
    'ground',
    'shredded',
    'rolled',
    'large',
    'small',
    'medium',
    'unsalted',
    'salted',
    'roasted',
    'boiled',
    'steamed',
    'baked',
    'grilled',
    'breast',
    'steak',
    'chop',
    'loin',
    'tenderloin',
    'belly',
    'shoulder',
    'leg',
    'back',
    'neck',
    'butt',
    'sirloin',
    'cheese',
    'ball',
    'lowfat',
    'nonfat',
    'fatfree',
    'reducedfat',
    'skim',
  };
}

class _StaticManifest {
  const _StaticManifest({
    required this.schemaVersion,
    required this.datasetVersion,
    required this.recordCount,
    required this.sha256,
    required this.shards,
  });

  final int schemaVersion;
  final String datasetVersion;
  final int recordCount;
  final String sha256;
  final Map<String, _StaticShardDescriptor> shards;
}

class _StaticShardDescriptor {
  const _StaticShardDescriptor({
    required this.route,
    required this.path,
    required this.sha256,
    required this.compressedBytes,
    required this.uncompressedBytes,
  });

  final String route;
  final String path;
  final String sha256;
  final int compressedBytes;
  final int uncompressedBytes;
}

class _LabelScore {
  const _LabelScore({
    required this.score,
    required this.label,
    required this.kind,
  });

  const _LabelScore.none(this.label)
      : score = 0,
        kind = 'none';

  final int score;
  final String label;
  final String kind;
}

class _RankedRecord {
  const _RankedRecord({
    required this.externalId,
    required this.name,
    required this.aliases,
    required this.typeCode,
    required this.imageUrl,
    required this.values,
    required this.qualityFlags,
    required this.matchedLabel,
    required this.matchKind,
    required this.score,
    required this.quality,
  });

  final String externalId;
  final String name;
  final List<String> aliases;
  final String typeCode;
  final String imageUrl;
  final Map<String, Object?> values;
  final List<String> qualityFlags;
  final String matchedLabel;
  final String matchKind;
  final int score;
  final int quality;
}
