import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sessioni')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/session'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuova sessione'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: MockTrackingCatalog.sessions
            .map(
              (MockWorkoutSession session) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: MockSectionCard(
                  title: session.title,
                  subtitle:
                      '${session.dateLabel} · ${session.durationMinutes} min · '
                      '${session.exercises.length} esercizi',
                  icon: Icons.history_rounded,
                  onTap: () => context.push('/sessions/${session.id}'),
                  trailing: MockStatusChip(label: session.status),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
