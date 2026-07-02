import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/transfer/domain/transfer_models.dart';

void main() {
  const TransferArchiveCodec codec = TransferArchiveCodec();

  test('portable archive preserves manifest and data', () {
    final TransferArchivePayload source = TransferArchivePayload(
      manifest: <String, dynamic>{
        'format': totalTrackerArchiveFormat,
        'formatVersion': totalTrackerArchiveVersion,
        'counts': <String, dynamic>{'ingredients': 2},
      },
      data: <String, dynamic>{
        'ingredients': <Map<String, dynamic>>[
          <String, dynamic>{'uuid': 'a', 'name': 'Riso'},
          <String, dynamic>{'uuid': 'b', 'name': 'Latte'},
        ],
      },
    );

    final TransferArchivePayload decoded = codec.decode(codec.encode(source));

    expect(decoded.manifest['format'], totalTrackerArchiveFormat);
    expect(decoded.manifest['formatVersion'], totalTrackerArchiveVersion);
    expect((decoded.data['ingredients'] as List).length, 2);
  });

  test('archive rejects a different format', () {
    final TransferArchivePayload source = TransferArchivePayload(
      manifest: <String, dynamic>{
        'format': 'other-format',
        'formatVersion': 1,
      },
      data: const <String, dynamic>{},
    );

    expect(
      () => codec.decode(codec.encode(source)),
      throwsA(isA<FormatException>()),
    );
  });

  test('analysis counters include selected items and conflicts', () {
    final TransferImportAnalysis analysis = TransferImportAnalysis(
      sourcePath: 'sample.totaltracker',
      manifest: const <String, dynamic>{},
      warnings: const <String>[],
      sections: <TransferImportSection>[
        TransferImportSection(
          code: 'ingredients',
          title: 'Ingredienti',
          description: '',
          items: <TransferImportItem>[
            TransferImportItem(
              id: '1',
              categoryCode: 'ingredients',
              title: 'Riso',
              subtitle: '',
              data: const <String, dynamic>{},
              hasConflict: true,
            ),
            TransferImportItem(
              id: '2',
              categoryCode: 'ingredients',
              title: 'Latte',
              subtitle: '',
              data: const <String, dynamic>{},
              selected: false,
            ),
          ],
        ),
      ],
    );

    expect(analysis.totalItems, 2);
    expect(analysis.selectedItems, 1);
    expect(analysis.conflicts, 1);
  });
}
