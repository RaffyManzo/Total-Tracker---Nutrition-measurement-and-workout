import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class RoutineDetailScreen extends StatelessWidget {
  const RoutineDetailScreen({
    required this.routineId,
    super.key,
  });

  final String routineId;

  @override
  Widget build(BuildContext context) {
    final MockRoutine? routine = MockTrackingCatalog.routineById(routineId);
    if (routine == null) {
      return const Scaffold(body: Center(child: Text('Routine non trovata')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio routine')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(routine.name, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${routine.goal} · ${routine.summary}'),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Esercizi'),
          const SizedBox(height: AppSpacing.md),
          ...routine.exercises.map(
            (MockRoutineExercise exercise) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    MockInfoRow(label: 'Modalità', value: exercise.mode),
                    const Divider(height: AppSpacing.xl),
                    MockInfoRow(
                      label: 'Serie',
                      value: '${exercise.sets} × ${exercise.repetitions}',
                    ),
                    const Divider(height: AppSpacing.xl),
                    MockInfoRow(
                      label: 'Recupero',
                      value: exercise.restSeconds == 0
                          ? 'Non previsto'
                          : '${exercise.restSeconds} s',
                    ),
                    const Divider(height: AppSpacing.xl),
                    MockInfoRow(
                      label: 'Muscoli',
                      value: exercise.primaryMuscles.join(', '),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(child: Text(routine.notes)),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica routine',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/routine'),
          ),
        ],
      ),
    );
  }
}
