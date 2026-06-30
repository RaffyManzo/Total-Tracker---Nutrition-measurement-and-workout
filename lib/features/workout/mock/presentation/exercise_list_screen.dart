import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_filter_chip.dart';
import '../../../../shared/widgets/tt_search_field.dart';
import '../data/mock_exercise_catalog.dart';
import '../domain/mock_exercise.dart';
import 'widgets/exercise_card.dart';

class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  String query = '';
  String mode = 'Tutti';

  List<MockExercise> get visibleItems {
    final String normalized = query.trim().toLowerCase();

    return MockExerciseCatalog.items.where((MockExercise exercise) {
      final bool queryMatches = normalized.isEmpty ||
          exercise.name.toLowerCase().contains(normalized) ||
          exercise.primaryMuscles.any(
            (String muscle) => muscle.toLowerCase().contains(normalized),
          );

      final bool modeMatches = mode == 'Tutti' ||
          (mode == 'Palestra' && exercise.mode == 'gym') ||
          (mode == 'AttivitÃ ' && exercise.mode == 'activity') ||
          (mode == 'Treadmill' && exercise.mode == 'treadmill');

      return queryMatches && modeMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esercizi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/exercises/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: <Widget>[
          TtSearchField(
            hintText: 'Cerca esercizio o muscolo...',
            onChanged: (String value) {
              setState(() {
                query = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <String>[
                'Tutti',
                'Palestra',
                'AttivitÃ ',
                'Treadmill',
              ]
                  .map(
                    (String label) => Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: TtFilterChip(
                        label: label,
                        selected: mode == label,
                        onSelected: (_) {
                          setState(() {
                            mode = label;
                          });
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...visibleItems.map(
            (MockExercise exercise) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: ExerciseCard(
                exercise: exercise,
                onTap: () => context.push('/exercises/${exercise.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
