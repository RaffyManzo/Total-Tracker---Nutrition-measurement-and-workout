import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Routine')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/routine'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova routine'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: MockTrackingCatalog.routines
            .map(
              (MockRoutine routine) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MockSectionCard(
                  title: routine.name,
                  subtitle:
                      '${routine.goal} · ${routine.exercises.length} esercizi · ${routine.summary}',
                  icon: Icons.repeat_rounded,
                  onTap: () => context.push('/routines/${routine.id}'),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
