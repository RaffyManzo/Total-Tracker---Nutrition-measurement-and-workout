import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../objectbox.g.dart';

class OpenNutritionCatalogDatabase {
  Store? _store;
  Future<Store>? _opening;

  static const String directoryName = 'total_tracker_opennutrition_objectbox';

  Future<Store> get store async {
    final Store? existing = _store;
    if (existing != null && !existing.isClosed()) {
      return existing;
    }

    final Future<Store>? pending = _opening;
    if (pending != null) return pending;

    final Future<Store> operation = _openWithRetry();
    _opening = operation;
    try {
      final Store opened = await operation;
      _store = opened;
      return opened;
    } finally {
      if (identical(_opening, operation)) {
        _opening = null;
      }
    }
  }

  Future<Store> _openWithRetry() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final String directory = path.join(documents.path, directoryName);

    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt += 1) {
      try {
        return await openStore(directory: directory);
      } catch (error) {
        lastError = error;
        if (attempt == 4) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 180 * (attempt + 1)),
        );
      }
    }
    throw StateError('Apertura catalogo non riuscita: $lastError');
  }

  Future<String> get directoryPath async {
    final Directory documents = await getApplicationDocumentsDirectory();
    return path.join(documents.path, directoryName);
  }

  void close() {
    final Store? current = _store;
    if (current != null && !current.isClosed()) {
      current.close();
    }
    _store = null;
  }

  Future<void> deleteDirectory() async {
    close();
    final Directory directory = Directory(await directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
