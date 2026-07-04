import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

const int schemaVersion = 3;
const int routeLength = 3;
const int maximumFiles = 19000;
const int maximumShardBytes = 24 * 1024 * 1024;

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final sourcePath = options['source'];
  final outPath = options['out'];

  if (sourcePath == null || outPath == null) {
    stderr.writeln(
      'Usage: dart run build_full_candidate_v3.dart '
      '--source <v1-index> --out <v3-index>',
    );
    exitCode = 64;
    return;
  }

  final sourceDir = Directory(sourcePath);
  final outDir = Directory(outPath);
  if (!await sourceDir.exists()) {
    throw StateError('Indice sorgente non trovato: $sourcePath');
  }

  final sourceManifestFile = File(
    '${sourceDir.path}${Platform.pathSeparator}manifest.json',
  );
  final sourceManifest =
      jsonDecode(await sourceManifestFile.readAsString())
          as Map<String, Object?>;
  final datasetVersion = sourceManifest['datasetVersion']?.toString() ?? '';
  final sourceShards = (sourceManifest['shards'] as List)
      .cast<Map<String, Object?>>();

  if (await outDir.exists()) await outDir.delete(recursive: true);
  await outDir.create(recursive: true);

  final shardDir = Directory('${outDir.path}${Platform.pathSeparator}shards');
  final reportsDir = Directory(
    '${outDir.path}${Platform.pathSeparator}reports',
  );
  await shardDir.create(recursive: true);
  await reportsDir.create(recursive: true);

  final recordsById = <String, Map<String, Object?>>{};
  final typeCounts = <String, int>{};
  var verifiedSourceShards = 0;
  var sourceRecordReferences = 0;

  for (final shardEntry in sourceShards) {
    final relative = shardEntry['path']!.toString().replaceAll(
      '/',
      Platform.pathSeparator,
    );
    final file = File('${sourceDir.path}${Platform.pathSeparator}$relative');
    final bytes = await file.readAsBytes();
    final expectedHash = shardEntry['sha256']!.toString();
    final actualHash = sha256.convert(bytes).toString();

    if (actualHash != expectedHash) {
      throw StateError('Hash sorgente non valido: $relative');
    }
    verifiedSourceShards++;

    final decoded =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
    final records = (decoded['records'] as List).cast<Map<String, Object?>>();

    for (final raw in records) {
      sourceRecordReferences++;
      final record = Map<String, Object?>.from(raw);
      final id = record['id']?.toString() ?? '';
      final name = record['n']?.toString() ?? '';
      if (id.isEmpty || normalize(name).isEmpty) continue;

      final type = normalize(record['t']?.toString() ?? '');
      typeCounts[type.isEmpty ? '(empty)' : type] =
          (typeCounts[type.isEmpty ? '(empty)' : type] ?? 0) + 1;

      final previous = recordsById[id];
      if (previous == null || _quality(record) > _quality(previous)) {
        recordsById[id] = record;
      }
    }
  }

  final routes = <String, Map<String, Map<String, Object?>>>{};
  var primaryRouteReferences = 0;
  var aliasRouteReferences = 0;

  for (final record in recordsById.values) {
    final id = record['id']!.toString();
    final labels = <({String value, bool primary})>[
      (value: record['n']!.toString(), primary: true),
      for (final alias in ((record['a'] as List?) ?? const <Object?>[]))
        (value: alias.toString(), primary: false),
    ];

    final seenRoutes = <String>{};
    for (final label in labels) {
      final route = routeKey(label.value);
      if (route.isEmpty || !seenRoutes.add(route)) continue;

      routes.putIfAbsent(route, () => <String, Map<String, Object?>>{})[id] =
          record;

      if (label.primary) {
        primaryRouteReferences++;
      } else {
        aliasRouteReferences++;
      }
    }
  }

  final routeNames = routes.keys.toList()..sort();
  if (routeNames.length + 5 > maximumFiles) {
    throw StateError('Troppi asset: ${routeNames.length + 5} > $maximumFiles');
  }

  final manifestShards = <Map<String, Object?>>[];
  final routeIndex = <String, List<String>>{};
  var totalCompressedBytes = 0;
  var maxCompressedBytes = 0;
  var totalShardReferences = 0;

  for (final route in routeNames) {
    final records = routes[route]!.values.toList()
      ..sort((a, b) {
        final byName = normalize(
          a['n']!.toString(),
        ).compareTo(normalize(b['n']!.toString()));
        if (byName != 0) return byName;

        final byQuality = _quality(b).compareTo(_quality(a));
        if (byQuality != 0) return byQuality;

        return a['id']!.toString().compareTo(b['id']!.toString());
      });

    final payload = utf8.encode(
      jsonEncode(<String, Object?>{
        'schemaVersion': schemaVersion,
        'datasetVersion': datasetVersion,
        'route': route,
        'records': records,
      }),
    );
    final compressed = gzip.encode(payload);

    if (compressed.length > maximumShardBytes) {
      throw StateError('Shard $route oltre il limite: ${compressed.length}');
    }

    final file = File(
      '${shardDir.path}${Platform.pathSeparator}$route.json.gz',
    );
    await file.writeAsBytes(compressed, flush: true);

    totalCompressedBytes += compressed.length;
    maxCompressedBytes = math.max(maxCompressedBytes, compressed.length);
    totalShardReferences += records.length;

    final base = route.substring(0, math.min(2, route.length));
    routeIndex.putIfAbsent(base, () => <String>[]).add(route);

    manifestShards.add(<String, Object?>{
      'route': route,
      'path': 'shards/$route.json.gz',
      'recordCount': records.length,
      'uncompressedBytes': payload.length,
      'compressedBytes': compressed.length,
      'sha256': sha256.convert(compressed).toString(),
    });
  }

  for (final routes in routeIndex.values) {
    routes.sort();
  }

  final benchmark = _runBenchmark(queries: benchmarkQueries, routes: routes);
  final foundCount = benchmark.where((row) => row['found'] == true).length;
  final top1Pass = benchmark.where((row) => row['top1Pass'] == true).length;

  final manifest = <String, Object?>{
    'schemaVersion': schemaVersion,
    'datasetVersion': datasetVersion,
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'source': sourceManifest['source'],
    'policy': <String, Object?>{
      'sourceRole': 'secondary-complement',
      'primarySource': 'open_food_facts',
      'includedTypes': <String>[
        'everyday',
        'grocery',
        'prepared',
        'restaurant',
      ],
      'reasonForKeepingGrocery':
          'Source provenance does not prove equivalence with Open Food Facts; '
          'priority and deduplication are enforced by the app coordinator.',
      'aliasRouting': true,
      'ranking': 'strict-primary-first-v3',
      'routeLength': routeLength,
      'queryTranslation': 'on-device before routing',
      'importRequiresSummaryConfirmation': true,
    },
    'recordCount': recordsById.length,
    'shardRecordReferences': totalShardReferences,
    'shardCount': manifestShards.length,
    'assetFileCount': manifestShards.length + 5,
    'totalCompressedBytes': totalCompressedBytes,
    'maxCompressedShardBytes': maxCompressedBytes,
    'routeIndex': routeIndex,
    'shards': manifestShards,
  };

  final manifestText = const JsonEncoder.withIndent('  ').convert(manifest);
  final manifestFile = File(
    '${outDir.path}${Platform.pathSeparator}manifest.json',
  );
  await manifestFile.writeAsString(manifestText, flush: true);

  final manifestHash = sha256.convert(utf8.encode(manifestText)).toString();
  await File(
    '${outDir.path}${Platform.pathSeparator}manifest.sha256',
  ).writeAsString('$manifestHash  manifest.json\n', flush: true);

  final audit = <String, Object?>{
    'datasetVersion': datasetVersion,
    'verifiedSourceShards': verifiedSourceShards,
    'sourceRecordReferences': sourceRecordReferences,
    'uniqueRecords': recordsById.length,
    'typeCounts': _sortedCounts(typeCounts),
    'primaryRouteReferences': primaryRouteReferences,
    'aliasRouteReferences': aliasRouteReferences,
    'shardRecordReferences': totalShardReferences,
    'shardCount': manifestShards.length,
    'assetFileCount': manifestShards.length + 5,
    'totalCompressedBytes': totalCompressedBytes,
    'maxCompressedShardBytes': maxCompressedBytes,
    'manifestSha256': manifestHash,
    'benchmarkFound': foundCount,
    'benchmarkTop1Pass': top1Pass,
    'benchmarkCount': benchmark.length,
  };

  await File(
    '${reportsDir.path}${Platform.pathSeparator}candidate_audit.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(audit),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}benchmark.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(benchmark),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}benchmark.csv',
  ).writeAsString(_benchmarkCsv(benchmark), flush: true);
  await File(
    '${reportsDir.path}${Platform.pathSeparator}summary.md',
  ).writeAsString(_summaryMarkdown(audit), flush: true);

  await File('${outDir.path}${Platform.pathSeparator}README.md').writeAsString(
    '# Total Tracker OpenNutrition static index candidate v3\n\n'
    'This index is a derived database from OpenNutrition and is distributed '
    'under ODbL 1.0. Open Food Facts remains the primary source in Total '
    'Tracker. OpenNutrition results are secondary, locally ranked, translated '
    'on device, and imported only after user confirmation.\n\n'
    'Attribution: OpenNutrition — https://www.opennutrition.app/\n',
    flush: true,
  );

  await File(
    '${outDir.path}${Platform.pathSeparator}ODBL-NOTICE.txt',
  ).writeAsString(
    'Contains information derived from OpenNutrition. '
    'This derived database is made available under the '
    'Open Database License (ODbL) 1.0.\n',
    flush: true,
  );

  stdout.writeln('FULL_CANDIDATE_V3_OK');
  stdout.writeln('RECORDS=${recordsById.length}');
  stdout.writeln('SHARDS=${manifestShards.length}');
  stdout.writeln('ASSET_FILES=${manifestShards.length + 5}');
  stdout.writeln('COMPRESSED_BYTES=$totalCompressedBytes');
  stdout.writeln('MAX_SHARD_BYTES=$maxCompressedBytes');
  stdout.writeln('BENCHMARK_TOP1=$top1Pass/${benchmark.length}');
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var index = 0; index < args.length; index++) {
    final key = args[index];
    if (!key.startsWith('--') || index + 1 >= args.length) continue;
    result[key.substring(2)] = args[++index];
  }
  return result;
}

String routeKey(String label) {
  final compact = normalize(label).replaceAll(' ', '');
  if (compact.isEmpty) return '';

  if (compact.length >= routeLength) {
    return compact.substring(0, routeLength);
  }

  return compact.padRight(routeLength, '_');
}

List<String> routesForQuery(String query, Iterable<String> availableRoutes) {
  final compact = normalize(query).replaceAll(' ', '');
  if (compact.isEmpty) return const <String>[];

  if (compact.length >= routeLength) {
    final exact = compact.substring(0, routeLength);
    return availableRoutes.contains(exact) ? <String>[exact] : const <String>[];
  }

  final prefix = compact
      .padRight(compact.length, '_')
      .substring(0, compact.length);

  final matches =
      availableRoutes.where((route) => route.startsWith(prefix)).toList()
        ..sort();
  return matches;
}

List<Map<String, Object?>> _runBenchmark({
  required List<_BenchmarkQuery> queries,
  required Map<String, Map<String, Map<String, Object?>>> routes,
}) {
  final rows = <Map<String, Object?>>[];

  for (final query in queries) {
    final selectedRoutes = routesForQuery(query.canonical, routes.keys);
    final candidates = <String, Map<String, Object?>>{};

    for (final route in selectedRoutes) {
      candidates.addAll(routes[route] ?? const {});
    }

    final scored = <_Scored>[];
    for (final record in candidates.values) {
      final result = scoreRecord(query.canonical, record);
      if (result.score > 0) scored.add(result);
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;

      final byQuality = _quality(b.record).compareTo(_quality(a.record));
      if (byQuality != 0) return byQuality;

      final aName = a.record['n']?.toString() ?? '';
      final bName = b.record['n']?.toString() ?? '';
      final byLength = aName.length.compareTo(bName.length);
      if (byLength != 0) return byLength;

      return aName.compareTo(bName);
    });

    final top = scored.take(5).toList();
    final pass = top.isNotEmpty && query.accept(top.first);

    rows.add(<String, Object?>{
      'query': query.query,
      'canonicalQuery': query.canonical,
      'routes': selectedRoutes,
      'found': top.isNotEmpty,
      'top1Pass': pass,
      'topResults': <Map<String, Object?>>[
        for (final result in top) result.toJson(),
      ],
    });
  }

  return rows;
}

_Scored scoreRecord(String query, Map<String, Object?> record) {
  final primary = record['n']?.toString() ?? '';
  final aliases = ((record['a'] as List?) ?? const <Object?>[]).map(
    (value) => value.toString(),
  );

  var best = _scoreLabel(query, primary, primary: true);
  for (final alias in aliases) {
    final candidate = _scoreLabel(query, alias, primary: false);
    if (candidate.score > best.score) best = candidate;
  }

  if (best.score <= 0) {
    return _Scored(0, record, '', false, 'none');
  }

  var score = best.score;
  score += _typeBoost(record['t']?.toString() ?? '');
  score += math.min(120, _quality(record) * 8);

  final queryTokens = tokens(normalize(query)).toSet();
  final primaryTokens = tokens(normalize(primary)).toSet();
  final unexpectedModifiers = primaryTokens.where(
    (token) => dishModifiers.contains(token) && !queryTokens.contains(token),
  );
  score -= unexpectedModifiers.length * 1500;

  if (normalize(primary).contains(' by ') &&
      !normalize(query).contains(' by ')) {
    score -= 1200;
  }

  return _Scored(
    score,
    record,
    best.matchedLabel,
    best.matchedPrimary,
    best.matchKind,
  );
}

_Scored _scoreLabel(String query, String label, {required bool primary}) {
  final q = normalize(query);
  final candidate = normalize(label);

  if (q.isEmpty || candidate.isEmpty) {
    return _Scored(0, const <String, Object?>{}, label, primary, 'none');
  }

  final queryTokens = tokens(q);
  final candidateTokens = tokens(candidate);
  final singularQuery = singularPhrase(q);
  final singularCandidate = singularPhrase(candidate);

  var score = 0;
  var kind = 'none';

  if (candidate == q) {
    score = primary ? 14000 : 9500;
    kind = primary ? 'exact-primary' : 'exact-alias';
  } else if (singularCandidate == singularQuery) {
    score = primary ? 13500 : 9200;
    kind = primary ? 'singular-primary' : 'singular-alias';
  } else if (candidate.startsWith('$q ')) {
    score = primary ? 10000 : 7600;
    kind = primary ? 'prefix-primary' : 'prefix-alias';
  } else if (_allTokensEquivalent(queryTokens, candidateTokens)) {
    score = primary ? 8200 : 6400;
    kind = primary ? 'tokens-primary' : 'tokens-alias';
  } else if (candidate.contains(q)) {
    score = primary ? 6500 : 4500;
    kind = primary ? 'contains-primary' : 'contains-alias';
  }

  if (score > 0) {
    score -= math.max(0, candidateTokens.length - queryTokens.length) * 35;
    score -= math.min(220, (candidate.length - q.length).abs());
  }

  return _Scored(score, const <String, Object?>{}, label, primary, kind);
}

bool _allTokensEquivalent(
  List<String> queryTokens,
  List<String> candidateTokens,
) {
  return queryTokens.every(
    (queryToken) => candidateTokens.any(
      (candidateToken) =>
          singularToken(queryToken) == singularToken(candidateToken),
    ),
  );
}

int _typeBoost(String type) {
  switch (normalize(type)) {
    case 'everyday':
      return 500;
    case 'grocery':
      return 250;
    case 'prepared':
      return 100;
    case 'restaurant':
      return -100;
    default:
      return 0;
  }
}

int _quality(Map<String, Object?> record) {
  final values =
      (record['v'] as Map?)?.cast<String, Object?>() ??
      const <String, Object?>{};
  var score = 0;

  if (values['k'] != null) score += 4;
  if (values['p'] != null) score += 2;
  if (values['c'] != null) score += 2;
  if (values['f'] != null) score += 2;
  if (values['fi'] != null) score += 1;
  if (values['su'] != null) score += 1;
  if (values['sa'] != null) score += 1;
  if ((record['im']?.toString() ?? '').isNotEmpty) score += 1;

  final flags = ((record['q'] as List?) ?? const <Object?>[])
      .map((value) => value.toString())
      .toSet();
  if (flags.contains('estimated_or_derived')) score -= 2;

  return score;
}

String normalize(String input) {
  var value = input.toLowerCase().trim();
  const replacements = <String, String>{
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

  replacements.forEach((from, to) => value = value.replaceAll(from, to));

  return value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

List<String> tokens(String value) {
  return value.split(' ').where((token) => token.isNotEmpty).toList();
}

String singularPhrase(String value) {
  return tokens(value).map(singularToken).join(' ');
}

String singularToken(String token) {
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

List<Map<String, Object>> _sortedCounts(Map<String, int> input) {
  final entries = input.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });

  return <Map<String, Object>>[
    for (final entry in entries)
      <String, Object>{'value': entry.key, 'count': entry.value},
  ];
}

String _benchmarkCsv(List<Map<String, Object?>> rows) {
  final buffer = StringBuffer(
    'query,canonical_query,found,top1_pass,top_name,'
    'matched_label,match_kind,score,type\n',
  );

  for (final row in rows) {
    final results = (row['topResults'] as List).cast<Map<String, Object?>>();
    final top = results.isEmpty ? null : results.first;

    buffer.writeln(
      <Object?>[
        _csv(row['query']),
        _csv(row['canonicalQuery']),
        row['found'],
        row['top1Pass'],
        _csv(top?['n']),
        _csv(top?['matchedLabel']),
        _csv(top?['matchKind']),
        top?['score'] ?? '',
        _csv(top?['t']),
      ].join(','),
    );
  }

  return buffer.toString();
}

String _summaryMarkdown(Map<String, Object?> audit) {
  final totalMib = (audit['totalCompressedBytes'] as int) / (1024 * 1024);

  return '# OpenNutrition full candidate index v3\n\n'
      '- Dataset version: `${audit['datasetVersion']}`\n'
      '- Unique records: `${audit['uniqueRecords']}`\n'
      '- Shards: `${audit['shardCount']}`\n'
      '- Static asset files: `${audit['assetFileCount']}`\n'
      '- Alias route references: `${audit['aliasRouteReferences']}`\n'
      '- Total compressed size: `${totalMib.toStringAsFixed(2)} MiB`\n'
      '- Largest shard: `${audit['maxCompressedShardBytes']}` bytes\n'
      '- Benchmark coverage: `${audit['benchmarkFound']}/${audit['benchmarkCount']}`\n'
      '- Strict top-1: `${audit['benchmarkTop1Pass']}/${audit['benchmarkCount']}`\n'
      '- Manifest SHA-256: `${audit['manifestSha256']}`\n';
}

String _csv(Object? value) {
  final text = value?.toString() ?? '';
  return '"${text.replaceAll('"', '""')}"';
}

class _Scored {
  const _Scored(
    this.score,
    this.record,
    this.matchedLabel,
    this.matchedPrimary,
    this.matchKind,
  );

  final int score;
  final Map<String, Object?> record;
  final String matchedLabel;
  final bool matchedPrimary;
  final String matchKind;

  Map<String, Object?> toJson() => <String, Object?>{
    'score': score,
    'matchedLabel': matchedLabel,
    'matchedPrimary': matchedPrimary,
    'matchKind': matchKind,
    ...record,
  };
}

class _BenchmarkQuery {
  const _BenchmarkQuery(
    this.query,
    this.canonical,
    this.required, {
    this.alternatives = const <List<String>>[],
    this.allowedModifiers = const <String>{},
  });

  final String query;
  final String canonical;
  final List<String> required;
  final List<List<String>> alternatives;
  final Set<String> allowedModifiers;

  bool accept(_Scored result) {
    final primary = normalize(result.record['n']?.toString() ?? '');
    final matched = normalize(result.matchedLabel);
    final combinedTokens = <String>{
      ...tokens(primary).map(singularToken),
      ...tokens(matched).map(singularToken),
    };

    final requiredPass = required.every(
      (token) => combinedTokens.contains(singularToken(normalize(token))),
    );

    final alternativePass = alternatives.any(
      (group) => group.every(
        (token) => combinedTokens.contains(singularToken(normalize(token))),
      ),
    );

    if (!requiredPass && !alternativePass) return false;

    final queryTokens = tokens(normalize(canonical)).toSet();
    final primaryTokens = tokens(primary).toSet();

    for (final modifier in dishModifiers) {
      if (primaryTokens.contains(modifier) &&
          !queryTokens.contains(modifier) &&
          !allowedModifiers.contains(modifier)) {
        return false;
      }
    }

    return true;
  }
}

const Set<String> dishModifiers = <String>{
  'pie',
  'tart',
  'crisp',
  'syrup',
  'juice',
  'jam',
  'jelly',
  'cake',
  'mochi',
  'bun',
  'roll',
  'kugel',
  'chip',
  'chips',
  'soup',
  'sauce',
  'paste',
  'ketchup',
  'muffin',
  'jerky',
  'burger',
  'salad',
  'casserole',
  'sandwich',
  'melt',
  'gravy',
  'liver',
  'bacon',
  'flour',
  'spice',
  'seasoning',
  'powder',
  'omelette',
  'protein',
  'teriyaki',
  'marinade',
  'dressing',
  'cookie',
  'candy',
  'tamale',
  'rind',
  'rinds',
  'snout',
  'yolk',
  'white',
  'whites',
  'salami',
  'bran',
  'primavera',
};

const List<_BenchmarkQuery> benchmarkQueries = <_BenchmarkQuery>[
  _BenchmarkQuery('petto di pollo', 'chicken breast', <String>[
    'chicken',
    'breast',
  ]),
  _BenchmarkQuery('riso basmati', 'basmati rice', <String>['basmati', 'rice']),
  _BenchmarkQuery('riso integrale', 'brown rice', <String>['brown', 'rice']),
  _BenchmarkQuery('pasta', 'pasta', <String>['pasta']),
  _BenchmarkQuery('pane integrale', 'whole wheat bread', <String>[
    'whole',
    'wheat',
    'bread',
  ]),
  _BenchmarkQuery('mela', 'apple', <String>['apple']),
  _BenchmarkQuery('banana', 'banana', <String>['banana']),
  _BenchmarkQuery('arancia', 'orange', <String>['orange']),
  _BenchmarkQuery('fragola', 'strawberry', <String>['strawberry']),
  _BenchmarkQuery('mirtilli', 'blueberries', <String>['blueberry']),
  _BenchmarkQuery('avocado', 'avocado', <String>['avocado']),
  _BenchmarkQuery('patate', 'potato', <String>['potato']),
  _BenchmarkQuery('patata dolce', 'sweet potato', <String>['sweet', 'potato']),
  _BenchmarkQuery('pomodoro', 'tomato', <String>['tomato']),
  _BenchmarkQuery('zucchine', 'zucchini', <String>['zucchini']),
  _BenchmarkQuery('broccoli', 'broccoli', <String>['broccoli']),
  _BenchmarkQuery('spinaci', 'spinach', <String>['spinach']),
  _BenchmarkQuery('carote', 'carrot', <String>['carrot']),
  _BenchmarkQuery('lenticchie', 'lentils', <String>['lentil']),
  _BenchmarkQuery('ceci', 'chickpeas', <String>['chickpea']),
  _BenchmarkQuery('fagioli neri', 'black beans', <String>['black', 'bean']),
  _BenchmarkQuery('salmone', 'salmon', <String>['salmon']),
  _BenchmarkQuery('tonno', 'tuna', <String>['tuna']),
  _BenchmarkQuery('merluzzo', 'cod', <String>['cod']),
  _BenchmarkQuery('gamberetti', 'shrimp', <String>['shrimp']),
  _BenchmarkQuery('uovo', 'egg', <String>['egg']),
  _BenchmarkQuery(
    'albume',
    'egg white',
    <String>['egg', 'white'],
    allowedModifiers: <String>{'white', 'whites'},
  ),
  _BenchmarkQuery('latte intero', 'whole milk', <String>['whole', 'milk']),
  _BenchmarkQuery('yogurt greco', 'greek yogurt', <String>['greek', 'yogurt']),
  _BenchmarkQuery('mozzarella', 'mozzarella', <String>['mozzarella']),
  _BenchmarkQuery('parmigiano', 'parmesan', <String>['parmesan']),
  _BenchmarkQuery('fiocchi di latte', 'cottage cheese', <String>[
    'cottage',
    'cheese',
  ]),
  _BenchmarkQuery('mandorle', 'almonds', <String>['almond']),
  _BenchmarkQuery('noci', 'walnuts', <String>['walnut']),
  _BenchmarkQuery('burro di arachidi', 'peanut butter', <String>[
    'peanut',
    'butter',
  ]),
  _BenchmarkQuery('olio di oliva', 'olive oil', <String>['olive', 'oil']),
  _BenchmarkQuery('burro', 'butter', <String>['butter']),
  _BenchmarkQuery('avena', 'oats', <String>['oat']),
  _BenchmarkQuery('quinoa', 'quinoa', <String>['quinoa']),
  _BenchmarkQuery('cous cous', 'couscous', <String>['couscous']),
  _BenchmarkQuery('manzo macinato', 'ground beef', <String>['ground', 'beef']),
  _BenchmarkQuery('bistecca', 'beef steak', <String>['beef', 'steak']),
  _BenchmarkQuery('maiale', 'pork', <String>['pork']),
  _BenchmarkQuery('tacchino', 'turkey', <String>['turkey']),
  _BenchmarkQuery('prosciutto', 'ham', <String>['ham']),
  _BenchmarkQuery('tofu', 'tofu', <String>['tofu']),
  _BenchmarkQuery(
    'cioccolato fondente',
    'dark chocolate',
    <String>['dark', 'chocolate'],
    alternatives: <List<String>>[
      <String>['bittersweet', 'chocolate'],
    ],
  ),
  _BenchmarkQuery('miele', 'honey', <String>['honey']),
  _BenchmarkQuery('zucchero', 'sugar', <String>['sugar']),
  _BenchmarkQuery(
    'pizza margherita',
    'margherita pizza',
    <String>['margherita', 'pizza'],
    alternatives: <List<String>>[
      <String>['margherita', 'flatbread'],
    ],
  ),
];
