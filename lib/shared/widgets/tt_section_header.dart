import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

class TtSectionHeader extends StatelessWidget {
  const TtSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.titleLarge,
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  style: textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        if (action != null) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          action!,
        ],
      ],
    );
  }
}
