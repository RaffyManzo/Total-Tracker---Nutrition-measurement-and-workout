import 'package:flutter/material.dart';

class TtPrimaryButton extends StatelessWidget {
  const TtPrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? resolvedOnPressed = isLoading ? null : onPressed;

    final Widget labelWidget = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : Text(label);

    final Widget button = icon == null || isLoading
        ? FilledButton(
            onPressed: resolvedOnPressed,
            child: labelWidget,
          )
        : FilledButton.icon(
            onPressed: resolvedOnPressed,
            icon: Icon(icon),
            label: labelWidget,
          );

    if (!expanded) {
      return button;
    }

    return SizedBox(
      width: double.infinity,
      child: button,
    );
  }
}
