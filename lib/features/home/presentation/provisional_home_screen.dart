import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_section_header.dart';

class ProvisionalHomeScreen extends StatelessWidget {
  const ProvisionalHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Tracker'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Anteprima componenti',
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
            'Ciao Raffaele',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Home provvisoria per navigare in tutte le sezioni mock.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Archivi principali'),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.restaurant_menu_rounded,
            title: 'Ingredienti',
            subtitle: 'Archivio, dettaglio, barcode e inserimento.',
            onTap: () => context.push('/ingredients'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.fitness_center_rounded,
            title: 'Esercizi',
            subtitle: 'Archivio, modalità, muscoli e media.',
            onTap: () => context.push('/exercises'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Tracking completo'),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.dashboard_customize_outlined,
            title: 'Apri area tracking',
            subtitle:
                'Diario, pasti, ricette, misurazioni, routine, schede e sessioni.',
            onTap: () => context.push('/tracking'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.calendar_today_rounded,
            title: 'Diario giornaliero',
            subtitle: 'Target, calorie, peso, passi, acqua e sonno.',
            onTap: () => context.push('/diary'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.lunch_dining_rounded,
            title: 'Pasti e ricette',
            subtitle: 'Composizione pasti e preparazioni riutilizzabili.',
            onTap: () => context.push('/meals'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Misurazioni',
            subtitle: 'Bilancia e metro.',
            onTap: () => context.push('/measurements'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.repeat_rounded,
            title: 'Routine e schede',
            subtitle: 'Template e programmazione degli allenamenti.',
            onTap: () => context.push('/routines'),
          ),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.history_rounded,
            title: 'Sessioni',
            subtitle: 'Storico e registrazione degli allenamenti.',
            onTap: () => context.push('/sessions'),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtSectionHeader(title: 'Strumenti'),
          const SizedBox(height: AppSpacing.md),
          _HomeFeatureCard(
            icon: Icons.palette_outlined,
            title: 'Anteprima UI',
            subtitle: 'Componenti condivisi e design system.',
            onTap: () => context.push('/ui-preview'),
          ),
          const SizedBox(height: AppSpacing.md),
          const TtAppCard(
            child: Text(
              'Tutte le schermate di questa fase usano dati mock. '
              'Le 23 entità ObjectBox sono già presenti, ma il collegamento '
              'tra UI e repository verrà implementato nella fase successiva.',
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
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
            radius: 31,
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
