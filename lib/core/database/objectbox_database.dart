import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../objectbox.g.dart';

class ObjectBoxDatabase {
  static const String databaseFolderName = 'total_tracker_objectbox';

  Store? _store;
  Future<Store>? _opening;
  String? _openingDirectory;
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

  Future<Store> open({String? directory}) {
    final Store? currentStore = _store;
    if (currentStore != null) {
      return Future<Store>.value(currentStore);
    }

    final Future<Store>? currentOpening = _opening;
    if (currentOpening != null) {
      if (directory != null && directory != _openingDirectory) {
        throw StateError('ObjectBox Store is already opening elsewhere.');
      }
      return currentOpening;
    }

    _openingDirectory = directory;
    _opening = _openStore(directory: directory);
    return _opening!.whenComplete(() {
      _opening = null;
      _openingDirectory = null;
    });
  }

  Future<void> close() async {
    final Store? currentStore = _store;
    if (currentStore == null) {
      return;
    }
    currentStore.close();
    _store = null;
    _directory = null;
  }

  Future<Store> _openStore({String? directory}) async {
    final String resolvedDirectory = directory ?? await _productionDirectory();
    await Directory(resolvedDirectory).create(recursive: true);
    final Store openedStore = Store(
      getObjectBoxModel(),
      directory: resolvedDirectory,
    );
    _store = openedStore;
    _directory = resolvedDirectory;
    return openedStore;
  }

  Future<String> _productionDirectory() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return p.join(documentsDirectory.path, databaseFolderName);
  }
}
