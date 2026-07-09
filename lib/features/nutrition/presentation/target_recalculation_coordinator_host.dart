import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/services/target_input_change_bus.dart';
import '../data/services/target_invalidation_repository.dart';
import '../data/services/target_recalculation_coordinator.dart';
import '../data/services/target_recalculation_service.dart';
import 'food_v01_screens.dart';

class TargetRecalculationCoordinatorHost extends ConsumerStatefulWidget {
  const TargetRecalculationCoordinatorHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<TargetRecalculationCoordinatorHost> createState() =>
      _TargetRecalculationCoordinatorHostState();
}

class _TargetRecalculationCoordinatorHostState
    extends ConsumerState<TargetRecalculationCoordinatorHost> {
  TargetRecalculationCoordinator? _coordinator;
  StreamSubscription<TargetSnapshotsUpdated>? _snapshotSubscription;
  bool _startScheduled = false;
  bool _disposed = false;

  @override
  Widget build(BuildContext context) {
    final DatabaseInitializationStatus status = ref.watch(
      databaseInitializationStatusProvider,
    );
    if (status.isReady &&
        _coordinator == null &&
        !_startScheduled &&
        !_disposed) {
      _startScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScheduled = false;
        _start();
      });
    }
    return widget.child;
  }

  void _start() {
    if (!mounted || _disposed || _coordinator != null) {
      return;
    }
    final TargetRecalculationService recalculation = TargetRecalculationService(
      profiles: ref.read(userProfileRepositoryProvider),
      dailyRecords: ref.read(dailyRecordRepositoryProvider),
      analytics: ref.read(foodAnalyticsServiceProvider),
    );
    final TargetRecalculationCoordinator coordinator =
        TargetRecalculationCoordinator(
      invalidations: TargetInvalidationRepository(
        ref.read(objectBoxStoreProvider),
      ),
      dailyRecords: ref.read(dailyRecordRepositoryProvider),
      recalculation: recalculation,
    );
    _coordinator = coordinator;
    _snapshotSubscription = TargetInputChangeBus.snapshotUpdates.listen(
      _handleSnapshotsUpdated,
    );
    coordinator.start();
  }

  void _handleSnapshotsUpdated(TargetSnapshotsUpdated event) {
    TargetInputChangeBus.recordUiRefreshRequested();
    if (!mounted || _disposed) {
      return;
    }
    ref.invalidate(profileSettingsRevisionProvider);
    ref.invalidate(foodHubV01Provider);
    ref.invalidate(foodDaysV01Provider);
    ref.invalidate(foodMealsV01Provider);
    TargetInputChangeBus.recordUiRefreshExecution();
    FoodDataRefreshBus.publishManualRefresh(
      event.fromDateKey,
      operationId: event.operationId,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _startScheduled = false;
    unawaited(_snapshotSubscription?.cancel());
    unawaited(_coordinator?.dispose());
    super.dispose();
  }
}
