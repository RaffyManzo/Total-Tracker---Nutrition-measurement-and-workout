import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/food_data_refresh_bus.dart';
import '../data/services/target_recalculation_service.dart';
import 'food_v01_screens.dart';

/// Adds one authoritative synchronization action to the existing day detail.
///
/// Pull-to-refresh recalculates, persists and then broadcasts the same refresh
/// signal used by the rest of the nutrition UI. The original screen remains the
/// only owner of the day layout and data presentation.
class SynchronizedFoodDayDetailScreen extends ConsumerStatefulWidget {
  const SynchronizedFoodDayDetailScreen({
    required this.date,
    super.key,
  });

  final String date;

  @override
  ConsumerState<SynchronizedFoodDayDetailScreen> createState() =>
      _SynchronizedFoodDayDetailScreenState();
}

class _SynchronizedFoodDayDetailScreenState
    extends ConsumerState<SynchronizedFoodDayDetailScreen> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      notificationPredicate: (ScrollNotification notification) => true,
      onRefresh: _synchronize,
      child: FoodDayDetailScreen(date: widget.date),
    );
  }

  Future<void> _synchronize() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final TargetRecalculationService service = TargetRecalculationService(
        profiles: ref.read(userProfileRepositoryProvider),
        dailyRecords: ref.read(dailyRecordRepositoryProvider),
        analytics: ref.read(foodAnalyticsServiceProvider),
      );
      final TargetRecalculationReport report =
          await service.recalculateDay(widget.date);
      FoodDataRefreshBus.publishManualRefresh(widget.date);
      ref.invalidate(profileSettingsRevisionProvider);
      if (!mounted) return;
      final String message = report.updatedDays == 1
          ? 'Target e valori della giornata sincronizzati.'
          : 'Nessuna giornata da sincronizzare.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Sincronizzazione non completata: $error')),
        );
      rethrow;
    } finally {
      _refreshing = false;
    }
  }
}
