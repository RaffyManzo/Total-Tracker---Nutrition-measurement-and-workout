import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/tt_global_nav_fab.dart';

class ProfileSettingsHubScreen extends StatelessWidget {
  const ProfileSettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_SettingsSectionCardData>[
      const _SettingsSectionCardData(
        code: 'personal',
        title: 'Dati personali',
        subtitle: 'Nome, et\u00E0, sesso, altezza e peso iniziale.',
        icon: Icons.badge_outlined,
        accent: Color(0xFF4F46E5),
      ),
      const _SettingsSectionCardData(
        code: 'target_activity',
        title: 'Target e attivit\u00E0',
        subtitle:
            'Target calorico, sorgenti attivit\u00E0 e dettaglio dei calcoli.',
        icon: Icons.local_fire_department_outlined,
        accent: Color(0xFFEA580C),
      ),
      const _SettingsSectionCardData(
        code: 'meals',
        title: 'Pasti e macro',
        subtitle: 'Quote per pasto, macronutrienti, fibre e zuccheri.',
        icon: Icons.restaurant_menu_outlined,
        accent: Color(0xFF059669),
      ),
      const _SettingsSectionCardData(
        code: 'opennutrition',
        title: 'OpenNutrition',
        subtitle: 'Fonte complementare, stato della migrazione e attribuzioni.',
        icon: Icons.storage,
        accent: Color(0xFF0F766E),
        directRoute: '/settings/opennutrition',
      ),
      const _SettingsSectionCardData(
        code: 'navigation',
        title: 'Navigazione',
        subtitle: 'Dashboard iniziale e comportamento del pulsante Indietro.',
        icon: Icons.navigation_outlined,
        accent: Color(0xFF0F766E),
        directRoute: '/settings/navigation',
      ),
      const _SettingsSectionCardData(
        code: 'notifications',
        title: 'Notifiche',
        subtitle:
            'Reminder pasti, peso, misurazioni e operazioni in background.',
        icon: Icons.notifications_outlined,
        accent: Color(0xFFB45309),
        directRoute: '/settings/notifications',
      ),
      const _SettingsSectionCardData(
        code: 'device_permissions',
        title: 'Permessi dispositivo',
        subtitle:
            'Stato reale di notifiche, fotocamera e ottimizzazione batteria.',
        icon: Icons.admin_panel_settings_outlined,
        accent: Color(0xFF7C3AED),
        directRoute: '/settings/device-permissions',
      ),
      const _SettingsSectionCardData(
        code: 'food_services',
        title: 'Servizi alimentari online',
        subtitle: 'Abilita o disabilita Open Food Facts e i relativi pulsanti.',
        icon: Icons.cloud_outlined,
        accent: Color(0xFF2563EB),
        directRoute: '/settings/food-services',
      ),
      const _SettingsSectionCardData(
        code: 'transfer',
        title: 'Import / Export',
        subtitle: 'Archivi .totaltracker, cartella export e import selettivo.',
        icon: Icons.import_export_rounded,
        accent: Color(0xFF0284C7),
        directRoute: '/settings/transfer',
      ),
      const _SettingsSectionCardData(
        code: 'app',
        title: 'App e dati',
        subtitle: 'Tema, lingua, versione, directory e dati locali.',
        icon: Icons.settings_outlined,
        accent: Color(0xFF7C3AED),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      bottomNavigationBar: const TtFoodBottomNavBar(
        activeItem: TtFoodNavItem.settings,
      ),
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
                    'Ogni scheda apre una pagina dedicata. Le chiavi di navigazione '
                    'sono codici ASCII stabili e non dipendono dal testo visualizzato.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...<Widget>[
            _SettingsSectionCard(
              data: section,
              onTap: () {
                final directRoute = section.directRoute;
                if (directRoute != null) {
                  context.push(directRoute);
                  return;
                }
                final location = Uri(
                  path: '/settings/section',
                  queryParameters: <String, String>{'section': section.code},
                ).toString();
                context.push(location);
              },
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
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.directRoute,
  });

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? directRoute;
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
