import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/diagnostics/app_diagnostics.dart';
import '../core/preferences/app_navigation_preferences.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

final DashboardBackController dashboardBackController =
    DashboardBackController();

class DashboardBackScope extends StatelessWidget {
  const DashboardBackScope({required this.child, super.key});

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
    '/',
    '/food',
    '/workout',
    '/measurements',
    '/settings',
  };
  static const Duration _exitWindow = Duration(seconds: 2);

  bool _handling = false;
  DateTime? _lastExitAttempt;

  Future<bool> handle(GoRouter router) async {
    if (_handling) return true;
    _handling = true;
    try {
      final String preferredRoute = _normalizeRoot(
        await AppNavigationPreferences.getDefaultDashboardRoute(),
      );
      final String currentRoute = _normalizeRoot(
        router.routerDelegate.currentConfiguration.uri.path,
      );
      final bool isRoot = _dashboardRoots.contains(currentRoute);

      unawaited(
        AppDiagnostics.instance.info(
          'navigation.back_pressed',
          data: <String, Object?>{
            'currentRoute': currentRoute,
            'preferredRoute': preferredRoute,
            'routerCanPop': router.canPop(),
            'isDashboardRoot': isRoot,
          },
        ),
      );

      if (!isRoot && router.canPop()) {
        router.pop();
        return true;
      }

      if (currentRoute != preferredRoute) {
        _lastExitAttempt = null;
        router.go(preferredRoute);
        _showMessage('Dashboard aperta.');
        return true;
      }

      final DateTime now = DateTime.now();
      final DateTime? previous = _lastExitAttempt;
      if (previous == null || now.difference(previous) > _exitWindow) {
        _lastExitAttempt = now;
        _showMessage('Premi di nuovo Indietro per chiudere.');
        return true;
      }

      _lastExitAttempt = null;
      unawaited(AppDiagnostics.instance.info('navigation.exit_confirmed'));
      await SystemNavigator.pop();
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
    final String value = route.trim();
    if (value.isEmpty || value == '/') return '/food';
    final Uri uri = Uri.tryParse(value) ?? Uri(path: value);
    return uri.path.isEmpty ? '/food' : uri.path;
  }

  void _showMessage(String message) {
    appScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }
}

void installDashboardBackDispatcher(GoRouter router) {}
