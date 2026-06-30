import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/objectbox_providers.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_search_field.dart';
import '../data/entities/exercise_entity.dart';
import '../data/entities/workout_tracking_entities.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/workout_session_repository.dart';

final FutureProvider<WorkoutHubData> workoutHubProvider =
    FutureProvider<WorkoutHubData>((Ref ref) async {
  final exerciseRepository = ref.watch(exerciseRepositoryProvider);
  final routineRepository = ref.watch(routineRepositoryProvider);
  final planRepository = ref.watch(workoutPlanRepositoryProvider);
  final sessionRepository = ref.watch(workoutSessionRepositoryProvider);
  return WorkoutHubData(
    exercises: exerciseRepository.getAllActive(),
    routines: routineRepository.getAllActive(),
    plans: planRepository.getAllActive(),
    sessions: sessionRepository.getAllActive(),
  );
});

class WorkoutHubData {
  const WorkoutHubData({
    required this.exercises,
    required this.routines,
    required this.plans,
    required this.sessions,
  });

  final List<ExerciseEntity> exercises;
  final List<RoutineEntity> routines;
  final List<WorkoutPlanEntity> plans;
  final List<WorkoutSessionEntity> sessions;

  WorkoutSessionEntity? get latestSession {
    return sessions.isEmpty ? null : sessions.first;
  }
}

class WorkoutHubScreen extends ConsumerWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const WorkoutDisabledScreen();
  }
}

class WorkoutDisabledScreen extends StatelessWidget {
  const WorkoutDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Allenamento')),
      floatingActionButton: const TtGlobalNavFab(),
      body: ListView(
        padding: _screenPadding,
        children: <Widget>[
          Text(
            'Allenamento in preparazione',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'La UI allenamento è disabilitata in questa versione. Le sessioni completed già presenti in ObjectBox restano disponibili per il calcolo calorie del Food Plan.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtAppCard(
            child: Text(
              'Versione 0.1: focus su alimentazione, pasti, ingredienti, ricette e misurazioni.',
            ),
          ),
        ],
      ),
    );
  }
}

class PersistentExerciseListScreen extends ConsumerWidget {
  const PersistentExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(workoutHubProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Esercizi')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workoutHubProvider),
        ),
        data: (WorkoutHubData data) {
          if (data.exercises.isEmpty) {
            return const _EmptyList(
              message:
                  'Nessun esercizio ObjectBox. Il catalogo mock non alimenta questa lista.',
            );
          }
          final exerciseRepository = ref.watch(exerciseRepositoryProvider);
          return ListView.separated(
            padding: _screenPadding,
            itemCount: data.exercises.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final ExerciseEntity exercise = data.exercises[index];
              final primary = exerciseRepository.getPrimaryMuscles(exercise.id);
              final secondary =
                  exerciseRepository.getSecondaryMuscles(exercise.id);
              return TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${exercise.exerciseModeCode} - recupero ${exercise.defaultRestSec ?? 0}s',
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Primari: ${primary.map((item) => item.displayNameIt).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Secondari: ${secondary.map((item) => item.displayNameIt).join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PersistentRoutinesScreen extends ConsumerWidget {
  const PersistentRoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(workoutHubProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Routine')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workoutHubProvider),
        ),
        data: (WorkoutHubData data) {
          if (data.routines.isEmpty) {
            return const _EmptyList(
              message: 'Nessuna routine persistente.',
            );
          }
          final repository = ref.watch(routineRepositoryProvider);
          return ListView.separated(
            padding: _screenPadding,
            itemCount: data.routines.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final RoutineEntity routine = data.routines[index];
              final RoutineDetails? details = repository.getDetails(routine.id);
              return TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(routine.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(routine.goal.isEmpty ? routine.summary : routine.goal),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${details?.exercises.length ?? 0} esercizi',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class WorkoutPlansScreen extends ConsumerStatefulWidget {
  const WorkoutPlansScreen({super.key});

  @override
  ConsumerState<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends ConsumerState<WorkoutPlansScreen> {
  final TextEditingController _search = TextEditingController();
  String _level = '';
  String _status = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(workoutHubProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Schede')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workoutHubProvider),
        ),
        data: (WorkoutHubData data) {
          final repository = ref.watch(workoutPlanRepositoryProvider);
          final String query = _search.text.toLowerCase().trim();
          final List<WorkoutPlanEntity> plans = data.plans.where(
            (WorkoutPlanEntity plan) {
              final bool matchesQuery =
                  query.isEmpty || plan.name.toLowerCase().contains(query);
              final bool matchesLevel =
                  _level.isEmpty || plan.levelCode == _level;
              final bool matchesStatus =
                  _status.isEmpty || plan.statusCode == _status;
              return matchesQuery && matchesLevel && matchesStatus;
            },
          ).toList();

          return ListView(
            padding: _screenPadding,
            children: <Widget>[
              TtSearchField(
                controller: _search,
                hintText: 'Cerca scheda',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  _FilterChoice(
                    label: 'Tutti i livelli',
                    selected: _level.isEmpty,
                    onSelected: () => setState(() => _level = ''),
                  ),
                  for (final String level in <String>[
                    'base',
                    'intermedio',
                    'avanzato'
                  ])
                    _FilterChoice(
                      label: level,
                      selected: _level == level,
                      onSelected: () => setState(() => _level = level),
                    ),
                  _FilterChoice(
                    label: 'Tutti gli stati',
                    selected: _status.isEmpty,
                    onSelected: () => setState(() => _status = ''),
                  ),
                  for (final String status in <String>[
                    'draft',
                    'active',
                    'archived'
                  ])
                    _FilterChoice(
                      label: status,
                      selected: _status == status,
                      onSelected: () => setState(() => _status = status),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              if (plans.isEmpty)
                const TtAppCard(child: Text('Nessuna scheda persistente.'))
              else
                for (final WorkoutPlanEntity plan in plans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: TtAppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(plan.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text('${plan.levelCode} - ${plan.statusCode}'),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '${repository.getDays(plan.id).length} giornate - '
                            '${repository.exerciseCountForPlan(plan.id)} esercizi',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class WorkoutSessionsScreen extends ConsumerWidget {
  const WorkoutSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(workoutHubProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sessioni')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ref.read(workoutSessionRepositoryProvider).save(
                ref
                    .read(workoutSessionRepositoryProvider)
                    .createEmpty(_dateKey(DateTime.now())),
              );
          ref.invalidate(workoutHubProvider);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(workoutHubProvider),
        ),
        data: (WorkoutHubData data) {
          if (data.sessions.isEmpty) {
            return const _EmptyList(message: 'Nessuna sessione persistente.');
          }
          final WorkoutSessionRepository repository =
              ref.watch(workoutSessionRepositoryProvider);
          return ListView.separated(
            padding: _screenPadding,
            itemCount: data.sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final WorkoutSessionEntity session = data.sessions[index];
              final WorkoutSessionDetails? details =
                  repository.getDetails(session.id);
              return TtAppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(session.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text('${session.sessionDateKey} - ${session.statusCode}'),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${details?.exercises.length ?? 0} esercizi - '
                      '${session.durationMinutes ?? 0} min - '
                      '${session.estimatedKcalBurned?.round() ?? 0} kcal',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[
        TtAppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Errore', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(error.toString()),
              const SizedBox(height: AppSpacing.md),
              TtPrimaryButton(
                label: 'Riprova',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _screenPadding,
      children: <Widget>[TtAppCard(child: Text(message))],
    );
  }
}

EdgeInsets get _screenPadding {
  return const EdgeInsets.fromLTRB(
    AppSpacing.screenHorizontal,
    AppSpacing.screenVertical,
    AppSpacing.screenHorizontal,
    AppSpacing.xxxl,
  );
}

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
