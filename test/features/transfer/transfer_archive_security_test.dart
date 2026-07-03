import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/transfer/domain/transfer_models.dart';

void main() {
  const TransferArchiveCodec codec = TransferArchiveCodec();

  TransferArchivePayload samplePayload() {
    return TransferArchivePayload(
      manifest: <String, dynamic>{
        'format': totalTrackerArchiveFormat,
        'formatVersion': totalTrackerArchiveVersion,
        'exportedAt': DateTime.utc(2026, 7, 3).toIso8601String(),
        'appVersion': '0.3.1+5',
        'areas': <String>['profile', 'food'],
      },
      data: <String, dynamic>{
        'profile': <String, dynamic>{'name': 'security-test'},
        'ingredients': <Object?>[],
      },
    );
  }

  test('version 2 archive round-trips with SHA-256 integrity', () {
    final Uint8List encoded = codec.encode(samplePayload());
    final TransferArchivePayload decoded = codec.decode(encoded);

    expect(decoded.manifest['formatVersion'], totalTrackerArchiveVersion);
    expect(decoded.data['profile'], isA<Map<String, dynamic>>());
  });

  test('rejects an archive containing an unknown entry', () {
    final Archive archive = Archive()
      ..addFile(ArchiveFile('unexpected.txt', 1, <int>[1]));
    final Uint8List encoded = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(() => codec.decode(encoded), throwsFormatException);
  });

  test('rejects version 2 data with forged checksums', () {
    final List<int> manifestBytes = utf8.encode(
      jsonEncode(<String, dynamic>{
        'format': totalTrackerArchiveFormat,
        'formatVersion': totalTrackerArchiveVersion,
        'exportedAt': DateTime.utc(2026, 7, 3).toIso8601String(),
        'appVersion': '0.3.1+5',
      }),
    );
    final List<int> dataBytes = utf8.encode(jsonEncode(<String, dynamic>{}));
    final List<int> checksumBytes = utf8.encode(
      jsonEncode(<String, dynamic>{
        'algorithm': 'sha256',
        'manifest.json': List<String>.filled(64, '0').join(),
        'data.json': List<String>.filled(64, '0').join(),
      }),
    );
    final Archive archive = Archive()
      ..addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
      )
      ..addFile(ArchiveFile('data.json', dataBytes.length, dataBytes))
      ..addFile(
        ArchiveFile('checksums.json', checksumBytes.length, checksumBytes),
      );
    final Uint8List encoded = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(() => codec.decode(encoded), throwsFormatException);
  });

  test('rejects an oversized compressed input before decompression', () {
    final Uint8List oversized = Uint8List(
      totalTrackerMaxCompressedArchiveBytes + 1,
    );

    expect(() => codec.decode(oversized), throwsFormatException);
  });
}
