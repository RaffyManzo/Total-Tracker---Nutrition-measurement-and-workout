import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/core/services/app_info_service.dart';

void main() {
  test('formats byte sizes using readable units', () {
    expect(formatAppByteSize(10), '10 B');
    expect(formatAppByteSize(1024), '1.0 KB');
    expect(formatAppByteSize(5 * 1024 * 1024), '5.0 MB');
  });

  test('calculates the recursive size of a directory', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'total_tracker_app_info_test_',
    );
    addTearDown(() => root.delete(recursive: true));

    await File('${root.path}${Platform.pathSeparator}first.bin')
        .writeAsBytes(List<int>.filled(10, 1));
    final Directory nested = Directory(
      '${root.path}${Platform.pathSeparator}nested',
    );
    await nested.create();
    await File('${nested.path}${Platform.pathSeparator}second.bin')
        .writeAsBytes(List<int>.filled(15, 2));

    expect(await AppInfoService.calculateDirectorySize(root), 25);
  });
}
