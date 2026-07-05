import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/diagnostics/app_diagnostics.dart';
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
        if (didPop) return;
        unawaited(dashboardBackController.handle(GoRouter.of(context)));
      },
      child: child,
    );
  }
}

class DashboardBackController {
  static const Set<String> _dashboardRoots = <String>{
    '/food',
    '/workout',
    '/measurements',
    '/settings',
  };

  bool _handling = false;

  Future<bool> handle(GoRouter router) async {
    if (_handling) return true;
    _handling = true;

    try {
      final String configuredRoute =
          await AppNavigationPreferences.getDefaultDashboardRoute();
      final String preferredRoute = _normalizeRoot(configuredRoute);
      final String rawCurrent =
          router.routerDelegate.currentConfiguration.uri.path;
      final String currentRoute = _normalizeRoot(rawCurrent);
      final bool isDashboardRoot = _dashboardRoots.contains(currentRoute);

      unawaited(
        AppDiagnostics.instance.info(
          'navigation.back_pressed',
          data: <String, Object?>{
            'currentRoute': currentRoute,
            'preferredRoute': preferredRoute,
            'routerCanPop': router.canPop(),
            'isDashboardRoot': isDashboardRoot,
          },
        ),
      );

      if (isDashboardRoot) {
        if (currentRoute != preferredRoute) {
          router.go(preferredRoute);
          _showMessage('Dashboard aperta.');
        }
        // Il back sulla root viene sempre consumato. L'app non viene chiusa.
        return true;
      }

      if (router.canPop()) {
        router.pop();
        return true;
      }

      router.go(preferredRoute);
      return true;
    } catch (error, stackTrace) {
      unawaited(
        AppDiagnostics.instance.error(
          'navigation.back_failed',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return true;
    } finally {
      _handling = false;
    }
  }

  String _normalizeRoot(String route) {
    final String normalized = route.trim();
    if (normalized.isEmpty || normalized == '/') return '/food';
    return normalized;
  }

  void _showMessage(String message) {
    appScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 1),
        ),
      );
  }
}

// Conservata per compatibilità con l'inizializzazione esistente.
// Il tasto Indietro è gestito da DashboardBackScope nel ShellRoute.
void installDashboardBackDispatcher(GoRouter router) {}
