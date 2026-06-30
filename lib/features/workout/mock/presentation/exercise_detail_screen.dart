import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_exercise_catalog.dart';
import '../domain/mock_exercise.dart';

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({
    required this.exerciseId,
    super.key,
  });

  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final MockExercise? exercise = MockExerciseCatalog.byId(exerciseId);

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Esercizio')),
        body: const Center(child: Text('Esercizio non trovato')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio esercizio'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Modifica',
            onPressed: () => context.push('/exercises/new', extra: exercise),
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
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: Icon(
              exercise.mode == 'treadmill'
                  ? Icons.directions_run_rounded
                  : exercise.mode == 'activity'
                      ? Icons.sports_soccer_rounded
                      : Icons.fitness_center_rounded,
              size: 84,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            exercise.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _modeLabel(exercise.mode),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Configurazione'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: <Widget>[
                _DetailRow(
                  label: 'Recupero predefinito',
                  value: exercise.defaultRestSeconds == 0
                      ? 'Non previsto'
                      : '${exercise.defaultRestSeconds} secondi',
                ),
                const Divider(height: AppSpacing.xl),
                _DetailRow(
                  label: 'Media',
                  value:
                      exercise.media.isEmpty ? 'Non presente' : exercise.media,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Muscoli'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Principali',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: exercise.primaryMuscles
                      .map((String muscle) => Chip(label: Text(muscle)))
                      .toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Secondari',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: exercise.secondaryMuscles
                      .map((String muscle) => Chip(label: Text(muscle)))
                      .toList(),
                ),
              ],
            ),
          ),
          if (exercise.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            TtAppCard(child: Text(exercise.notes)),
          ],
          const SizedBox(height: AppSpacing.sectionGap),
          TtPrimaryButton(
            label: 'Modifica esercizio',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/exercises/new', extra: exercise),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Archiviazione simulata nella versione mock',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archivia esercizio'),
            ),
          ),
        ],
      ),
    );
  }

  static String _modeLabel(String mode) {
    switch (mode) {
      case 'activity':
        return 'AttivitÃ ';
      case 'treadmill':
        return 'Treadmill';
      default:
        return 'Palestra';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
