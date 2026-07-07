import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/tt_global_nav_fab.dart';

class ProfileSettingsHubScreen extends StatelessWidget {
  const ProfileSettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = <_SettingsSectionCardData>[
      _SettingsSectionCardData(
        code: 'personal',
        title: l10n.personalData,
        subtitle: l10n.personalDataSubtitle,
        icon: Icons.badge_outlined,
        accent: const Color(0xFF4F46E5),
      ),
      _SettingsSectionCardData(
        code: 'target_activity',
        title: l10n.targetAndActivity,
        subtitle: l10n.targetAndActivitySubtitle,
        icon: Icons.local_fire_department_outlined,
        accent: const Color(0xFFEA580C),
      ),
      _SettingsSectionCardData(
        code: 'meals',
        title: l10n.mealsAndMacros,
        subtitle: l10n.mealsAndMacrosSubtitle,
        icon: Icons.restaurant_menu_outlined,
        accent: const Color(0xFF059669),
      ),
      _SettingsSectionCardData(
        code: 'navigation',
        title: l10n.navigation,
        subtitle: l10n.navigationSubtitle,
        icon: Icons.navigation_outlined,
        accent: const Color(0xFF0F766E),
        directRoute: '/settings/navigation',
      ),
      _SettingsSectionCardData(
        code: 'notifications',
        title: l10n.notifications,
        subtitle: l10n.notificationsSubtitle,
        icon: Icons.notifications_outlined,
        accent: const Color(0xFFB45309),
        directRoute: '/settings/notifications',
      ),
      _SettingsSectionCardData(
        code: 'device_permissions',
        title: l10n.devicePermissions,
        subtitle: l10n.devicePermissionsSubtitle,
        icon: Icons.admin_panel_settings_outlined,
        accent: const Color(0xFF7C3AED),
        directRoute: '/settings/device-permissions',
      ),
      _SettingsSectionCardData(
        code: 'food_services',
        title: l10n.onlineFoodSources,
        subtitle: l10n.onlineFoodSourcesSubtitle,
        icon: Icons.cloud_outlined,
        accent: const Color(0xFF2563EB),
        directRoute: '/settings/food-services',
      ),
      const _SettingsSectionCardData(
        code: 'synchronization',
        title: 'Sincronizzazione',
        subtitle: 'Ricalcola lo storico o forza l’aggiornamento odierno.',
        icon: Icons.sync_rounded,
        accent: Color(0xFF0891B2),
        directRoute: '/settings/synchronization',
      ),
      const _SettingsSectionCardData(
        code: 'calculation_info',
        title: 'Info calcolo',
        subtitle: 'Formule, fallback, range, affidabilità e bibliografia.',
        icon: Icons.menu_book_outlined,
        accent: Color(0xFF6366F1),
        directRoute: '/settings/calculation-info',
      ),
      _SettingsSectionCardData(
        code: 'transfer',
        title: l10n.transfer,
        subtitle: l10n.transferSubtitle,
        icon: Icons.import_export_rounded,
        accent: const Color(0xFF0284C7),
        directRoute: '/settings/transfer',
      ),
      _SettingsSectionCardData(
        code: 'app',
        title: l10n.appAndData,
        subtitle: l10n.appAndDataSubtitle,
        icon: Icons.settings_outlined,
        accent: const Color(0xFF7C3AED),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      bottomNavigationBar: const TtFoodBottomNavBar(
        activeItem: TtFoodNavItem.settings,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsSections,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.settingsIntro),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...[
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
                  queryParameters: {'section': section.code},
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
            children: [
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
                  children: [
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
