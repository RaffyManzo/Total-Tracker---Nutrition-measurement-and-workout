import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../entities/open_nutrition_catalog_state_entity.dart';
import '../entities/open_nutrition_food_entity.dart';
import '../repositories/open_nutrition_catalog_repository.dart';
import 'open_nutrition_tsv_parser.dart';

class OpenNutritionDatasetConstants {
  const OpenNutritionDatasetConstants._();
  static const String version = '2025.1';
  static const String archiveUrl =
      'https://downloads.opennutrition.app/opennutrition-dataset-2025.1.zip';
  static const String sha256 =
      '30420802bbf0e29852c282e37a58c7e18ebc1b57e109706925ef969f0498ff47';
  static const String tsvName = 'opennutrition_foods.tsv';
  static const Set<String> allowedFiles = <String>{
    tsvName,
    'LICENSE-ODbL.txt',
    'LICENSE-DbCL.txt',
    'README.md',
  };
}

class OpenNutritionImportProgress {
  const OpenNutritionImportProgress({
    required this.stageCode,
    required this.message,
    this.fraction,
    this.completedBytes = 0,
    this.totalBytes = 0,
    this.parsedRows = 0,
    this.importedRows = 0,
    this.skippedRows = 0,
    this.failedRows = 0,
  });
  final String stageCode;
  final String message;
  final double? fraction;
  final int completedBytes;
  final int totalBytes;
  final int parsedRows;
  final int importedRows;
  final int skippedRows;
  final int failedRows;
}

class OpenNutritionImportCancellation {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const OpenNutritionImportCancelled();
  }
}

class OpenNutritionImportCancelled implements Exception {
  const OpenNutritionImportCancelled();
}

class OpenNutritionImportService {
  OpenNutritionImportService(this.repository, {http.Client? client})
      : _client = client ?? http.Client();
  final OpenNutritionCatalogRepository repository;
  final http.Client _client;
  static const int _batchSize = 750;

  Stream<OpenNutritionImportProgress> downloadAndImport({
    required int licenseAcceptedAtEpochMs,
    required OpenNutritionImportCancellation cancellation,
  }) async* {
    final temp = await getTemporaryDirectory();
    final work = await Directory(
      path.join(temp.path, 'opennutrition-${const Uuid().v4()}'),
    ).create(recursive: true);
    final archiveFile = File(path.join(work.path, 'dataset.zip'));
    try {
      final request = http.Request(
        'GET',
        Uri.parse(OpenNutritionDatasetConstants.archiveUrl),
      );
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Download HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      var downloaded = 0;
      final sink = archiveFile.openWrite();
      try {
        await for (final chunk in response.stream) {
          cancellation.throwIfCancelled();
          sink.add(chunk);
          downloaded += chunk.length;
          yield OpenNutritionImportProgress(
            stageCode: OpenNutritionImportStatusCodes.downloading,
            message: 'Download del catalogo OpenNutrition',
            fraction: total > 0 ? downloaded / total : null,
            completedBytes: downloaded,
            totalBytes: total,
          );
        }
      } finally {
        await sink.close();
      }
      yield* _importArchive(
        archiveFile: archiveFile,
        sourceUrl: OpenNutritionDatasetConstants.archiveUrl,
        expectedSha256: OpenNutritionDatasetConstants.sha256,
        licenseAcceptedAtEpochMs: licenseAcceptedAtEpochMs,
        cancellation: cancellation,
      );
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  Stream<OpenNutritionImportProgress> importLocalArchive({
    required File archiveFile,
    required int licenseAcceptedAtEpochMs,
    required OpenNutritionImportCancellation cancellation,
  }) {
    return _importArchive(
      archiveFile: archiveFile,
      sourceUrl: archiveFile.path,
      expectedSha256: OpenNutritionDatasetConstants.sha256,
      licenseAcceptedAtEpochMs: licenseAcceptedAtEpochMs,
      cancellation: cancellation,
    );
  }

  Stream<OpenNutritionImportProgress> _importArchive({
    required File archiveFile,
    required String sourceUrl,
    required String expectedSha256,
    required int licenseAcceptedAtEpochMs,
    required OpenNutritionImportCancellation cancellation,
  }) async* {
    final oldState = await repository.getState();
    final oldBatchId = oldState.activeBatchId;
    final batchId = const Uuid().v4();
    final started = DateTime.now().millisecondsSinceEpoch;
    final state = OpenNutritionCatalogStateEntity(
      id: oldState.id,
      installedVersion: oldState.installedVersion,
      activeBatchId: oldBatchId,
      sourceArchiveUrl: sourceUrl,
      expectedSha256: expectedSha256,
      importStatusCode: OpenNutritionImportStatusCodes.verifying,
      currentStageCode: OpenNutritionImportStatusCodes.verifying,
      licenseAcceptedAtEpochMs: licenseAcceptedAtEpochMs,
      startedAtEpochMs: started,
    );
    await repository.saveState(state);
    final work = await Directory.systemTemp.createTemp('opennutrition-import-');
    try {
      cancellation.throwIfCancelled();
      yield const OpenNutritionImportProgress(
        stageCode: OpenNutritionImportStatusCodes.verifying,
        message: 'Verifica SHA-256 dell’archivio',
      );
      final actualSha =
          (await sha256.bind(archiveFile.openRead()).first).toString();
      state.actualSha256 = actualSha;
      state.archiveBytes = await archiveFile.length();
      if (actualSha.toLowerCase() != expectedSha256.toLowerCase()) {
        throw StateError(
          'Checksum non valido. Atteso $expectedSha256, ottenuto $actualSha.',
        );
      }

      state.currentStageCode = OpenNutritionImportStatusCodes.extracting;
      state.importStatusCode = OpenNutritionImportStatusCodes.extracting;
      await repository.saveState(state);
      yield const OpenNutritionImportProgress(
        stageCode: OpenNutritionImportStatusCodes.extracting,
        message: 'Estrazione sicura dei file consentiti',
      );
      final extracted = await _extractAllowedFiles(
        archiveFile: archiveFile,
        outputDirectory: work,
        cancellation: cancellation,
      );
      final tsv = extracted[OpenNutritionDatasetConstants.tsvName];
      if (tsv == null || !await tsv.exists()) {
        throw StateError(
          'Il file ${OpenNutritionDatasetConstants.tsvName} manca.',
        );
      }
      state.extractedBytes = await tsv.length();
      await _persistLegalFiles(extracted);

      state.currentStageCode = OpenNutritionImportStatusCodes.validatingSchema;
      state.importStatusCode = OpenNutritionImportStatusCodes.validatingSchema;
      await repository.saveState(state);
      yield const OpenNutritionImportProgress(
        stageCode: OpenNutritionImportStatusCodes.validatingSchema,
        message: 'Validazione intestazioni TSV',
      );

      final parser = OpenNutritionTsvParser(
        datasetVersion: OpenNutritionDatasetConstants.version,
        importBatchId: batchId,
        importedAtEpochMs: started,
      );
      final lines = tsv
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      var first = true;
      var consumedBytes = 0;
      var parsed = 0;
      var imported = 0;
      var skipped = 0;
      var failed = 0;
      final buffer = <OpenNutritionFoodEntity>[];
      final totalBytes = await tsv.length();

      state.currentStageCode = OpenNutritionImportStatusCodes.converting;
      state.importStatusCode = OpenNutritionImportStatusCodes.converting;
      await repository.saveState(state);
      await for (final line in lines) {
        cancellation.throwIfCancelled();
        consumedBytes += utf8.encode(line).length + 1;
        if (first) {
          parser.readHeader(line);
          state.schemaJson = jsonEncode(parser.headers);
          first = false;
          continue;
        }
        if (line.trim().isEmpty) continue;
        parsed += 1;
        try {
          final result = parser.parseRow(line);
          if (result.entity == null) {
            skipped += 1;
          } else {
            buffer.add(result.entity!);
          }
        } catch (_) {
          failed += 1;
        }
        if (buffer.length >= _batchSize) {
          await repository.putBatch(List<OpenNutritionFoodEntity>.of(buffer));
          imported += buffer.length;
          buffer.clear();
          state
            ..parsedRows = parsed
            ..importedRows = imported
            ..skippedRows = skipped
            ..failedRows = failed;
          await repository.saveState(state);
          yield OpenNutritionImportProgress(
            stageCode: OpenNutritionImportStatusCodes.converting,
            message: 'Conversione e scrittura in ObjectBox',
            fraction: totalBytes > 0 ? consumedBytes / totalBytes : null,
            completedBytes: consumedBytes,
            totalBytes: totalBytes,
            parsedRows: parsed,
            importedRows: imported,
            skippedRows: skipped,
            failedRows: failed,
          );
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (buffer.isNotEmpty) {
        await repository.putBatch(buffer);
        imported += buffer.length;
      }
      if (imported == 0) throw StateError('Nessun record valido importato.');

      cancellation.throwIfCancelled();
      state.currentStageCode = OpenNutritionImportStatusCodes.activating;
      state.importStatusCode = OpenNutritionImportStatusCodes.activating;
      state
        ..parsedRows = parsed
        ..importedRows = imported
        ..skippedRows = skipped
        ..failedRows = failed;
      await repository.saveState(state);
      yield OpenNutritionImportProgress(
        stageCode: OpenNutritionImportStatusCodes.activating,
        message: 'Attivazione atomica del nuovo catalogo',
        fraction: 1,
        parsedRows: parsed,
        importedRows: imported,
        skippedRows: skipped,
        failedRows: failed,
      );

      state
        ..installedVersion = OpenNutritionDatasetConstants.version
        ..activeBatchId = batchId
        ..importStatusCode = OpenNutritionImportStatusCodes.installed
        ..currentStageCode = OpenNutritionImportStatusCodes.installed
        ..completedAtEpochMs = DateTime.now().millisecondsSinceEpoch
        ..lastError = '';
      await repository.saveState(state);
      if (oldBatchId.isNotEmpty && oldBatchId != batchId) {
        await repository.deleteBatch(oldBatchId);
      }
      yield OpenNutritionImportProgress(
        stageCode: OpenNutritionImportStatusCodes.installed,
        message: 'Catalogo installato',
        fraction: 1,
        parsedRows: parsed,
        importedRows: imported,
        skippedRows: skipped,
        failedRows: failed,
      );
    } on OpenNutritionImportCancelled {
      await repository.deleteBatch(batchId);
      state
        ..importStatusCode = OpenNutritionImportStatusCodes.cancelled
        ..currentStageCode = OpenNutritionImportStatusCodes.cancelled
        ..lastError = 'Importazione annullata.';
      await repository.saveState(state);
      rethrow;
    } catch (error) {
      await repository.deleteBatch(batchId);
      state
        ..importStatusCode = oldBatchId.isEmpty
            ? OpenNutritionImportStatusCodes.failed
            : OpenNutritionImportStatusCodes.installed
        ..currentStageCode = OpenNutritionImportStatusCodes.failed
        ..lastError = error.toString();
      await repository.saveState(state);
      rethrow;
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  Future<void> _persistLegalFiles(Map<String, File> extracted) async {
    final catalogDirectory = Directory(await repository.database.directoryPath);
    final legalDirectory = Directory(
      path.join(catalogDirectory.path, 'licenses'),
    );
    await legalDirectory.create(recursive: true);
    for (final name in const <String>[
      'LICENSE-ODbL.txt',
      'LICENSE-DbCL.txt',
      'README.md',
    ]) {
      final source = extracted[name];
      if (source != null && await source.exists()) {
        await source.copy(path.join(legalDirectory.path, name));
      }
    }
  }

  Future<Map<String, File>> _extractAllowedFiles({
    required File archiveFile,
    required Directory outputDirectory,
    required OpenNutritionImportCancellation cancellation,
  }) async {
    final input = InputFileStream(archiveFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final result = <String, File>{};
      for (final item in archive) {
        cancellation.throwIfCancelled();
        final normalized = item.name.replaceAll('\\', '/');
        final basename = path.basename(normalized);
        if (normalized.startsWith('/') ||
            normalized.contains('../') ||
            path.isAbsolute(normalized)) {
          throw StateError('Percorso ZIP non sicuro: ${item.name}');
        }
        if (!OpenNutritionDatasetConstants.allowedFiles.contains(basename)) {
          continue;
        }
        if (item.isSymbolicLink) {
          throw StateError(
            'Link simbolico non consentito nello ZIP: ${item.name}',
          );
        }
        if (!item.isFile) continue;
        final output = File(path.join(outputDirectory.path, basename));
        await output.parent.create(recursive: true);
        final outputStream = OutputFileStream(output.path);
        try {
          item.writeContent(outputStream);
        } finally {
          await outputStream.close();
        }
        result[basename] = output;
      }
      return result;
    } finally {
      await input.close();
    }
  }

  void dispose() => _client.close();
}
