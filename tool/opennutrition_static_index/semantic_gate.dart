import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final indexPath = options['index'];
  final outPath = options['out'];

  if (indexPath == null || outPath == null) {
    stderr.writeln(
      'Usage: dart run semantic_gate_v5.dart '
      '--index <candidate-v3> --out <report-dir>',
    );
    exitCode = 64;
    return;
  }

  final indexDir = Directory(indexPath);
  final outDir = Directory(outPath);

  if (!await indexDir.exists()) {
    throw StateError('Indice candidato non trovato: $indexPath');
  }
  await outDir.create(recursive: true);

  final manifestFile = File(
    '${indexDir.path}${Platform.pathSeparator}manifest.json',
  );
  final manifestHashFile = File(
    '${indexDir.path}${Platform.pathSeparator}manifest.sha256',
  );

  final manifestBytes = await manifestFile.readAsBytes();
  final actualManifestHash = sha256.convert(manifestBytes).toString();
  final expectedManifestHash = (await manifestHashFile.readAsString())
      .trim()
      .split(RegExp(r'\s+'))
      .first;

  if (actualManifestHash != expectedManifestHash) {
    throw StateError('Hash manifest non valido.');
  }

  final manifest =
      jsonDecode(utf8.decode(manifestBytes)) as Map<String, Object?>;
  final shardEntries = (manifest['shards'] as List)
      .cast<Map<String, Object?>>();

  final routes = <String, List<Map<String, Object?>>>{};
  final uniqueRecords = <String, Map<String, Object?>>{};
  var verifiedShards = 0;
  var loadedReferences = 0;

  for (final shardEntry in shardEntries) {
    final route = shardEntry['route']?.toString() ?? '';
    final relative = shardEntry['path']?.toString() ?? '';
    final shardFile = File(
      '${indexDir.path}${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}',
    );
    final bytes = await shardFile.readAsBytes();
    final expected = shardEntry['sha256']?.toString() ?? '';
    final actual = sha256.convert(bytes).toString();

    if (route.isEmpty || expected.isEmpty || expected != actual) {
      throw StateError('Shard non valido: $relative');
    }

    verifiedShards++;
    final decoded =
        jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
    final records = (decoded['records'] as List).cast<Map<String, Object?>>();

    routes[route] = records;
    loadedReferences += records.length;

    for (final record in records) {
      final id = record['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      final previous = uniqueRecords[id];
      if (previous == null || _quality(record) > _quality(previous)) {
        uniqueRecords[id] = record;
      }
    }
  }

  final benchmark = <Map<String, Object?>>[];
  var strictTop1Pass = 0;
  var acceptableTop5 = 0;
  var routedFound = 0;
  var routingAgreement = 0;

  for (final query in benchmarkQueries) {
    final selectedRoutes = _routesForQuery(query.canonical, routes.keys);

    final routedRecords = <String, Map<String, Object?>>{};
    for (final route in selectedRoutes) {
      for (final record in routes[route] ?? const <Map<String, Object?>>[]) {
        final id = record['id']?.toString() ?? '';
        if (id.isNotEmpty) routedRecords[id] = record;
      }
    }

    final routed = _search(query.canonical, routedRecords.values, limit: 12);
    final global = _search(query.canonical, uniqueRecords.values, limit: 12);

    final top1Pass = routed.isNotEmpty && query.accept(routed.first);
    final top5Pass = routed.take(5).any(query.accept);
    final agreement =
        routed.isNotEmpty &&
        global.isNotEmpty &&
        routed.first.record['id'] == global.first.record['id'];

    if (routed.isNotEmpty) routedFound++;
    if (top1Pass) strictTop1Pass++;
    if (top5Pass) acceptableTop5++;
    if (agreement) routingAgreement++;

    benchmark.add(<String, Object?>{
      'query': query.query,
      'canonicalQuery': query.canonical,
      'selectedRoutes': selectedRoutes,
      'found': routed.isNotEmpty,
      'strictTop1Pass': top1Pass,
      'acceptableInTop5': top5Pass,
      'routingAgreement': agreement,
      'routedTopResults': <Map<String, Object?>>[
        for (final result in routed.take(8)) result.toJson(),
      ],
      'globalTopResults': <Map<String, Object?>>[
        for (final result in global.take(8)) result.toJson(),
      ],
    });
  }

  final failures = benchmark
      .where((row) => row['strictTop1Pass'] != true)
      .toList();

  final summary = <String, Object?>{
    'gateVersion': 5,
    'datasetVersion': manifest['datasetVersion'],
    'schemaVersion': manifest['schemaVersion'],
    'manifestSha256': actualManifestHash,
    'verifiedShards': verifiedShards,
    'loadedRecordReferences': loadedReferences,
    'uniqueLoadedRecords': uniqueRecords.length,
    'benchmarkCount': benchmarkQueries.length,
    'routedFound': routedFound,
    'strictTop1Pass': strictTop1Pass,
    'acceptableInTop5': acceptableTop5,
    'routingAgreement': routingAgreement,
    'failureCount': failures.length,
    'candidateDecision': strictTop1Pass == benchmarkQueries.length
        ? 'PASS_SEMANTIC_GATE_V5'
        : 'REQUIRES_RANKING_REFINEMENT',
  };

  await File(
    '${outDir.path}${Platform.pathSeparator}semantic_gate_v5_summary.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(summary),
    flush: true,
  );
  await File(
    '${outDir.path}${Platform.pathSeparator}semantic_gate_v5_benchmark.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(benchmark),
    flush: true,
  );
  await File(
    '${outDir.path}${Platform.pathSeparator}semantic_gate_v5_failures.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(failures),
    flush: true,
  );
  await File(
    '${outDir.path}${Platform.pathSeparator}semantic_gate_v5.csv',
  ).writeAsString(_benchmarkCsv(benchmark), flush: true);
  await File(
    '${outDir.path}${Platform.pathSeparator}ranking_spec_v5.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(_rankingSpec()),
    flush: true,
  );
  await File(
    '${outDir.path}${Platform.pathSeparator}summary.md',
  ).writeAsString(_summaryMarkdown(summary), flush: true);

  stdout.writeln('SEMANTIC_GATE_V5_OK');
  stdout.writeln('VERIFIED_SHARDS=$verifiedShards');
  stdout.writeln('STRICT_TOP1=$strictTop1Pass/${benchmarkQueries.length}');
  stdout.writeln('ACCEPTABLE_TOP5=$acceptableTop5/${benchmarkQueries.length}');
  stdout.writeln(
    'ROUTING_AGREEMENT=$routingAgreement/${benchmarkQueries.length}',
  );
  stdout.writeln('DECISION=${summary['candidateDecision']}');
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

List<String> _routesForQuery(String query, Iterable<String> availableRoutes) {
  final compact = normalize(query).replaceAll(' ', '');
  if (compact.isEmpty) return const <String>[];

  if (compact.length >= 3) {
    final route = compact.substring(0, 3);
    return availableRoutes.contains(route) ? <String>[route] : const <String>[];
  }

  final matches =
      availableRoutes.where((route) => route.startsWith(compact)).toList()
        ..sort();
  return matches;
}

List<_Scored> _search(
  String query,
  Iterable<Map<String, Object?>> records, {
  required int limit,
}) {
  final results = <_Scored>[];

  for (final record in records) {
    final result = _scoreRecord(query, record);
    if (result.score > 0) results.add(result);
  }

  results.sort((a, b) {
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

  return results.take(limit).toList();
}

_Scored _scoreRecord(String query, Map<String, Object?> record) {
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
    return _Scored(
      score: 0,
      record: record,
      matchedLabel: '',
      matchedPrimary: false,
      matchKind: 'none',
      penalties: const <String>[],
    );
  }

  var score = best.score;
  final penalties = <String>[];

  score += _typeBoost(record['t']?.toString() ?? '');
  score += math.min(120, _quality(record) * 8);

  final queryTokens = tokens(normalize(query)).map(singularToken).toSet();
  final primaryTokens = tokens(normalize(primary)).map(singularToken).toList();
  final primaryTokenSet = primaryTokens.toSet();
  final overlap = primaryTokenSet.intersection(queryTokens).length;

  if (!best.matchedPrimary && overlap == 0) {
    score -= 8000;
    penalties.add('alias-primary-divergence');
  } else if (!best.matchedPrimary && overlap < queryTokens.length) {
    score -= 3000;
    penalties.add('alias-partial-primary-overlap');
  }

  final extras = primaryTokens
      .where((token) => !queryTokens.contains(token))
      .toList();

  for (final extra in extras) {
    if (neutralDescriptors.contains(extra)) continue;

    if (hardModifiers.contains(extra)) {
      score -= 6000;
      penalties.add('hard-modifier:$extra');
      continue;
    }

    if (relationTokens.contains(extra)) {
      score -= 5000;
      penalties.add('composition-token:$extra');
      continue;
    }

    score -= 1500;
    penalties.add('unknown-extra:$extra');
  }

  final normalizedPrimary = normalize(primary);
  final normalizedQuery = normalize(query);

  if (normalizedPrimary.contains(' by ') && !normalizedQuery.contains(' by ')) {
    score -= 7000;
    penalties.add('brand-by-pattern');
  }

  if (normalizedPrimary.contains(' with ') &&
      !normalizedQuery.contains(' with ')) {
    score -= 6000;
    penalties.add('unexpected-with-composition');
  }

  return _Scored(
    score: score,
    record: record,
    matchedLabel: best.matchedLabel,
    matchedPrimary: best.matchedPrimary,
    matchKind: best.matchKind,
    penalties: penalties,
  );
}

_Scored _scoreLabel(String query, String label, {required bool primary}) {
  final q = normalize(query);
  final candidate = normalize(label);

  if (q.isEmpty || candidate.isEmpty) {
    return _Scored(
      score: 0,
      record: const <String, Object?>{},
      matchedLabel: label,
      matchedPrimary: primary,
      matchKind: 'none',
      penalties: const <String>[],
    );
  }

  final singularQuery = singularPhrase(q);
  final singularCandidate = singularPhrase(candidate);
  final queryTokens = tokens(q);
  final candidateTokens = tokens(candidate);

  var score = 0;
  var kind = 'none';

  if (candidate == q) {
    score = primary ? 30000 : 22000;
    kind = primary ? 'exact-primary' : 'exact-alias';
  } else if (singularCandidate == singularQuery) {
    score = primary ? 29500 : 21500;
    kind = primary ? 'singular-primary' : 'singular-alias';
  } else if (candidate.startsWith('$q ')) {
    score = primary ? 24000 : 17000;
    kind = primary ? 'prefix-primary' : 'prefix-alias';
  } else if (_allTokensEquivalent(queryTokens, candidateTokens)) {
    score = primary ? 20000 : 15000;
    kind = primary ? 'tokens-primary' : 'tokens-alias';
  } else if (candidate.contains(q)) {
    score = primary ? 10000 : 7000;
    kind = primary ? 'contains-primary' : 'contains-alias';
  }

  if (score > 0) {
    score -= math.max(0, candidateTokens.length - queryTokens.length) * 35;
    score -= math.min(220, (candidate.length - q.length).abs());
  }

  return _Scored(
    score: score,
    record: const <String, Object?>{},
    matchedLabel: label,
    matchedPrimary: primary,
    matchKind: kind,
    penalties: const <String>[],
  );
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

Map<String, Object?> _rankingSpec() => <String, Object?>{
  'version': 5,
  'labelScores': <String, int>{
    'exactPrimary': 30000,
    'singularPrimary': 29500,
    'prefixPrimary': 24000,
    'exactAlias': 22000,
    'singularAlias': 21500,
    'tokensPrimary': 20000,
    'prefixAlias': 17000,
    'tokensAlias': 15000,
    'containsPrimary': 10000,
    'containsAlias': 7000,
  },
  'penalties': <String, int>{
    'aliasPrimaryDivergence': -8000,
    'aliasPartialPrimaryOverlap': -3000,
    'hardModifier': -6000,
    'compositionToken': -5000,
    'unknownExtra': -1500,
    'brandByPattern': -7000,
    'unexpectedWithComposition': -6000,
  },
  'neutralDescriptors': neutralDescriptors.toList()..sort(),
  'hardModifiers': hardModifiers.toList()..sort(),
  'relationTokens': relationTokens.toList()..sort(),
};

String _benchmarkCsv(List<Map<String, Object?>> rows) {
  final buffer = StringBuffer(
    'query,canonical_query,found,strict_top1_pass,acceptable_in_top5,'
    'top_name,matched_label,match_kind,score,penalties,type\n',
  );

  for (final row in rows) {
    final results = (row['routedTopResults'] as List)
        .cast<Map<String, Object?>>();
    final top = results.isEmpty ? null : results.first;

    buffer.writeln(
      <Object?>[
        _csv(row['query']),
        _csv(row['canonicalQuery']),
        row['found'],
        row['strictTop1Pass'],
        row['acceptableInTop5'],
        _csv(top?['n']),
        _csv(top?['matchedLabel']),
        _csv(top?['matchKind']),
        top?['score'] ?? '',
        _csv(((top?['penalties'] as List?) ?? const <Object?>[]).join('|')),
        _csv(top?['t']),
      ].join(','),
    );
  }

  return buffer.toString();
}

String _summaryMarkdown(Map<String, Object?> summary) {
  return '# OpenNutrition semantic gate v5\n\n'
      '- Dataset version: `${summary['datasetVersion']}`\n'
      '- Verified shards: `${summary['verifiedShards']}`\n'
      '- Unique records: `${summary['uniqueLoadedRecords']}`\n'
      '- Routed coverage: `${summary['routedFound']}/${summary['benchmarkCount']}`\n'
      '- Strict top-1: `${summary['strictTop1Pass']}/${summary['benchmarkCount']}`\n'
      '- Acceptable in top 5: `${summary['acceptableInTop5']}/${summary['benchmarkCount']}`\n'
      '- Routing/global agreement: `${summary['routingAgreement']}/${summary['benchmarkCount']}`\n'
      '- Decision: `${summary['candidateDecision']}`\n';
}

String _csv(Object? value) {
  final text = value?.toString() ?? '';
  return '"${text.replaceAll('"', '""')}"';
}

class _Scored {
  const _Scored({
    required this.score,
    required this.record,
    required this.matchedLabel,
    required this.matchedPrimary,
    required this.matchKind,
    required this.penalties,
  });

  final int score;
  final Map<String, Object?> record;
  final String matchedLabel;
  final bool matchedPrimary;
  final String matchKind;
  final List<String> penalties;

  Map<String, Object?> toJson() => <String, Object?>{
    'score': score,
    'matchedLabel': matchedLabel,
    'matchedPrimary': matchedPrimary,
    'matchKind': matchKind,
    'penalties': penalties,
    ...record,
  };
}

class _BenchmarkQuery {
  const _BenchmarkQuery(this.query, this.canonical, this.required);

  final String query;
  final String canonical;
  final List<String> required;

  bool accept(_Scored result) {
    final primary = normalize(result.record['n']?.toString() ?? '');
    final matched = normalize(result.matchedLabel);
    final primaryTokens = tokens(primary).map(singularToken).toSet();
    final matchedTokens = tokens(matched).map(singularToken).toSet();
    final requiredTokens = required
        .map((token) => singularToken(normalize(token)))
        .toSet();

    final primaryContainsConcept = requiredTokens.every(primaryTokens.contains);
    final aliasContainsConcept = requiredTokens.every(matchedTokens.contains);

    if (!primaryContainsConcept && !aliasContainsConcept) return false;

    if (!primaryContainsConcept && aliasContainsConcept) {
      final overlap = primaryTokens.intersection(requiredTokens).length;
      if (overlap == 0) return false;
    }

    final canonicalTokens = tokens(
      normalize(canonical),
    ).map(singularToken).toSet();
    final extras = primaryTokens.where(
      (token) => !canonicalTokens.contains(token),
    );

    for (final extra in extras) {
      if (neutralDescriptors.contains(extra)) continue;
      return false;
    }

    if (primary.contains(' by ') && !normalize(canonical).contains(' by ')) {
      return false;
    }

    if (primary.contains(' with ') &&
        !normalize(canonical).contains(' with ')) {
      return false;
    }

    return true;
  }
}

const Set<String> neutralDescriptors = <String>{
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
};

const Set<String> hardModifiers = <String>{
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
  'rind',
  'snout',
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
  'enchilada',
  'noodle',
  'substitute',
  'puff',
  'sausage',
  'vegetable',
  'broccoli',
  'liverwurst',
  'bologna',
  'pastrami',
  'pepperoni',
  'nigiri',
  'tataki',
  'sashimi',
  'stick',
  'yolk',
  'white',
  'milk',
  'cereal',
  'square',
  'primavera',
  'fagioli',
};

const Set<String> relationTokens = <String>{
  'with',
  'and',
  'by',
  'e',
  'con',
  'de',
  'del',
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
  _BenchmarkQuery('albume', 'egg white', <String>['egg', 'white']),
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
  _BenchmarkQuery('cioccolato fondente', 'dark chocolate', <String>[
    'dark',
    'chocolate',
  ]),
  _BenchmarkQuery('miele', 'honey', <String>['honey']),
  _BenchmarkQuery('zucchero', 'sugar', <String>['sugar']),
  _BenchmarkQuery('pizza margherita', 'margherita pizza', <String>[
    'margherita',
    'pizza',
  ]),
];
