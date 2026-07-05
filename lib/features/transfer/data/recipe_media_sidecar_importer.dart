import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../nutrition/data/entities/nutrition_tracking_entities.dart';

typedef RecipeMediaProgressCallback = void Function(
  double progress,
  String message,
);

class RecipeMediaImportReport {
  const RecipeMediaImportReport({
    required this.imported,
    required this.unchanged,
    required this.missingRecipes,
    required this.totalMapped,
    required this.bytesWritten,
  });

  final int imported;
  final int unchanged;
  final int missingRecipes;
  final int totalMapped;
  final int bytesWritten;

  String get summary =>
      'Immagini collegate: $imported · già aggiornate: $unchanged · '
      'ricette non trovate: $missingRecipes';
}

class RecipeMediaSidecarImporter {
  RecipeMediaSidecarImporter(this._store);

  static const int _maxArchiveBytes = 64 * 1024 * 1024;
  static const int _maxExpandedBytes = 96 * 1024 * 1024;
  static const int _maxImageBytes = 8 * 1024 * 1024;
  static const int _maxEntries = 5000;

  final Store _store;

  Future<RecipeMediaImportReport> importFile(
    String sourcePath, {
    RecipeMediaProgressCallback? onProgress,
  }) async {
    final File source = File(sourcePath);
    if (!await source.exists()) {
      throw const FormatException('Pacchetto immagini non trovato.');
    }
    final int sourceLength = await source.length();
    if (sourceLength <= 0 || sourceLength > _maxArchiveBytes) {
      throw const FormatException(
          'Dimensione del pacchetto immagini non valida.');
    }

    onProgress?.call(0.03, 'Lettura del pacchetto immagini...');
    final Uint8List archiveBytes = await source.readAsBytes();
    onProgress?.call(0.12, 'Verifica struttura e checksum...');

    final _DecodedMediaSidecar decoded = await Isolate.run(
      () => _decodeAndValidate(archiveBytes),
    );

    final Box<RecipeEntity> recipeBox = _store.box<RecipeEntity>();
    final Map<String, RecipeEntity> recipesByUuid = <String, RecipeEntity>{
      for (final RecipeEntity recipe in recipeBox.getAll())
        if (recipe.deletedAtEpochMs == null) recipe.uuid: recipe,
    };

    final Directory supportDirectory = await getApplicationSupportDirectory();
    final Directory destinationDirectory = Directory(
      p.join(supportDirectory.path, 'media', 'recipes'),
    );
    final Directory stagingDirectory = Directory(
      p.join(
        supportDirectory.path,
        'media',
        'recipe-import-staging',
        DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    await destinationDirectory.create(recursive: true);
    await stagingDirectory.create(recursive: true);

    final List<_PreparedMediaWrite> preparedWrites = <_PreparedMediaWrite>[];
    final List<RecipeEntity> recipesToUpdate = <RecipeEntity>[];
    int imported = 0;
    int unchanged = 0;
    int missingRecipes = 0;
    int bytesWritten = 0;

    try {
      for (int index = 0; index < decoded.mappings.length; index += 1) {
        final _RecipeMediaMapping mapping = decoded.mappings[index];
        final RecipeEntity? recipe = recipesByUuid[mapping.recipeUuid];
        if (recipe == null) {
          missingRecipes += 1;
          continue;
        }

        final Uint8List imageBytes = decoded.files[mapping.mediaPath]!;
        final String destinationPath = p.join(
          destinationDirectory.path,
          '${mapping.recipeUuid}.webp',
        );
        final File destination = File(destinationPath);
        final bool sameFile = await _matchesSha256(
          destination,
          mapping.mediaSha256,
        );

        if (sameFile && recipe.imagePath == destinationPath) {
          unchanged += 1;
        } else {
          if (!sameFile) {
            final File staged = File(
              p.join(stagingDirectory.path, '${mapping.recipeUuid}.webp'),
            );
            await staged.writeAsBytes(imageBytes, flush: true);
            if (sha256.convert(await staged.readAsBytes()).toString() !=
                mapping.mediaSha256) {
              throw StateError(
                'Verifica scrittura non riuscita per ${mapping.recipeUuid}.',
              );
            }
            preparedWrites.add(
              _PreparedMediaWrite(
                staged: staged,
                destination: destination,
              ),
            );
            bytesWritten += imageBytes.length;
          }
          recipe.imagePath = destinationPath;
          recipe.updatedAtEpochMs = DateTime.now().millisecondsSinceEpoch;
          recipesToUpdate.add(recipe);
          imported += 1;
        }

        if (index % 3 == 0 || index + 1 == decoded.mappings.length) {
          final double fraction = decoded.mappings.isEmpty
              ? 1
              : (index + 1) / decoded.mappings.length;
          onProgress?.call(
            0.18 + (fraction * 0.58),
            'Preparo immagine ${index + 1} di ${decoded.mappings.length}...',
          );
          await Future<void>.delayed(Duration.zero);
        }
      }

      onProgress?.call(0.8, 'Applico i file nello storage privato...');
      final List<_AppliedMediaWrite> applied = <_AppliedMediaWrite>[];
      try {
        for (final _PreparedMediaWrite write in preparedWrites) {
          File? backup;
          if (await write.destination.exists()) {
            backup = File('${write.destination.path}.backup');
            if (await backup.exists()) {
              await backup.delete();
            }
            await write.destination.rename(backup.path);
          }
          await write.staged.rename(write.destination.path);
          applied.add(
            _AppliedMediaWrite(destination: write.destination, backup: backup),
          );
        }

        onProgress?.call(0.92, 'Aggiorno le ricette in una transazione...');
        _store.runInTransaction(TxMode.write, () {
          if (recipesToUpdate.isNotEmpty) {
            recipeBox.putMany(recipesToUpdate);
          }
        });

        for (final _AppliedMediaWrite write in applied) {
          final File? backup = write.backup;
          if (backup != null && await backup.exists()) {
            await backup.delete();
          }
        }
      } catch (_) {
        for (final _AppliedMediaWrite write in applied.reversed) {
          if (await write.destination.exists()) {
            await write.destination.delete();
          }
          final File? backup = write.backup;
          if (backup != null && await backup.exists()) {
            await backup.rename(write.destination.path);
          }
        }
        rethrow;
      }
    } finally {
      if (await stagingDirectory.exists()) {
        await stagingDirectory.delete(recursive: true);
      }
    }

    onProgress?.call(1, 'Importazione immagini completata.');
    return RecipeMediaImportReport(
      imported: imported,
      unchanged: unchanged,
      missingRecipes: missingRecipes,
      totalMapped: decoded.mappings.length,
      bytesWritten: bytesWritten,
    );
  }

  static Future<bool> _matchesSha256(File file, String expected) async {
    if (!await file.exists()) return false;
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  static _DecodedMediaSidecar _decodeAndValidate(Uint8List bytes) {
    final Archive archive = ZipDecoder().decodeBytes(bytes, verify: true);
    if (archive.length < 3 || archive.length > _maxEntries) {
      throw const FormatException('Numero di file ZIP non valido.');
    }

    final Map<String, Uint8List> files = <String, Uint8List>{};
    int expandedBytes = 0;
    for (final ArchiveFile file in archive) {
      final String name = file.name.replaceAll('\\', '/');
      _validateEntryName(name);
      if (!file.isFile) {
        throw FormatException('Directory o link ZIP non consentito: $name');
      }
      if (files.containsKey(name)) {
        throw FormatException('Entry duplicata nel pacchetto: $name');
      }
      final List<int> content = file.content as List<int>;
      final Uint8List data = Uint8List.fromList(content);
      expandedBytes += data.length;
      if (expandedBytes > _maxExpandedBytes) {
        throw const FormatException('Pacchetto espanso troppo grande.');
      }
      if (name.startsWith('images/') && data.length > _maxImageBytes) {
        throw FormatException('Immagine troppo grande: $name');
      }
      files[name] = data;
    }

    for (final String required in <String>[
      'manifest.json',
      'recipe_media_map.json',
      'checksums.json',
    ]) {
      if (!files.containsKey(required)) {
        throw FormatException('File obbligatorio mancante: $required');
      }
    }

    final Map<String, dynamic> manifest = _jsonMap(files['manifest.json']!);
    if (manifest['format'] != 'total-tracker-recipe-media-sidecar' ||
        manifest['formatVersion'] != 1) {
      throw const FormatException('Formato sidecar immagini non supportato.');
    }
    if (manifest['mappingFile'] != 'recipe_media_map.json') {
      throw const FormatException('Mapping immagini non riconosciuto.');
    }

    final Map<String, dynamic> checksumMap = _jsonMap(files['checksums.json']!);
    if (checksumMap['algorithm'] != 'sha256') {
      throw const FormatException('Algoritmo checksum non supportato.');
    }
    final Set<String> expectedChecksumFiles =
        files.keys.where((String name) => name != 'checksums.json').toSet();
    final Set<String> declaredChecksumFiles =
        checksumMap.keys.where((String name) => name != 'algorithm').toSet();
    if (declaredChecksumFiles.length != expectedChecksumFiles.length ||
        !declaredChecksumFiles.containsAll(expectedChecksumFiles)) {
      throw const FormatException(
        'La copertura dei checksum non coincide con il contenuto del pacchetto.',
      );
    }
    for (final String name in expectedChecksumFiles) {
      final Object? expected = checksumMap[name];
      final Uint8List fileBytes = files[name]!;
      if (expected is! String || !_isSha256(expected.toLowerCase())) {
        throw FormatException('Checksum non valido o mancante: $name');
      }
      final String actual = sha256.convert(fileBytes).toString();
      if (actual != expected.toLowerCase()) {
        throw FormatException('Checksum non valido: $name');
      }
    }

    final Map<String, dynamic> mappingJson =
        _jsonMap(files['recipe_media_map.json']!);
    final Object? rawRecipes = mappingJson['recipes'];
    if (rawRecipes is! List<dynamic>) {
      throw const FormatException('Elenco ricette immagini non valido.');
    }

    final List<_RecipeMediaMapping> mappings = <_RecipeMediaMapping>[];
    final Set<String> seenRecipeUuids = <String>{};
    for (final Object? rawItem in rawRecipes) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('Mapping ricetta non valido.');
      }
      final String recipeUuid = (rawItem['recipeUuid'] as String? ?? '').trim();
      final String mediaPath = (rawItem['mediaPath'] as String? ?? '').trim();
      final String mediaSha256 =
          (rawItem['mediaSha256'] as String? ?? '').trim().toLowerCase();
      final String mimeType = (rawItem['mimeType'] as String? ?? '').trim();
      if (!_isUuid(recipeUuid) ||
          !seenRecipeUuids.add(recipeUuid) ||
          mediaPath != 'images/$recipeUuid.webp' ||
          mimeType != 'image/webp' ||
          !_isSha256(mediaSha256)) {
        throw FormatException('Mapping immagine non valido per $recipeUuid.');
      }
      final Uint8List? image = files[mediaPath];
      if (image == null || !_isWebp(image)) {
        throw FormatException('File WebP non valido: $mediaPath');
      }
      if (sha256.convert(image).toString() != mediaSha256) {
        throw FormatException('Hash immagine non valido: $mediaPath');
      }
      mappings.add(
        _RecipeMediaMapping(
          recipeUuid: recipeUuid,
          mediaPath: mediaPath,
          mediaSha256: mediaSha256,
        ),
      );
    }

    final Object? expectedCount = manifest['imageCount'];
    final Set<String> mappedImagePaths =
        mappings.map((_RecipeMediaMapping item) => item.mediaPath).toSet();
    final Set<String> archivedImagePaths =
        files.keys.where((String name) => name.startsWith('images/')).toSet();
    if (expectedCount is! int ||
        expectedCount != mappings.length ||
        mappedImagePaths.length != mappings.length ||
        archivedImagePaths.length != mappings.length ||
        !mappedImagePaths.containsAll(archivedImagePaths)) {
      throw const FormatException('Conteggio o mapping immagini non coerente.');
    }

    return _DecodedMediaSidecar(
      mappings: mappings,
      files: files,
    );
  }

  static Map<String, dynamic> _jsonMap(Uint8List bytes) {
    final Object? decoded =
        jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON atteso come oggetto.');
    }
    return decoded;
  }

  static void _validateEntryName(String name) {
    if (name.isEmpty ||
        name.startsWith('/') ||
        name.contains('..') ||
        name.contains(':') ||
        name.contains('\\')) {
      throw FormatException('Percorso ZIP non sicuro: $name');
    }
    if (name != 'manifest.json' &&
        name != 'recipe_media_map.json' &&
        name != 'checksums.json' &&
        !RegExp(r'^images/[0-9a-f-]{36}\.webp$').hasMatch(name)) {
      throw FormatException('Entry ZIP non consentita: $name');
    }
  }

  static bool _isUuid(String value) => RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(value.toLowerCase());

  static bool _isSha256(String value) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  static bool _isWebp(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return ascii.decode(bytes.sublist(0, 4)) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12)) == 'WEBP';
  }
}

class _DecodedMediaSidecar {
  const _DecodedMediaSidecar({
    required this.mappings,
    required this.files,
  });

  final List<_RecipeMediaMapping> mappings;
  final Map<String, Uint8List> files;
}

class _RecipeMediaMapping {
  const _RecipeMediaMapping({
    required this.recipeUuid,
    required this.mediaPath,
    required this.mediaSha256,
  });

  final String recipeUuid;
  final String mediaPath;
  final String mediaSha256;
}

class _PreparedMediaWrite {
  const _PreparedMediaWrite({
    required this.staged,
    required this.destination,
  });

  final File staged;
  final File destination;
}

class _AppliedMediaWrite {
  const _AppliedMediaWrite({
    required this.destination,
    required this.backup,
  });

  final File destination;
  final File? backup;
}
