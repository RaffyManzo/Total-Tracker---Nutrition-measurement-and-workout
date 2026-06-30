import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import 'widgets/mock_tracking_widgets.dart';

class TrackingHubScreen extends StatelessWidget {
  const TrackingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          const TtSectionHeader(
            title: 'Diario e pianificazione',
            subtitle:
                'Mock delle entità ObjectBox appena aggiunte, con dati locali.',
          ),
          const SizedBox(height: AppSpacing.xl),
          MockSectionCard(
            title: 'Diario giornaliero',
            subtitle: 'Calorie, attività, peso, acqua, sonno e passi.',
            icon: Icons.calendar_today_rounded,
            onTap: () => context.push('/diary'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Pasti',
            subtitle: 'Pasti standard, liberi e contributi nutrizionali.',
            icon: Icons.lunch_dining_rounded,
            onTap: () => context.push('/meals'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Ricette',
            subtitle: 'Ingredienti, passaggi, rese e valori nutrizionali.',
            icon: Icons.menu_book_rounded,
            onTap: () => context.push('/recipes'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Misurazioni',
            subtitle: 'Bilancia e misure con metro.',
            icon: Icons.monitor_weight_outlined,
            onTap: () => context.push('/measurements'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Routine',
            subtitle: 'Template riutilizzabili per gli allenamenti.',
            icon: Icons.repeat_rounded,
            onTap: () => context.push('/routines'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Schede',
            subtitle: 'Giorni, esercizi e prescrizioni pianificate.',
            icon: Icons.view_week_outlined,
            onTap: () => context.push('/plans'),
          ),
          const SizedBox(height: AppSpacing.md),
          MockSectionCard(
            title: 'Sessioni',
            subtitle: 'Storico e registrazione delle sessioni reali.',
            icon: Icons.history_rounded,
            onTap: () => context.push('/sessions'),
          ),
        ],
      ),
    );
  }
}
