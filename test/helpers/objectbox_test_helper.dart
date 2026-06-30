import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/database/objectbox_database.dart';

Future<ObjectBoxDatabase> openTestDatabase() async {
  final Directory directory =
      await Directory.systemTemp.createTemp('total_tracker_objectbox_test_');
  final ObjectBoxDatabase database = ObjectBoxDatabase();
  await database.open(directory: directory.path);

  addTearDown(() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  return database;
}
