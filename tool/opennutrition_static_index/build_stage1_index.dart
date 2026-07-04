import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

const int schemaVersion = 1;
const int maxNameLength = 240;
const int maxAliasCount = 8;
const int maxAliasLength = 160;
const int targetCompressedShardBytes = 1024 * 1024;

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final tsvPath = options['tsv'];
  final outPath = options['out'];
  final datasetVersion = options['dataset-version'] ?? '2025.1';
  if (tsvPath == null || outPath == null) {
    stderr.writeln(
      'Usage: dart run build_experimental_index.dart --tsv <file> --out <dir> --dataset-version <version>',
    );
    exitCode = 64;
    return;
  }

  final tsv = File(tsvPath);
  if (!await tsv.exists()) {
    stderr.writeln('TSV non trovato: $tsvPath');
    exitCode = 66;
    return;
  }

  final out = Directory(outPath);
  if (await out.exists()) await out.delete(recursive: true);
  await out.create(recursive: true);
  final buckets = Directory('${out.path}${Platform.pathSeparator}_buckets');
  final shardsDir = Directory('${out.path}${Platform.pathSeparator}shards');
  final reportsDir = Directory('${out.path}${Platform.pathSeparator}reports');
  await buckets.create(recursive: true);
  await shardsDir.create(recursive: true);
  await reportsDir.create(recursive: true);

  final audit = _Audit(
    datasetVersion: datasetVersion,
    tsvBytes: await tsv.length(),
  );
  final parser = _TsvParser();
  final bucketSinks = <String, IOSink>{};
  final bucketFiles = <String, File>{};
  var headerRead = false;

  try {
    final records = const _TsvRecordDecoder().bind(
      tsv.openRead().transform(utf8.decoder),
    );
    await for (final row in records) {
      if (!headerRead) {
        parser.readHeader(row);
        audit.headers = parser.headers;
        headerRead = true;
        continue;
      }
      audit.totalRows++;
      final parsed = parser.parse(row, audit);
      if (parsed == null) continue;
      if (parsed.fromOpenFoodFacts) {
        audit.openFoodFactsRowsExcluded++;
        continue;
      }
      audit.indexCandidateRows++;
      final bucket = _bucketKey(parsed.normalizedName);
      final file = bucketFiles.putIfAbsent(
        bucket,
        () => File('${buckets.path}${Platform.pathSeparator}$bucket.jsonl'),
      );
      final sink = bucketSinks.putIfAbsent(
        bucket,
        () => file.openWrite(mode: FileMode.append),
      );
      sink.writeln(jsonEncode(parsed.toJson()));
      if (audit.sampleCandidates.length < 100)
        audit.sampleCandidates.add(parsed.toPublicJson());
      if (audit.totalRows % 25000 == 0) {
        stdout.writeln(
          'PARSED_ROWS=${audit.totalRows} CANDIDATES=${audit.indexCandidateRows}',
        );
      }
    }
  } finally {
    for (final sink in bucketSinks.values) {
      await sink.flush();
      await sink.close();
    }
  }

  if (!headerRead) throw StateError('Il TSV non contiene intestazioni.');

  final manifestShards = <Map<String, Object?>>[];
  final allShardFiles = <File>[];
  final sortedBuckets = bucketFiles.keys.toList()..sort();

  for (final bucket in sortedBuckets) {
    final file = bucketFiles[bucket]!;
    final groups = <String, Map<String, _MinimalRecord>>{};
    await for (final line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final record = _MinimalRecord.fromJson(
        jsonDecode(line) as Map<String, Object?>,
      );
      final shardPrefix = _prefix(record.normalizedName, 2);
      final map = groups.putIfAbsent(
        shardPrefix,
        () => <String, _MinimalRecord>{},
      );
      final key = record.dedupeKey;
      final previous = map[key];
      if (previous == null) {
        map[key] = record;
      } else {
        audit.duplicatesRemoved++;
        if (record.qualityScore > previous.qualityScore ||
            (record.qualityScore == previous.qualityScore &&
                record.id.compareTo(previous.id) < 0)) {
          map[key] = record;
        }
      }
    }

    final prefixes = groups.keys.toList()..sort();
    for (final prefix in prefixes) {
      final records = groups[prefix]!.values.toList()
        ..sort((a, b) {
          final byName = a.normalizedName.compareTo(b.normalizedName);
          if (byName != 0) return byName;
          final byQuality = b.qualityScore.compareTo(a.qualityScore);
          if (byQuality != 0) return byQuality;
          return a.id.compareTo(b.id);
        });
      await _writeAdaptiveShards(
        prefix: prefix,
        records: records,
        depth: 2,
        datasetVersion: datasetVersion,
        shardsDir: shardsDir,
        manifestShards: manifestShards,
        allShardFiles: allShardFiles,
      );
    }
    await file.delete();
  }

  manifestShards.sort(
    (a, b) => (a['prefix'] as String).compareTo(b['prefix'] as String),
  );
  audit.indexedRows = manifestShards.fold<int>(
    0,
    (sum, item) => sum + (item['recordCount'] as int),
  );
  audit.shardCount = manifestShards.length;
  audit.totalCompressedBytes = manifestShards.fold<int>(
    0,
    (sum, item) => sum + (item['compressedBytes'] as int),
  );
  audit.maxCompressedShardBytes = manifestShards.fold<int>(
    0,
    (maxValue, item) => math.max(maxValue, item['compressedBytes'] as int),
  );
  audit.minCompressedShardBytes = manifestShards.isEmpty
      ? 0
      : manifestShards.fold<int>(
          1 << 62,
          (minValue, item) =>
              math.min(minValue, item['compressedBytes'] as int),
        );

  final manifest = <String, Object?>{
    'schemaVersion': schemaVersion,
    'datasetVersion': datasetVersion,
    'generatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'source': <String, Object?>{
      'name': 'OpenNutrition',
      'url': 'https://www.opennutrition.app',
      'datasetUrl':
          'https://downloads.opennutrition.app/opennutrition-dataset-2025.1.zip',
      'license': 'ODbL-1.0 / modified DbCL-1.0',
      'attribution': 'OpenNutrition',
    },
    'policy': <String, Object?>{
      'openFoodFactsDerivedRecordsExcluded': true,
      'maxCompressedShardBytesTarget': targetCompressedShardBytes,
      'routing':
          'Choose the longest shard prefix matching the normalized query; for shorter queries fetch all prefixes beginning with the query.',
    },
    'recordCount': audit.indexedRows,
    'shardCount': audit.shardCount,
    'shards': manifestShards,
  };

  final manifestFile = File(
    '${out.path}${Platform.pathSeparator}manifest.json',
  );
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifest),
    flush: true,
  );

  final benchmark = await _runBenchmark(allShardFiles, audit);
  await File(
    '${reportsDir.path}${Platform.pathSeparator}benchmark.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(benchmark),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}benchmark.csv',
  ).writeAsString(_benchmarkCsv(benchmark), flush: true);

  final auditJson = audit.toJson();
  await File(
    '${reportsDir.path}${Platform.pathSeparator}dataset_audit.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(auditJson),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}sample_records.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(audit.sampleCandidates),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}sample_shard.json',
  ).writeAsString(
    const JsonEncoder.withIndent(
      '  ',
    ).convert(await _sampleShard(allShardFiles)),
    flush: true,
  );
  await File(
    '${reportsDir.path}${Platform.pathSeparator}summary.md',
  ).writeAsString(_summaryMarkdown(audit, benchmark), flush: true);
  await File('${out.path}${Platform.pathSeparator}README.md').writeAsString(
    '# Total Tracker OpenNutrition experimental static index\n\n'
    'Derived from the OpenNutrition dataset. Licensed under ODbL 1.0; contents under the modified DbCL terms distributed with the source dataset.\n\n'
    'Attribution: [OpenNutrition](https://www.opennutrition.app). Records identified as derived from Open Food Facts were excluded from this experimental index.\n',
    flush: true,
  );

  await buckets.delete(recursive: true);
  stdout.writeln('INDEX_BUILD_OK');
  stdout.writeln('RECORDS=${audit.indexedRows}');
  stdout.writeln('SHARDS=${audit.shardCount}');
  stdout.writeln('COMPRESSED_BYTES=${audit.totalCompressedBytes}');
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) continue;
    final key = arg.substring(2);
    if (i + 1 >= args.length) throw FormatException('Valore mancante per $arg');
    result[key] = args[++i];
  }
  return result;
}

class _TsvRecordDecoder extends StreamTransformerBase<String, List<String>> {
  const _TsvRecordDecoder();
  @override
  Stream<List<String>> bind(Stream<String> stream) async* {
    final row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    var quotePending = false;
    var firstCharacter = true;
    var skipLfAfterCr = false;
    await for (final chunk in stream) {
      for (var index = 0; index < chunk.length; index++) {
        final char = chunk[index];
        if (firstCharacter) {
          firstCharacter = false;
          if (char == '\uFEFF') continue;
        }
        if (skipLfAfterCr) {
          skipLfAfterCr = false;
          if (char == '\n') continue;
        }
        if (quotePending) {
          quotePending = false;
          if (char == '"') {
            field.write('"');
            continue;
          }
          inQuotes = false;
        }
        if (inQuotes) {
          if (char == '"') {
            quotePending = true;
          } else {
            field.write(char);
          }
          continue;
        }
        if (char == '"' && field.isEmpty) {
          inQuotes = true;
        } else if (char == '\t') {
          row.add(field.toString());
          field.clear();
        } else if (char == '\r' || char == '\n') {
          row.add(field.toString());
          field.clear();
          yield List<String>.unmodifiable(row);
          row.clear();
          if (char == '\r') skipLfAfterCr = true;
        } else {
          field.write(char);
        }
      }
    }
    if (quotePending) inQuotes = false;
    if (inQuotes)
      throw const FormatException('Campo TSV quotato non terminato.');
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      yield List<String>.unmodifiable(row);
    }
  }
}

class _TsvParser {
  late List<String> headers;
  late Map<String, int> index;

  void readHeader(List<String> values) {
    headers = values
        .map((v) => v.replaceFirst('\uFEFF', '').trim())
        .toList(growable: false);
    index = <String, int>{
      for (var i = 0; i < headers.length; i++) _normalizeKey(headers[i]): i,
    };
    if (!index.containsKey('id') || !index.containsKey('name')) {
      throw StateError(
        'Schema inatteso. Colonne richieste: id, name. Trovate: $headers',
      );
    }
  }

  _MinimalRecord? parse(List<String> fields, _Audit audit) {
    if (fields.every((value) => value.trim().isEmpty)) {
      audit.skippedEmptyRows++;
      return null;
    }
    final id = value(fields, 'id');
    final rawName = value(fields, 'name');
    final aliases = decodeStringList(value(fields, 'alternate_names'));
    final name = safeName(rawName).isNotEmpty
        ? safeName(rawName)
        : aliases
              .map(safeName)
              .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (id.isEmpty) {
      audit.skippedMissingId++;
      return null;
    }
    if (name.isEmpty) {
      audit.skippedMissingName++;
      return null;
    }
    final normalizedName = normalizeSearch(name);
    if (normalizedName.isEmpty) {
      audit.skippedUnsearchableName++;
      return null;
    }

    final nutritionRaw = value(fields, 'nutrition_100g');
    final nutrition = decodeJsonMap(nutritionRaw);
    final kcal = nutrient(fields, nutrition, const [
      'energy',
      'energy_kcal',
      'energy-kcal',
      'calories',
      'kcal',
    ], energy: true);
    final protein = nutrient(fields, nutrition, const ['protein', 'proteins']);
    final carbs = nutrient(fields, nutrition, const [
      'carbohydrate',
      'carbohydrates',
      'carbs',
    ]);
    final fat = nutrient(fields, nutrition, const ['fat', 'total_fat']);
    final fiber = nutrient(fields, nutrition, const [
      'fiber',
      'fibre',
      'dietary_fiber',
    ]);
    final sugar = nutrient(fields, nutrition, const ['sugar', 'sugars']);
    final salt = nutrient(fields, nutrition, const ['salt']);

    final cleanKcal = validRange(kcal, 0, 2000);
    final cleanProtein = validRange(protein, 0, 100);
    final cleanCarbs = validRange(carbs, 0, 100);
    final cleanFat = validRange(fat, 0, 100);
    final cleanFiber = validRange(fiber, 0, 100);
    final cleanSugar = validRange(sugar, 0, 100);
    final cleanSalt = validRange(salt, 0, 100);

    if ([
      kcal,
      protein,
      carbs,
      fat,
      fiber,
      sugar,
      salt,
    ].any((v) => v != null && !v.isFinite)) {
      audit.nonFiniteNutrientRows++;
    }
    if (cleanKcal == null &&
        cleanProtein == null &&
        cleanCarbs == null &&
        cleanFat == null) {
      audit.skippedNoCoreNutrition++;
      return null;
    }

    final sourceRaw = value(fields, 'source');
    final sourceLower = sourceRaw.toLowerCase();
    final fromOff =
        sourceLower.contains('open food facts') ||
        sourceLower.contains('openfoodfacts') ||
        sourceLower.contains('world.openfoodfacts.org');
    final estimated =
        sourceLower.contains('estimated') ||
        sourceLower.contains('derived') ||
        nutritionRaw.toLowerCase().contains('estimated');
    final type = safeScalar(value(fields, 'type'), 48);
    audit.typeCounts[type.isEmpty ? '(empty)' : type] =
        (audit.typeCounts[type.isEmpty ? '(empty)' : type] ?? 0) + 1;
    for (final source in sourceLabels(sourceRaw)) {
      audit.sourceCounts[source] = (audit.sourceCounts[source] ?? 0) + 1;
    }

    final filteredAliases = <String>[];
    final seenAliases = <String>{normalizedName};
    for (final alias in aliases) {
      final clean = safeName(alias);
      final normalized = normalizeSearch(clean);
      if (clean.isEmpty ||
          normalized.isEmpty ||
          seenAliases.contains(normalized))
        continue;
      seenAliases.add(normalized);
      filteredAliases.add(
        clean.length <= maxAliasLength
            ? clean
            : clean.substring(0, maxAliasLength),
      );
      if (filteredAliases.length >= maxAliasCount) break;
    }

    final image = validUrl(
      firstNonEmpty([
        value(fields, 'image_url'),
        value(fields, 'image_front_url'),
        value(fields, 'image'),
        findStringByKeys(decodeJson(sourceRaw), const [
          'image_url',
          'image_front_url',
          'image',
        ]),
      ]),
    );

    final qualityFlags = <String>[];
    if (cleanKcal == null) qualityFlags.add('missing_kcal');
    if (cleanProtein == null || cleanCarbs == null || cleanFat == null)
      qualityFlags.add('incomplete_macros');
    if (estimated) qualityFlags.add('estimated_or_derived');
    if (image.isEmpty) qualityFlags.add('missing_image');

    final qualityScore =
        (cleanKcal != null ? 4 : 0) +
        (cleanProtein != null ? 2 : 0) +
        (cleanCarbs != null ? 2 : 0) +
        (cleanFat != null ? 2 : 0) +
        (cleanFiber != null ? 1 : 0) +
        (cleanSugar != null ? 1 : 0) +
        (cleanSalt != null ? 1 : 0) +
        (filteredAliases.isNotEmpty ? 1 : 0) +
        (image.isNotEmpty ? 1 : 0) -
        (estimated ? 2 : 0);

    return _MinimalRecord(
      id: id,
      name: name,
      normalizedName: normalizedName,
      aliases: filteredAliases,
      type: type,
      kcal: cleanKcal,
      protein: cleanProtein,
      carbs: cleanCarbs,
      fat: cleanFat,
      fiber: cleanFiber,
      sugar: cleanSugar,
      salt: cleanSalt,
      imageUrl: image,
      qualityFlags: qualityFlags,
      qualityScore: qualityScore,
      fromOpenFoodFacts: fromOff,
    );
  }

  String value(List<String> fields, String key) {
    final position = index[_normalizeKey(key)];
    if (position == null || position >= fields.length) return '';
    return fields[position].trim();
  }

  double? nutrient(
    List<String> fields,
    Map<String, Object?> nutrition,
    List<String> aliases, {
    bool energy = false,
  }) {
    for (final alias in aliases) {
      for (final variant in [
        alias,
        '${alias}_100g',
        alias.replaceAll('_', '-'),
        '${alias.replaceAll('_', '-')}_100g',
      ]) {
        final parsed = numberWithUnit(value(fields, variant));
        if (parsed.$1 != null)
          return energy ? energyToKcal(parsed.$1!, parsed.$2) : parsed.$1;
      }
    }
    final match = findNutrient(nutrition, aliases);
    if (match.$1 == null) return null;
    return energy ? energyToKcal(match.$1!, match.$2) : match.$1;
  }
}

class _MinimalRecord {
  const _MinimalRecord({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.aliases,
    required this.type,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.salt,
    required this.imageUrl,
    required this.qualityFlags,
    required this.qualityScore,
    required this.fromOpenFoodFacts,
  });

  final String id;
  final String name;
  final String normalizedName;
  final List<String> aliases;
  final String type;
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? salt;
  final String imageUrl;
  final List<String> qualityFlags;
  final int qualityScore;
  final bool fromOpenFoodFacts;

  String get dedupeKey =>
      '$normalizedName|${_signature(kcal, 1)}|${_signature(protein, 10)}|${_signature(carbs, 10)}|${_signature(fat, 10)}';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'normalizedName': normalizedName,
    'aliases': aliases,
    'type': type,
    'kcal': kcal,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'fiber': fiber,
    'sugar': sugar,
    'salt': salt,
    'imageUrl': imageUrl,
    'qualityFlags': qualityFlags,
    'qualityScore': qualityScore,
    'fromOpenFoodFacts': fromOpenFoodFacts,
  };

  Map<String, Object?> toPublicJson() => <String, Object?>{
    'id': id,
    'n': name,
    if (aliases.isNotEmpty) 'a': aliases,
    if (type.isNotEmpty) 't': type,
    'v': <String, Object?>{
      if (kcal != null) 'k': roundValue(kcal!, 2),
      if (protein != null) 'p': roundValue(protein!, 2),
      if (carbs != null) 'c': roundValue(carbs!, 2),
      if (fat != null) 'f': roundValue(fat!, 2),
      if (fiber != null) 'fi': roundValue(fiber!, 2),
      if (sugar != null) 'su': roundValue(sugar!, 2),
      if (salt != null) 'sa': roundValue(salt!, 3),
    },
    if (imageUrl.isNotEmpty) 'im': imageUrl,
    if (qualityFlags.isNotEmpty) 'q': qualityFlags,
  };

  factory _MinimalRecord.fromJson(Map<String, Object?> json) => _MinimalRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    normalizedName: json['normalizedName'] as String,
    aliases: (json['aliases'] as List).cast<String>(),
    type: json['type'] as String,
    kcal: (json['kcal'] as num?)?.toDouble(),
    protein: (json['protein'] as num?)?.toDouble(),
    carbs: (json['carbs'] as num?)?.toDouble(),
    fat: (json['fat'] as num?)?.toDouble(),
    fiber: (json['fiber'] as num?)?.toDouble(),
    sugar: (json['sugar'] as num?)?.toDouble(),
    salt: (json['salt'] as num?)?.toDouble(),
    imageUrl: json['imageUrl'] as String,
    qualityFlags: (json['qualityFlags'] as List).cast<String>(),
    qualityScore: json['qualityScore'] as int,
    fromOpenFoodFacts: json['fromOpenFoodFacts'] as bool,
  );
}

class _Audit {
  _Audit({required this.datasetVersion, required this.tsvBytes});
  final String datasetVersion;
  final int tsvBytes;
  List<String> headers = const [];
  int totalRows = 0;
  int skippedEmptyRows = 0;
  int skippedMissingId = 0;
  int skippedMissingName = 0;
  int skippedUnsearchableName = 0;
  int skippedNoCoreNutrition = 0;
  int nonFiniteNutrientRows = 0;
  int openFoodFactsRowsExcluded = 0;
  int indexCandidateRows = 0;
  int duplicatesRemoved = 0;
  int indexedRows = 0;
  int shardCount = 0;
  int totalCompressedBytes = 0;
  int minCompressedShardBytes = 0;
  int maxCompressedShardBytes = 0;
  final Map<String, int> typeCounts = {};
  final Map<String, int> sourceCounts = {};
  final List<Map<String, Object?>> sampleCandidates = [];

  Map<String, Object?> toJson() => <String, Object?>{
    'datasetVersion': datasetVersion,
    'tsvBytes': tsvBytes,
    'headers': headers,
    'rows': <String, Object?>{
      'total': totalRows,
      'empty': skippedEmptyRows,
      'missingId': skippedMissingId,
      'missingName': skippedMissingName,
      'unsearchableName': skippedUnsearchableName,
      'noCoreNutrition': skippedNoCoreNutrition,
      'nonFiniteNutrients': nonFiniteNutrientRows,
      'openFoodFactsExcluded': openFoodFactsRowsExcluded,
      'candidatesBeforeDeduplication': indexCandidateRows,
      'duplicatesRemoved': duplicatesRemoved,
      'indexed': indexedRows,
    },
    'shards': <String, Object?>{
      'count': shardCount,
      'totalCompressedBytes': totalCompressedBytes,
      'minCompressedBytes': minCompressedShardBytes,
      'maxCompressedBytes': maxCompressedShardBytes,
      'targetMaxCompressedBytes': targetCompressedShardBytes,
    },
    'typeCounts': sortedCounts(typeCounts),
    'sourceCountsTop100': sortedCounts(sourceCounts).take(100).toList(),
  };
}

Future<void> _writeAdaptiveShards({
  required String prefix,
  required List<_MinimalRecord> records,
  required int depth,
  required String datasetVersion,
  required Directory shardsDir,
  required List<Map<String, Object?>> manifestShards,
  required List<File> allShardFiles,
}) async {
  if (records.isEmpty) return;
  final payload = _encodeShard(prefix, records, datasetVersion);
  final compressed = gzip.encode(payload);
  if (compressed.length > targetCompressedShardBytes &&
      records.length > 300 &&
      depth < 6) {
    final split = <String, List<_MinimalRecord>>{};
    for (final record in records) {
      final child = _prefix(record.normalizedName, depth + 1);
      split.putIfAbsent(child, () => <_MinimalRecord>[]).add(record);
    }
    if (split.length > 1) {
      final keys = split.keys.toList()..sort();
      for (final key in keys) {
        await _writeAdaptiveShards(
          prefix: key,
          records: split[key]!,
          depth: depth + 1,
          datasetVersion: datasetVersion,
          shardsDir: shardsDir,
          manifestShards: manifestShards,
          allShardFiles: allShardFiles,
        );
      }
      return;
    }
  }

  final safePrefix = prefix == 'other' ? 'other' : prefix;
  final file = File(
    '${shardsDir.path}${Platform.pathSeparator}$safePrefix.json.gz',
  );
  await file.writeAsBytes(compressed, flush: true);
  allShardFiles.add(file);
  manifestShards.add(<String, Object?>{
    'prefix': prefix,
    'path': 'shards/$safePrefix.json.gz',
    'recordCount': records.length,
    'uncompressedBytes': payload.length,
    'compressedBytes': compressed.length,
    'sha256': sha256.convert(compressed).toString(),
  });
}

List<int> _encodeShard(
  String prefix,
  List<_MinimalRecord> records,
  String datasetVersion,
) {
  final json = jsonEncode(<String, Object?>{
    'schemaVersion': schemaVersion,
    'datasetVersion': datasetVersion,
    'prefix': prefix,
    'records': records.map((r) => r.toPublicJson()).toList(growable: false),
  });
  return utf8.encode(json);
}

Future<List<Map<String, Object?>>> _runBenchmark(
  List<File> shardFiles,
  _Audit audit,
) async {
  final queries = _benchmarkQueries;
  final tops = <String, List<_ScoredRecord>>{
    for (final q in queries) q.$1: <_ScoredRecord>[],
  };
  for (final file in shardFiles) {
    final decoded = utf8.decode(gzip.decode(await file.readAsBytes()));
    final data = jsonDecode(decoded) as Map<String, Object?>;
    final records = (data['records'] as List).cast<Map<String, Object?>>();
    for (final record in records) {
      final name = record['n'] as String;
      final aliases = ((record['a'] as List?) ?? const []).cast<String>();
      for (final query in queries) {
        final score = _score(query.$2, name, aliases);
        if (score <= 0) continue;
        final list = tops[query.$1]!;
        list.add(_ScoredRecord(score, record));
        list.sort((a, b) => b.score.compareTo(a.score));
        if (list.length > 5) list.removeLast();
      }
    }
  }

  return [
    for (final query in queries)
      <String, Object?>{
        'query': query.$1,
        'canonicalQuery': query.$2,
        'found': tops[query.$1]!.isNotEmpty,
        'topResults': [
          for (final item in tops[query.$1]!)
            <String, Object?>{'score': item.score, ...item.record},
        ],
      },
  ];
}

int _score(String query, String name, List<String> aliases) {
  final q = normalizeSearch(query);
  if (q.isEmpty) return 0;
  final candidates = [name, ...aliases].map(normalizeSearch);
  var best = 0;
  final qTokens = q.split(' ').where((v) => v.isNotEmpty).toList();
  for (final candidate in candidates) {
    if (candidate.isEmpty) continue;
    var score = 0;
    if (candidate == q)
      score = 1000;
    else if (candidate.startsWith('$q '))
      score = 850;
    else if (candidate.contains(q))
      score = 700;
    final allTokens = qTokens.every(
      (token) => candidate
          .split(' ')
          .any((part) => part == token || part.startsWith(token)),
    );
    if (allTokens) score = math.max(score, 500 + qTokens.length * 25);
    if (score > best) best = score;
  }
  return best;
}

Future<Map<String, Object?>> _sampleShard(List<File> files) async {
  if (files.isEmpty) return <String, Object?>{};
  files.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
  final decoded = utf8.decode(gzip.decode(await files.first.readAsBytes()));
  final map = jsonDecode(decoded) as Map<String, Object?>;
  final records = (map['records'] as List).take(30).toList();
  return <String, Object?>{
    'sourceShard': files.first.uri.pathSegments.last,
    'schemaVersion': map['schemaVersion'],
    'datasetVersion': map['datasetVersion'],
    'prefix': map['prefix'],
    'sampleRecords': records,
  };
}

String _benchmarkCsv(List<Map<String, Object?>> rows) {
  final buffer = StringBuffer(
    'query,canonical_query,found,top_name,top_score\n',
  );
  for (final row in rows) {
    final top = (row['topResults'] as List).cast<Map<String, Object?>>();
    buffer.writeln(
      [
        csv(row['query'].toString()),
        csv(row['canonicalQuery'].toString()),
        row['found'],
        csv(top.isEmpty ? '' : top.first['n'].toString()),
        top.isEmpty ? '' : top.first['score'],
      ].join(','),
    );
  }
  return buffer.toString();
}

String _summaryMarkdown(_Audit audit, List<Map<String, Object?>> benchmark) {
  final found = benchmark.where((row) => row['found'] == true).length;
  final mib = audit.totalCompressedBytes / (1024 * 1024);
  return '# OpenNutrition static-index feasibility\n\n'
      '- Dataset version: `${audit.datasetVersion}`\n'
      '- TSV rows: `${audit.totalRows}`\n'
      '- Open Food Facts-derived rows excluded: `${audit.openFoodFactsRowsExcluded}`\n'
      '- Candidates before deduplication: `${audit.indexCandidateRows}`\n'
      '- Duplicates removed: `${audit.duplicatesRemoved}`\n'
      '- Indexed records: `${audit.indexedRows}`\n'
      '- Shards: `${audit.shardCount}`\n'
      '- Total compressed index: `${mib.toStringAsFixed(2)} MiB`\n'
      '- Largest compressed shard: `${audit.maxCompressedShardBytes}` bytes\n'
      '- Benchmark coverage: `$found/${benchmark.length}`\n\n'
      'The build is experimental and remains under `tmp/`; it is not connected to Flutter.\n';
}

List<Map<String, Object>> sortedCounts(Map<String, int> input) {
  final entries = input.entries.toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return [
    for (final entry in entries)
      <String, Object>{'value': entry.key, 'count': entry.value},
  ];
}

String _bucketKey(String normalized) {
  if (normalized.isEmpty) return 'other';
  final c = normalized[0];
  return RegExp(r'[a-z0-9]').hasMatch(c) ? c : 'other';
}

String _prefix(String normalized, int length) {
  final compact = normalized.replaceAll(' ', '');
  if (compact.isEmpty) return 'other';
  if (compact.length >= length) return compact.substring(0, length);
  return compact.padRight(length, '_');
}

String normalizeSearch(String input) {
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

String _normalizeKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

Object? decodeJson(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return <String, Object?>{};
  if (!(clean.startsWith('{') || clean.startsWith('['))) return clean;
  try {
    return jsonDecode(clean);
  } catch (_) {
    return clean;
  }
}

Map<String, Object?> decodeJsonMap(String value) {
  final decoded = decodeJson(value);
  if (decoded is Map)
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  return <String, Object?>{};
}

List<String> decodeStringList(String value) {
  final decoded = decodeJson(value);
  if (decoded is List)
    return decoded.map(scalar).where((v) => v.isNotEmpty).toList();
  final text = scalar(decoded);
  if (text.isEmpty) return const [];
  return text
      .split(RegExp(r'[|;,]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
}

String scalar(Object? value) => value == null || value is Map || value is List
    ? ''
    : value.toString().trim();
String safeScalar(String value, int maxLength) {
  final clean = value.trim();
  if (clean.length <= maxLength) return clean;
  return clean.substring(0, maxLength);
}

String safeName(String value) {
  final clean = value.trim();
  if (clean.isEmpty ||
      clean.length > maxNameLength ||
      clean.startsWith('{') ||
      clean.startsWith('['))
    return '';
  if (clean.contains('nutrition_100g') || clean.contains('ingredient_analysis'))
    return '';
  return clean;
}

(double?, String) findNutrient(Object? value, List<String> aliases) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = _normalizeKey(
        entry.key.toString(),
      ).replaceAll(RegExp(r'_?100g$'), '');
      if (aliases.any(
        (alias) =>
            key == _normalizeKey(alias).replaceAll(RegExp(r'_?100g$'), ''),
      )) {
        final parsed = numberWithUnit(entry.value);
        if (parsed.$1 != null) return parsed;
      }
    }
    for (final nested in value.values) {
      final result = findNutrient(nested, aliases);
      if (result.$1 != null) return result;
    }
  } else if (value is List) {
    for (final nested in value) {
      final result = findNutrient(nested, aliases);
      if (result.$1 != null) return result;
    }
  }
  return (null, '');
}

(double?, String) numberWithUnit(Object? value) {
  if (value is num) return (value.toDouble(), '');
  if (value is Map) {
    final rawValue = value['value'] ?? value['amount'] ?? value['quantity'];
    final unit = (value['unit'] ?? value['units'] ?? '').toString();
    return (asDouble(rawValue), unit);
  }
  if (value is String) {
    final clean = value.trim();
    if (clean.isEmpty) return (null, '');
    final decoded = decodeJson(clean);
    if (decoded is! String) return numberWithUnit(decoded);
    final match = RegExp(
      r'(-?\d+(?:[\.,]\d+)?)\s*([a-zA-Zµμ]*)',
    ).firstMatch(clean);
    if (match == null) return (null, '');
    return (
      double.tryParse(match.group(1)!.replaceAll(',', '.')),
      match.group(2) ?? '',
    );
  }
  return (null, '');
}

double energyToKcal(double value, String unit) {
  final normalized = unit.toLowerCase().replaceAll(' ', '');
  return normalized == 'kj' || normalized == 'kilojoule'
      ? value / 4.184
      : value;
}

double? validRange(double? value, double min, double max) {
  if (value == null || !value.isFinite || value < min || value > max)
    return null;
  return value;
}

double? asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String)
    return double.tryParse(value.trim().replaceAll(',', '.'));
  return null;
}

String findStringByKeys(Object? value, List<String> keys) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (keys
          .map(_normalizeKey)
          .contains(_normalizeKey(entry.key.toString()))) {
        final text = scalar(entry.value);
        if (text.isNotEmpty) return text;
      }
    }
    for (final nested in value.values) {
      final result = findStringByKeys(nested, keys);
      if (result.isNotEmpty) return result;
    }
  } else if (value is List) {
    for (final nested in value) {
      final result = findStringByKeys(nested, keys);
      if (result.isNotEmpty) return result;
    }
  }
  return '';
}

String firstNonEmpty(List<String> values) =>
    values.firstWhere((v) => v.trim().isNotEmpty, orElse: () => '').trim();
String validUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.isScheme('http') || uri.isScheme('https'))
      ? uri.toString()
      : '';
}

Iterable<String> sourceLabels(String sourceRaw) sync* {
  final decoded = decodeJson(sourceRaw);
  if (decoded is List) {
    for (final item in decoded) {
      if (item is Map) {
        final label = firstNonEmpty([
          scalar(item['name']),
          scalar(item['source']),
          scalar(item['database']),
          scalar(item['provider']),
        ]);
        yield label.isEmpty ? '(structured)' : safeScalar(label, 160);
      } else {
        final label = compactSourceLabel(scalar(item));
        if (label.isNotEmpty) yield label;
      }
    }
  } else {
    final label = compactSourceLabel(scalar(decoded));
    if (label.isNotEmpty) yield label;
  }
}

String compactSourceLabel(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return '';
  final uri = Uri.tryParse(clean);
  if (uri != null &&
      (uri.isScheme('http') || uri.isScheme('https')) &&
      uri.host.isNotEmpty) {
    return uri.host.toLowerCase();
  }
  return safeScalar(clean, 160);
}

String _signature(double? value, int multiplier) =>
    value == null ? 'x' : (value * multiplier).round().toString();
double roundValue(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).round() / factor;
}

String csv(String value) => '"${value.replaceAll('"', '""')}"';

class _ScoredRecord {
  const _ScoredRecord(this.score, this.record);
  final int score;
  final Map<String, Object?> record;
}

const List<(String, String)> _benchmarkQueries = [
  ('petto di pollo', 'chicken breast'),
  ('riso basmati', 'basmati rice'),
  ('riso integrale', 'brown rice'),
  ('pasta', 'pasta'),
  ('pane integrale', 'whole wheat bread'),
  ('mela', 'apple'),
  ('banana', 'banana'),
  ('arancia', 'orange'),
  ('fragola', 'strawberry'),
  ('mirtilli', 'blueberries'),
  ('avocado', 'avocado'),
  ('patate', 'potato'),
  ('patata dolce', 'sweet potato'),
  ('pomodoro', 'tomato'),
  ('zucchine', 'zucchini'),
  ('broccoli', 'broccoli'),
  ('spinaci', 'spinach'),
  ('carote', 'carrot'),
  ('lenticchie', 'lentils'),
  ('ceci', 'chickpeas'),
  ('fagioli neri', 'black beans'),
  ('salmone', 'salmon'),
  ('tonno', 'tuna'),
  ('merluzzo', 'cod'),
  ('gamberetti', 'shrimp'),
  ('uovo', 'egg'),
  ('albume', 'egg white'),
  ('latte intero', 'whole milk'),
  ('yogurt greco', 'greek yogurt'),
  ('mozzarella', 'mozzarella'),
  ('parmigiano', 'parmesan'),
  ('fiocchi di latte', 'cottage cheese'),
  ('mandorle', 'almonds'),
  ('noci', 'walnuts'),
  ('burro di arachidi', 'peanut butter'),
  ('olio di oliva', 'olive oil'),
  ('burro', 'butter'),
  ('avena', 'oats'),
  ('quinoa', 'quinoa'),
  ('cous cous', 'couscous'),
  ('manzo macinato', 'ground beef'),
  ('bistecca', 'beef steak'),
  ('maiale', 'pork'),
  ('tacchino', 'turkey'),
  ('prosciutto', 'ham'),
  ('tofu', 'tofu'),
  ('cioccolato fondente', 'dark chocolate'),
  ('miele', 'honey'),
  ('zucchero', 'sugar'),
  ('pizza margherita', 'margherita pizza'),
];
