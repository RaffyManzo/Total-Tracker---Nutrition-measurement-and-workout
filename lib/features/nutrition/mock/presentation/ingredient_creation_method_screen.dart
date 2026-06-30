import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_section_header.dart';

class IngredientCreationMethodScreen extends StatelessWidget {
  const IngredientCreationMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo ingrediente')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: <Widget>[
          const TtSectionHeader(
            title: 'Come vuoi aggiungerlo?',
            subtitle:
                'Scegli una modalitÃ . Tutti i dati potranno essere verificati prima del salvataggio.',
          ),
          const SizedBox(height: AppSpacing.xl),
          _CreationMethodCard(
            icon: Icons.qr_code_scanner_rounded,
            title: 'Scansiona barcode',
            description:
                'Leggi il codice e simula la ricerca su Open Food Facts.',
            onTap: () => context.push('/ingredients/new/barcode'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CreationMethodCard(
            icon: Icons.cloud_outlined,
            title: 'Cerca online',
            description:
                'Cerca per nome o marca e importa un risultato verificato.',
            onTap: () => context.push('/ingredients/search-online'),
          ),
          const SizedBox(height: AppSpacing.md),
          _CreationMethodCard(
            icon: Icons.edit_note_rounded,
            title: 'Inserimento manuale',
            description: 'Compila anagrafica, origine e valori nutrizionali.',
            onTap: () => context.push('/ingredients/new/manual'),
          ),
        ],
      ),
    );
  }
}

class _CreationMethodCard extends StatelessWidget {
  const _CreationMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
