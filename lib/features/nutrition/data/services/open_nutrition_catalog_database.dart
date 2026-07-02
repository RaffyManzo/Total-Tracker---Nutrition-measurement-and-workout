import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../objectbox.g.dart';

class OpenNutritionCatalogDatabase {
  Store? _store;

  static const String directoryName = 'total_tracker_opennutrition_objectbox';

  Future<Store> get store async {
    final existing = _store;
    if (existing != null && !existing.isClosed()) {
      return existing;
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = path.join(documents.path, directoryName);
    _store = await openStore(directory: directory);
    return _store!;
  }

  Future<String> get directoryPath async {
    final documents = await getApplicationDocumentsDirectory();
    return path.join(documents.path, directoryName);
  }

  void close() {
    final current = _store;
    if (current != null && !current.isClosed()) {
      current.close();
    }
    _store = null;
  }

  Future<void> deleteDirectory() async {
    close();
    final directory = Directory(await directoryPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
