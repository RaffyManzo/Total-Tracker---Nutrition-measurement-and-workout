import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({
    required this.sessionId,
    super.key,
  });

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final MockWorkoutSession? session =
        MockTrackingCatalog.sessionById(sessionId);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Sessione non trovata')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio sessione')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(session.title,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('${session.dateLabel} · ${session.status}'),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: MockMetricTile(
                  label: 'Durata',
                  value: '${session.durationMinutes} min',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: MockMetricTile(
                  label: 'Battito medio',
                  value: '${session.averageHeartRate} bpm',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          MockMetricTile(
            label: 'Calorie attive stimate',
            value: '${session.estimatedKcal.toStringAsFixed(0)} kcal',
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Esercizi'),
          const SizedBox(height: AppSpacing.md),
          ...session.exercises.map(
            (MockSessionExercise exercise) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TtAppCard(
                child: Row(
                  children: <Widget>[
                    Icon(
                      exercise.completed
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: Theme.of(context).colorScheme.primary,
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
                          Text('${exercise.mode} · ${exercise.summary}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (session.notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            TtAppCard(child: Text(session.notes)),
          ],
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: session.status == 'Pianificata'
                ? 'Avvia sessione mock'
                : 'Modifica sessione',
            icon: session.status == 'Pianificata'
                ? Icons.play_arrow_rounded
                : Icons.edit_outlined,
            onPressed: () => context.push('/forms/session'),
          ),
        ],
      ),
    );
  }
}
