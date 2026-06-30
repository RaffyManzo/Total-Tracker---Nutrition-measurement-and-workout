import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../data/mock_tracking_catalog.dart';
import '../domain/mock_tracking_models.dart';
import 'widgets/mock_tracking_widgets.dart';

class ScaleMeasurementDetailScreen extends StatelessWidget {
  const ScaleMeasurementDetailScreen({
    required this.measurementId,
    super.key,
  });

  final String measurementId;

  @override
  Widget build(BuildContext context) {
    final MockScaleMeasurement? value =
        MockTrackingCatalog.scaleById(measurementId);
    if (value == null) {
      return const Scaffold(
        body: Center(child: Text('Misurazione non trovata')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio bilancia')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(
            '${value.weightKg.toStringAsFixed(2)} kg',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(value.dateLabel),
          const SizedBox(height: AppSpacing.xl),
          TtAppCard(
            child: Column(
              children: <Widget>[
                MockInfoRow(
                  label: 'Massa grassa',
                  value: '${value.bodyFatPercent}%',
                ),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(
                  label: 'Massa muscolare',
                  value: '${value.muscleMassKg} kg',
                ),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(
                  label: 'Acqua corporea',
                  value: '${value.waterPercent}%',
                ),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'BMI', value: '${value.bmi}'),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'Dispositivo', value: value.device),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(
                  label: 'Affidabilità',
                  value: value.reliability,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica misurazione',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/scale'),
          ),
        ],
      ),
    );
  }
}

class TapeMeasurementDetailScreen extends StatelessWidget {
  const TapeMeasurementDetailScreen({
    required this.measurementId,
    super.key,
  });

  final String measurementId;

  @override
  Widget build(BuildContext context) {
    final MockTapeMeasurement? value =
        MockTrackingCatalog.tapeById(measurementId);
    if (value == null) {
      return const Scaffold(
        body: Center(child: Text('Misurazione non trovata')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio metro')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          Text(
            value.dateLabel,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          const TtSectionHeader(title: 'Misure'),
          const SizedBox(height: AppSpacing.md),
          TtAppCard(
            child: Column(
              children: value.entries.entries
                  .map(
                    (MapEntry<String, double> entry) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: MockInfoRow(
                        label: entry.key,
                        value: '${entry.value.toStringAsFixed(1)} cm',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TtAppCard(
            child: Column(
              children: <Widget>[
                MockInfoRow(
                  label: 'Affidabilità',
                  value: value.reliability,
                ),
                const Divider(height: AppSpacing.xl),
                MockInfoRow(label: 'Note', value: value.notes),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          TtPrimaryButton(
            label: 'Modifica misurazione',
            icon: Icons.edit_outlined,
            onPressed: () => context.push('/forms/tape'),
          ),
        ],
      ),
    );
  }
}
