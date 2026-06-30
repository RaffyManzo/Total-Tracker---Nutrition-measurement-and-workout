import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';

class WorkoutPlanDetailScreen extends StatelessWidget {
  const WorkoutPlanDetailScreen({
    required this.planId,
    super.key,
  });

  final String planId;

  @override
  Widget build(BuildContext context) {
    final MockWorkoutPlan? plan = MockTrackingCatalog.planById(planId);
    if (plan == null) {
      return const Scaffold(body: Center(child: Text('Scheda non trovata')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio scheda')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(plan.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${plan.level} · ${plan.status}'),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Giorni'),
          const SizedBox(height: AppSpacing.md),
          ...plan.days.map(
            (MockPlanDay day) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      day.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...day.exercises.map(
                      (String exercise) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(exercise)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TtAppCard(child: Text(plan.notes)),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica scheda',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/plan'),
          ),
        ],
      ),
    );
  }
}
