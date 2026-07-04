import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../preferences/food_service_preferences.dart';

class OpenNutritionNetworkPolicyException implements Exception {
  const OpenNutritionNetworkPolicyException(this.message);

  final String message;

  @override
  String toString() => message;
}

class OpenNutritionNetworkDecision {
  const OpenNutritionNetworkDecision({
    required this.allowed,
    required this.message,
    required this.connectionLabel,
  });

  final bool allowed;
  final String message;
  final String connectionLabel;
}

class OpenNutritionNetworkAccess {
  const OpenNutritionNetworkAccess._();

  static const Duration connectivityTimeout = Duration(seconds: 5);

  static Future<OpenNutritionNetworkDecision> evaluate(
    OpenNutritionNetworkPolicy policy,
  ) async {
    final List<ConnectivityResult> results;
    try {
      results =
          await Connectivity().checkConnectivity().timeout(connectivityTimeout);
    } on TimeoutException {
      throw const OpenNutritionNetworkPolicyException(
        'Impossibile determinare in tempo utile il tipo di rete attiva.',
      );
    } catch (error) {
      throw OpenNutritionNetworkPolicyException(
        'Impossibile verificare la rete attiva: $error',
      );
    }

    final bool hasWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    final bool hasMobile = results.contains(ConnectivityResult.mobile);
    final bool hasNoConnection = results.isEmpty ||
        results.every(
            (ConnectivityResult value) => value == ConnectivityResult.none);

    final String connectionLabel;
    if (hasWifi && hasMobile) {
      connectionLabel = 'Wi-Fi e dati mobili';
    } else if (hasWifi) {
      connectionLabel = 'Wi-Fi';
    } else if (hasMobile) {
      connectionLabel = 'dati mobili';
    } else if (hasNoConnection) {
      connectionLabel = 'nessuna connessione';
    } else {
      connectionLabel = 'connessione non classificata';
    }

    final bool allowed = switch (policy) {
      OpenNutritionNetworkPolicy.wifiOnly => hasWifi,
      OpenNutritionNetworkPolicy.mobileOnly => hasMobile && !hasWifi,
      OpenNutritionNetworkPolicy.wifiAndMobile => hasWifi || hasMobile,
    };

    if (allowed) {
      return OpenNutritionNetworkDecision(
        allowed: true,
        message: 'Connessione consentita.',
        connectionLabel: connectionLabel,
      );
    }

    return OpenNutritionNetworkDecision(
      allowed: false,
      connectionLabel: connectionLabel,
      message: 'OpenNutrition non è stato avviato: la policy "${policy.label}" '
          'non consente la rete attiva ($connectionLabel). Modifica la policy '
          'nelle impostazioni oppure cambia connessione.',
    );
  }
}
