import 'package:flutter/material.dart';

import '../../../../../app/theme/app_spacing.dart';
import '../../../../../shared/widgets/tt_app_card.dart';
import '../../domain/mock_exercise.dart';

class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    required this.exercise,
    required this.onTap,
    super.key,
  });

  final MockExercise exercise;
  final VoidCallback onTap;

  IconData get icon {
    switch (exercise.mode) {
      case 'treadmill':
        return Icons.directions_run_rounded;
      case 'activity':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  String get modeLabel {
    switch (exercise.mode) {
      case 'treadmill':
        return 'Treadmill';
      case 'activity':
        return 'AttivitÃ ';
      default:
        return 'Palestra';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  modeLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  exercise.primaryMuscles.join(', '),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
