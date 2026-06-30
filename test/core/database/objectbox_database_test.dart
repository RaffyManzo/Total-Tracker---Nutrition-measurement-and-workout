import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/database/objectbox_database.dart';

void main() {
  test('apre e chiude lo Store senza errori', () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('total_tracker_objectbox_test_');
    final ObjectBoxDatabase database = ObjectBoxDatabase();

    await database.open(directory: directory.path);
    expect(database.isOpen, isTrue);

    await database.close();
    expect(database.isOpen, isFalse);

    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('non apre due Store concorrenti sulla stessa istanza', () async {
    final Directory directory =
        await Directory.systemTemp.createTemp('total_tracker_objectbox_test_');
    final ObjectBoxDatabase database = ObjectBoxDatabase();

    final stores = await Future.wait([
      database.open(directory: directory.path),
      database.open(directory: directory.path),
    ]);

    expect(identical(stores.first, stores.last), isTrue);

    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });
}
