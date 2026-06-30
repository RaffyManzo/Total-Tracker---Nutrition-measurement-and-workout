import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class WorkoutPlansScreen extends StatelessWidget {
  const WorkoutPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schede allenamento')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/plan'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova scheda'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: MockTrackingCatalog.plans
            .map(
              (MockWorkoutPlan plan) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MockSectionCard(
                  title: plan.name,
                  subtitle:
                      '${plan.level} · ${plan.days.length} giorni · ${plan.notes}',
                  icon: Icons.view_week_outlined,
                  onTap: () => context.push('/plans/${plan.id}'),
                  trailing: MockStatusChip(label: plan.status),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
