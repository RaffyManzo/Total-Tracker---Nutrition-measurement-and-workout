import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileSettingsHubScreen extends StatelessWidget {
  const ProfileSettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_SettingsSectionCardData>[
      const _SettingsSectionCardData(
        title: 'Dati personali',
        subtitle: 'Nome, etÃ , sesso, altezza e peso iniziale.',
        icon: Icons.badge_outlined,
        accent: Color(0xFF4F46E5),
      ),
      const _SettingsSectionCardData(
        title: 'Target e attivitÃ ',
        subtitle: 'Target calorico, modalitÃ  adattiva e stime attivitÃ .',
        icon: Icons.local_fire_department_outlined,
        accent: Color(0xFFEA580C),
      ),
      const _SettingsSectionCardData(
        title: 'Pasti',
        subtitle: 'Quote per pasto, macro, fibre e zuccheri.',
        icon: Icons.restaurant_menu_outlined,
        accent: Color(0xFF059669),
      ),
      const _SettingsSectionCardData(
        title: 'Import / Export',
        subtitle: 'Archivi .totaltracker, cartella export e import selettivo.',
        icon: Icons.import_export_rounded,
        accent: Color(0xFF0284C7),
      ),
      const _SettingsSectionCardData(
        title: 'App',
        subtitle: 'Versione, spazio occupato e directory dati.',
        icon: Icons.info_outline_rounded,
        accent: Color(0xFF7C3AED),
      ),
      const _SettingsSectionCardData(
        title: 'Avvisi e promemoria',
        subtitle: 'Banner informativi e consigli di registrazione.',
        icon: Icons.notifications_active_outlined,
        accent: Color(0xFFDC2626),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text(
                    'Sezioni impostazioni',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Apri una sezione per consultare o modificare le impostazioni del profilo. '
                    'Le schermate di dettaglio restano quelle del progetto attuale, raggruppate '
                    'da questa pagina introduttiva piÃ¹ ordinata.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...<Widget>[
            _SettingsSectionCard(
              data: section,
              onTap: () =>
                  context.push('/settings/legacy?section=${section.title}'),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SettingsSectionCardData {
  const _SettingsSectionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({required this.data, required this.onTap});

  final _SettingsSectionCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(data.icon, color: data.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(data.subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
