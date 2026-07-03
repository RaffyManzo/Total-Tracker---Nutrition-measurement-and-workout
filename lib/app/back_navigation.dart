import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/preferences/app_navigation_preferences.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final DashboardBackController dashboardBackController =
    DashboardBackController();

class DashboardBackController {
  static const Duration exitConfirmationWindow = Duration(seconds: 2);

  DateTime? _lastExitAttempt;
  bool _handling = false;

  Future<bool> handle(GoRouter router) async {
    if (_handling) return true;
    _handling = true;
    try {
      if (router.canPop()) {
        _lastExitAttempt = null;
        router.pop();
        return true;
      }

      final String preferredRoute =
          await AppNavigationPreferences.getDefaultDashboardRoute();
      final String rawCurrent =
          router.routerDelegate.currentConfiguration.uri.path;
      final String currentRoute = rawCurrent == '/' ? '/food' : rawCurrent;

      if (currentRoute != preferredRoute) {
        _lastExitAttempt = DateTime.now();
        router.go(preferredRoute);
        final ScaffoldMessengerState? messenger =
            appScaffoldMessengerKey.currentState;
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Dashboard aperta. Premi ancora Indietro entro 2 secondi '
                'per chiudere Total Tracker.',
              ),
              duration: exitConfirmationWindow,
            ),
          );
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
      final ScaffoldMessengerState? messenger =
          appScaffoldMessengerKey.currentState;
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Premi di nuovo Indietro per chiudere Total Tracker.',
            ),
            duration: exitConfirmationWindow,
          ),
        );
      return true;
    } finally {
      _handling = false;
    }
  }
}

class DashboardBackGuard extends StatelessWidget {
  const DashboardBackGuard({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter.of(context);
    final bool canPop = router.canPop();

    return PopScope<Object?>(
      canPop: canPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          unawaited(dashboardBackController.handle(router));
        }
      },
      child: child,
    );
  }
}
