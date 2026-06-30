import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_section_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Anteprima UI',
            onPressed: () => context.push('/ui-preview'),
            icon: const Icon(Icons.palette_outlined),
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
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Dati persistenti, hub essenziali e navigazione reale.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Aree principali'),
          const SizedBox(height: AppSpacing.md),
          _HubCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Alimentazione e monitoraggio',
            subtitle: 'Giorni, pasti, ricette, ingredienti e settimana.',
            onTap: () => context.push('/food'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HubCard(
            icon: Icons.fitness_center_rounded,
            title: 'Allenamento',
            subtitle: 'Predisposto per le calorie workout, UI in arrivo.',
            onTap: () => context.push('/workout'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Collegamenti'),
          const SizedBox(height: AppSpacing.md),
          _HubCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Misurazioni',
            subtitle: 'Bilancia e metro collegati a ObjectBox.',
            onTap: () => context.push('/measurements'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HubCard(
            icon: Icons.view_week_outlined,
            title: 'Schede allenamento',
            subtitle: 'Disabilitate nella 0.1, già previste nel modello.',
            onTap: () => context.push('/workout/plans'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HubCard(
            icon: Icons.palette_outlined,
            title: 'Anteprima UI',
            subtitle: 'Design system verde/grigio e componenti condivisi.',
            onTap: () => context.push('/ui-preview'),
          ),
        ],
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TtAppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
