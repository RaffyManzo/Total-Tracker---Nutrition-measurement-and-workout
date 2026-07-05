import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/preferences/app_navigation_preferences.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final DashboardBackController dashboardBackController =
    DashboardBackController();

class DashboardBackScope extends StatelessWidget {
  const DashboardBackScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        unawaited(
          dashboardBackController.handle(GoRouter.of(context)),
        );
      },
      child: child,
    );
  }
}

class DashboardBackController {
  static const Duration exitConfirmationWindow = Duration(seconds: 2);

  DateTime? _lastExitAttempt;
  bool _handling = false;

  Future<bool> handle(GoRouter router) async {
    if (_handling) {
      return true;
    }

    _handling = true;
    try {
      if (router.canPop()) {
        _lastExitAttempt = null;
        router.pop();
        return true;
      }

      final String configuredRoute =
          await AppNavigationPreferences.getDefaultDashboardRoute();
      final String preferredRoute =
          configuredRoute == '/' ? '/food' : configuredRoute;

      final String rawCurrent =
          router.routerDelegate.currentConfiguration.uri.path;
      final String currentRoute = rawCurrent == '/' ? '/food' : rawCurrent;

      if (currentRoute != preferredRoute) {
        _lastExitAttempt = null;
        router.go(preferredRoute);
        _showMessage('Dashboard aperta.');
        return true;
      }

      final DateTime now = DateTime.now();
      final DateTime? previousAttempt = _lastExitAttempt;

      if (previousAttempt != null &&
          now.difference(previousAttempt) <= exitConfirmationWindow) {
        _lastExitAttempt = null;
        await SystemNavigator.pop();
        return true;
      }

      _lastExitAttempt = now;
      _showMessage(
        'Premi di nuovo Indietro per chiudere Total Tracker.',
      );
      return true;
    } finally {
      _handling = false;
    }
  }

  void _showMessage(String message) {
    appScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: exitConfirmationWindow,
        ),
      );
  }
}

// Conservata per compatibilità con l'inizializzazione esistente.
// Il tasto Indietro è gestito da DashboardBackScope nel ShellRoute.
void installDashboardBackDispatcher(GoRouter router) {}
