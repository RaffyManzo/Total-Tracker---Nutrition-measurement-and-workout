import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class MeasurementsScreen extends StatelessWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Misurazioni')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          const TtSectionHeader(
            title: 'Bilancia',
            action: Icon(Icons.monitor_weight_outlined),
          ),
          const SizedBox(height: AppSpacing.md),
          ...MockTrackingCatalog.scaleMeasurements.map(
            (MockScaleMeasurement value) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MockSectionCard(
                title: '${value.weightKg.toStringAsFixed(2)} kg',
                subtitle:
                    '${value.dateLabel} · BF ${value.bodyFatPercent.toStringAsFixed(1)}% · BMI ${value.bmi.toStringAsFixed(1)}',
                icon: Icons.monitor_weight_outlined,
                onTap: () => context.push('/measurements/scale/${value.id}'),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/forms/scale'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuova misurazione bilancia'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(
            title: 'Metro',
            action: Icon(Icons.straighten_rounded),
          ),
          const SizedBox(height: AppSpacing.md),
          ...MockTrackingCatalog.tapeMeasurements.map(
            (MockTapeMeasurement value) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: MockSectionCard(
                title: 'Misure corporee',
                subtitle: '${value.dateLabel} · ${value.entries.length} misure',
                icon: Icons.straighten_rounded,
                onTap: () => context.push('/measurements/tape/${value.id}'),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => context.push('/forms/tape'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuova misurazione con metro'),
          ),
        ],
      ),
    );
  }
}
