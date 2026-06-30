import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({
    required this.dayId,
    super.key,
  });

  final String dayId;

  @override
  Widget build(BuildContext context) {
    final MockDayRecord? day = MockTrackingCatalog.dayById(dayId);

    if (day == null) {
      return const Scaffold(body: Center(child: Text('Giornata non trovata')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio giornata'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica',
            onPressed: () => context.push('/forms/day'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          Text(day.dateLabel,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(day.weekLabel, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Assunte',
                  value: '${day.caloriesIn.toStringAsFixed(0)} kcal',
                  icon: Icons.restaurant_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MockMetricTile(
                  label: 'Target',
                  value: '${day.targetKcal.toStringAsFixed(0)} kcal',
                  icon: Icons.flag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Attive',
                  value: '${day.activeKcal.toStringAsFixed(0)} kcal',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MockMetricTile(
                  label: 'Bilancio',
                  value:
                      '${day.balance >= 0 ? '+' : ''}${day.balance.toStringAsFixed(0)} kcal',
                  icon: Icons.balance_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Indicatori'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: <Widget>[
                MockInfoRow(label: 'Peso', value: '${day.weightKg} kg'),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'Passi', value: '${day.steps}'),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'Acqua', value: '${day.waterLiters} L'),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'Sonno', value: '${day.sleepHours} h'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Note'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(child: Text(day.notes)),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Apri pasti della giornata',
            icon: Icons.lunch_dining_outlined,
            onPressed: () => context.push('/meals'),
          ),
        ],
      ),
    );
  }
}
