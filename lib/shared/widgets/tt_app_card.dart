import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_shadows.dart';
import '../../app/theme/app_spacing.dart';

class TtAppCard extends StatelessWidget {
  const TtAppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;
    final Color resolvedBackground =
        backgroundColor ?? AppColors.surface(brightness);
    final Color resolvedBorder = borderColor ?? AppColors.border(brightness);

    final Widget materialCard = Material(
      color: resolvedBackground,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadii.card,
          border: Border.all(color: resolvedBorder),
          boxShadow: AppShadows.card(brightness),
        ),
        child: materialCard,
      ),
    );
  }
}
