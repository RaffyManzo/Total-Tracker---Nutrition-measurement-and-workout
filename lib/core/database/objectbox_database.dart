import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';

class ObjectBoxDatabase {
  static const String databaseFolderName = 'total_tracker_objectbox';

  static final Map<String, Store> _storesByDirectory = <String, Store>{};
  static final Map<String, Future<Store>> _openingsByDirectory =
      <String, Future<Store>>{};

  Store? _store;
  String? _directory;

  Store get store {
    final Store? currentStore = _store;
    if (currentStore == null) {
      throw StateError('ObjectBox Store is not open.');
    }
    return currentStore;
  }

  String? get directory => _directory;
  bool get isOpen => _store != null;

  Future<Store> open({String? directory}) async {
    final Store? currentStore = _store;
    if (currentStore != null) {
      return currentStore;
    }

    final String resolvedDirectory = p.normalize(
      directory ?? await _productionDirectory(),
    );
    await Directory(resolvedDirectory).create(recursive: true);

    final Store? sharedStore = _storesByDirectory[resolvedDirectory];
    if (sharedStore != null) {
      _store = sharedStore;
      _directory = resolvedDirectory;
      return sharedStore;
    }

    final Future<Store>? activeOpening =
        _openingsByDirectory[resolvedDirectory];
    if (activeOpening != null) {
      final Store opened = await activeOpening;
      _store = opened;
      _directory = resolvedDirectory;
      return opened;
    }

    final Future<Store> opening = _openStore(resolvedDirectory);
    _openingsByDirectory[resolvedDirectory] = opening;
    try {
      final Store opened = await opening;
      _storesByDirectory[resolvedDirectory] = opened;
      _store = opened;
      _directory = resolvedDirectory;
      return opened;
    } finally {
      _openingsByDirectory.remove(resolvedDirectory);
    }
  }

  Future<void> close() async {
    final Store? currentStore = _store;
    final String? currentDirectory = _directory;
    if (currentStore == null || currentDirectory == null) {
      return;
    }

    if (identical(_storesByDirectory[currentDirectory], currentStore)) {
      _storesByDirectory.remove(currentDirectory);
    }
    currentStore.close();
    _store = null;
    _directory = null;
  }

  Future<Store> _openStore(String directory) async {
    if (Store.isOpen(directory)) {
      return Store.attach(getObjectBoxModel(), directory);
    }

    try {
      return Store(getObjectBoxModel(), directory: directory);
    } catch (error) {
      final String message = error.toString();
      if (message.contains('another store is still open') ||
          message.contains('OBX_ERROR code 10001')) {
        return Store.attach(getObjectBoxModel(), directory);
      }
      rethrow;
    }
  }

  Future<String> _productionDirectory() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, databaseFolderName);
  }
}
