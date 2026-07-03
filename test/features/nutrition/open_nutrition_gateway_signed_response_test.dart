import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:total_tracker/core/preferences/food_service_preferences.dart';
import 'package:total_tracker/features/nutrition/data/services/open_nutrition_gateway_service.dart';

void main() {
  late Ed25519 algorithm;
  late SimpleKeyPair keyPair;
  late OpenNutritionGatewayConfig config;

  setUp(() async {
    algorithm = Ed25519();
    keyPair = await algorithm.newKeyPairFromSeed(
      List<int>.generate(32, (int index) => index),
    );
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();

    config = OpenNutritionGatewayConfig.validate(
      rawUrl: 'https://nutrition.example.com',
      rawPublicKey: base64Encode(publicKey.bytes),
      rawKeyId: 'primary',
    );

    SharedPreferences.setMockInitialValues(<String, Object>{
      FoodServicePreferenceKeys.openNutritionRemoteEnabled: true,
      FoodServicePreferenceKeys.gatewayInstallationId:
          '11111111-1111-4111-8111-111111111111',
    });
  });

  test('accepts a bounded Ed25519-signed gateway response', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _signedResponse(
        request: request,
        algorithm: algorithm,
        keyPair: keyPair,
      );
    });

    final OpenNutritionGatewayService service = OpenNutritionGatewayService(
      client: client,
      fixedConfig: config,
      fixedInstallationId: '11111111-1111-4111-8111-111111111111',
    );
    addTearDown(service.dispose);

    final OpenNutritionGatewaySearchPage result = await service.search(
      query: 'Greek yogurt',
    );

    expect(result.datasetVersion, 'test-1');
    expect(result.foods, hasLength(1));
    expect(result.foods.single.name, 'Greek yogurt');
    expect(result.foods.single.importBatchId, 'remote:test-1');
    expect(
      result.foods.single.imageUrl,
      isEmpty,
      reason: 'Remote images are opt-in and disabled by default.',
    );
  });

  test('rejects a body whose signature was created by another key', () async {
    final SimpleKeyPair attacker = await algorithm.newKeyPairFromSeed(
      List<int>.filled(32, 9),
    );
    final MockClient client = MockClient((http.Request request) async {
      return _signedResponse(
        request: request,
        algorithm: algorithm,
        keyPair: attacker,
      );
    });

    final OpenNutritionGatewayService service = OpenNutritionGatewayService(
      client: client,
      fixedConfig: config,
      fixedInstallationId: '11111111-1111-4111-8111-111111111111',
    );
    addTearDown(service.dispose);

    await expectLater(
      service.search(query: 'Greek yogurt'),
      throwsA(isA<OpenNutritionGatewayException>()),
    );
  });

  test('rejects signed responses with unknown schema fields', () async {
    final MockClient client = MockClient((http.Request request) async {
      return _signedResponse(
        request: request,
        algorithm: algorithm,
        keyPair: keyPair,
        extraEnvelope: const <String, Object?>{
          'unexpectedPrivilegedField': true,
        },
      );
    });

    final OpenNutritionGatewayService service = OpenNutritionGatewayService(
      client: client,
      fixedConfig: config,
      fixedInstallationId: '11111111-1111-4111-8111-111111111111',
    );
    addTearDown(service.dispose);

    await expectLater(
      service.search(query: 'Greek yogurt'),
      throwsA(isA<OpenNutritionGatewayException>()),
    );
  });

  test('rejects stale signed responses', () async {
    final MockClient client = MockClient((http.Request request) async {
      final DateTime stale =
          DateTime.now().toUtc().subtract(const Duration(hours: 1));
      return _signedResponse(
        request: request,
        algorithm: algorithm,
        keyPair: keyPair,
        issuedAt: stale,
        expiresAt: stale.add(const Duration(minutes: 2)),
      );
    });

    final OpenNutritionGatewayService service = OpenNutritionGatewayService(
      client: client,
      fixedConfig: config,
      fixedInstallationId: '11111111-1111-4111-8111-111111111111',
    );
    addTearDown(service.dispose);

    await expectLater(
      service.search(query: 'Greek yogurt'),
      throwsA(isA<OpenNutritionGatewayException>()),
    );
  });
}

Future<http.Response> _signedResponse({
  required http.Request request,
  required Ed25519 algorithm,
  required SimpleKeyPair keyPair,
  DateTime? issuedAt,
  DateTime? expiresAt,
  Map<String, Object?> extraEnvelope = const <String, Object?>{},
}) async {
  final DateTime now = DateTime.now().toUtc();
  final DateTime issued = issuedAt ?? now;
  final Map<String, Object?> envelope = <String, Object?>{
    'schemaVersion': 1,
    'requestId': request.headers['X-Request-Id'],
    'issuedAt': issued.toIso8601String(),
    'expiresAt':
        (expiresAt ?? issued.add(const Duration(minutes: 2))).toIso8601String(),
    'datasetVersion': 'test-1',
    'page': 1,
    'hasNext': false,
    'items': <Object?>[
      <String, Object?>{
        'externalId': 'food-1',
        'name': 'Greek yogurt',
        'brand': 'Example',
        'barcode': '8001234567890',
        'imageUrl': 'https://images.openfoodfacts.org/a.400.jpg',
        'imageSmallUrl': 'https://images.openfoodfacts.org/a.200.jpg',
        'kcal100g': 60,
        'protein100g': 10,
        'carbs100g': 4,
        'fat100g': 0.5,
        'fiber100g': 0,
        'sugar100g': 4,
        'salt100g': 0.1,
        'sodium100g': 0.04,
        'estimated': false,
        'fromOpenFoodFacts': true,
      },
    ],
    ...extraEnvelope,
  };
  final Uint8List body = Uint8List.fromList(
    utf8.encode(jsonEncode(envelope)),
  );
  final Signature signature = await algorithm.sign(
    body,
    keyPair: keyPair,
  );
  return http.Response.bytes(
    body,
    200,
    headers: <String, String>{
      'content-type': 'application/json; charset=utf-8',
      'x-opennutrition-signature': base64Encode(signature.bytes),
      'x-opennutrition-key-id': 'primary',
    },
  );
}
