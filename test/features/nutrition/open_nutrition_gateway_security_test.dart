import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/services/open_nutrition_gateway_service.dart';

void main() {
  group('OpenNutrition gateway security', () {
    final String publicKey =
        base64Encode(Uint8List.fromList(List<int>.filled(32, 7)));

    test('accepts only a strict public HTTPS hostname and Ed25519 key', () {
      final OpenNutritionGatewayConfig config =
          OpenNutritionGatewayConfig.validate(
        rawUrl: 'https://nutrition.example.com',
        rawPublicKey: publicKey,
        rawKeyId: 'primary',
      );

      expect(config.baseUri.scheme, 'https');
      expect(config.baseUri.host, 'nutrition.example.com');
      expect(config.publicKeyBytes, hasLength(32));
    });

    test('rejects unsafe gateway destinations and ambiguous hostnames', () {
      for (final String url in <String>[
        'http://nutrition.example.com',
        'https://localhost',
        'https://127.0.0.1',
        'https://[::1]',
        'https://gateway.local',
        'https://singlelabel',
        'https://bad..example.com',
        'https://-bad.example.com',
        'https://bad-.example.com',
        'https://münich.example.com',
        'https://user:pass@nutrition.example.com',
        'https://nutrition.example.com:8443',
        'https://nutrition.example.com?next=internal',
        'https://nutrition.example.com/#fragment',
      ]) {
        expect(
          () => OpenNutritionGatewayConfig.validate(
            rawUrl: url,
            rawPublicKey: publicKey,
            rawKeyId: 'primary',
          ),
          throwsA(isA<OpenNutritionGatewayException>()),
          reason: url,
        );
      }
    });

    test('query policy rejects controls, bidi, URLs and injection syntax', () {
      expect(
        OpenNutritionGatewayService.validateQuery('Greek   yogurt'),
        'Greek yogurt',
      );
      expect(
        OpenNutritionGatewayService.validateQuery('caffè latte 2%'),
        'caffè latte 2%',
      );

      for (final String query in <String>[
        'a',
        List<String>.filled(81, 'x').join(),
        'milk\nadmin',
        'milk\u202Eadmin',
        'milk<script>',
        r'milk\..\secret',
        'milk;drop table foods',
        'https://example.com',
        'www.example.com',
        'milk -- admin',
        'milk /* admin */',
        '!!!',
        'one two three four five six seven eight nine ten eleven twelve thirteen',
      ]) {
        expect(
          () => OpenNutritionGatewayService.validateQuery(query),
          throwsA(isA<OpenNutritionGatewayException>()),
          reason: query,
        );
      }
    });

    test('query policy limits UTF-8 bytes independently from characters', () {
      final String oversizedUtf8 = List<String>.filled(60, '€').join();
      expect(
        () => OpenNutritionGatewayService.validateQuery(oversizedUtf8),
        throwsA(isA<OpenNutritionGatewayException>()),
      );
    });
  });
}
