import 'package:flutter/material.dart';

class TtFilterChip extends StatelessWidget {
  const TtFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 17,
            ),
      label: Text(label),
      showCheckmark: false,
    );
  }
}
