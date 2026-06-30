import 'package:flutter/material.dart';

class TtSearchField extends StatelessWidget {
  const TtSearchField({
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onFilterPressed,
    this.autofocus = false,
    super.key,
  });

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterPressed;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: onFilterPressed == null
            ? null
            : IconButton(
                tooltip: 'Filtri',
                onPressed: onFilterPressed,
                icon: const Icon(Icons.tune_rounded),
              ),
      ),
    );
  }
}
