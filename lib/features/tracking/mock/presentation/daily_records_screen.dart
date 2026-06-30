import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class DailyRecordsScreen extends StatelessWidget {
  const DailyRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diario giornaliero')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/forms/day'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo giorno'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          100,
        ),
        children: <Widget>[
          const TtSectionHeader(
            title: 'Giornate recenti',
            subtitle: 'Bilancio energetico e indicatori principali.',
          ),
          const SizedBox(height: AppSpacing.xl),
          ...MockTrackingCatalog.days.map(
            (MockDayRecord day) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MockSectionCard(
                title: day.dateLabel,
                subtitle:
                    '${day.caloriesIn.toStringAsFixed(0)} / ${day.targetKcal.toStringAsFixed(0)} kcal · '
                    '${day.steps} passi · ${day.weightKg.toStringAsFixed(2)} kg',
                icon: Icons.today_rounded,
                onTap: () => context.push('/diary/${day.id}'),
                trailing: MockStatusChip(
                  label: day.balance <= 0 ? 'In target' : 'Sopra target',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TtPrimaryButton(
            label: 'Aggiungi giornata',
            icon: Icons.add_rounded,
            onPressed: () => context.push('/forms/day'),
          ),
        ],
      ),
    );
  }
}
