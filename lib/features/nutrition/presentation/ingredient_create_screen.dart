import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/ingredient_entity.dart';
import '../domain/nutrition_codes.dart';

class IngredientCreateScreen extends ConsumerStatefulWidget {
  const IngredientCreateScreen({super.key});

  @override
  ConsumerState<IngredientCreateScreen> createState() =>
      _IngredientCreateScreenState();
}

class _IngredientCreateScreenState
    extends ConsumerState<IngredientCreateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _brand = TextEditingController();
  final TextEditingController _barcode = TextEditingController();
  final TextEditingController _image = TextEditingController();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _categories = TextEditingController();
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _protein = TextEditingController();
  final TextEditingController _carbs = TextEditingController();
  final TextEditingController _fat = TextEditingController();
  final TextEditingController _fiber = TextEditingController();
  final TextEditingController _sugar = TextEditingController();
  final TextEditingController _salt = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _brand,
      _barcode,
      _image,
      _quantity,
      _categories,
      _notes,
      _kcal,
      _protein,
      _carbs,
      _fat,
      _fiber,
      _sugar,
      _salt,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _number(TextEditingController controller) {
    return double.tryParse(
          controller.text.trim().replaceAll(',', '.'),
        ) ??
        0;
  }

  double? _optionalNumber(TextEditingController controller) {
    final String text = controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final IngredientEntity ingredient =
          ref.read(ingredientRepositoryProvider).save(
                IngredientEntity(
                  uuid: '',
                  name: _name.text.trim(),
                  brand: _brand.text.trim(),
                  barcode: _barcode.text.trim(),
                  packageQuantity: _optionalNumber(_quantity),
                  sourceTypeCode: IngredientSourceTypeCodes.manual,
                  sourceName: 'Personale',
                  imageUrl: _image.text.trim(),
                  categories: _categories.text.trim(),
                  notes: _notes.text.trim(),
                  nutritionReferenceAmount: 100,
                  nutritionReferenceUnitCode: NutritionUnitCodes.grams,
                  kcalPerReference: _number(_kcal),
                  proteinPerReference: _number(_protein),
                  carbsPerReference: _number(_carbs),
                  fatPerReference: _number(_fat),
                  fiberPerReference: _number(_fiber),
                  sugarPerReference: _number(_sugar),
                  saltPerReference: _number(_salt),
                  createdAtEpochMs: 0,
                  updatedAtEpochMs: 0,
                ),
              );

      if (!mounted) return;
      context.pop(ingredient);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (String? value) {
          if (required && (value?.trim().isEmpty ?? true)) {
            return 'Campo obbligatorio';
          }
          if (numeric &&
              (value?.trim().isNotEmpty ?? false) &&
              double.tryParse(value!.trim().replaceAll(',', '.')) == null) {
            return 'Valore numerico non valido';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo ingrediente')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _field(_name, 'Nome', required: true),
            _field(_brand, 'Brand'),
            _field(_barcode, 'Barcode'),
            _field(_image, 'URL o percorso immagine'),
            _field(_quantity, 'Quantità confezione', numeric: true),
            _field(_categories, 'Categorie'),
            const SizedBox(height: 8),
            Text(
              'Valori nutrizionali per 100 g',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _field(_kcal, 'Calorie', numeric: true),
            _field(_protein, 'Proteine (g)', numeric: true),
            _field(_carbs, 'Carboidrati (g)', numeric: true),
            _field(_fat, 'Grassi (g)', numeric: true),
            _field(_fiber, 'Fibre (g)', numeric: true),
            _field(_sugar, 'Zuccheri (g)', numeric: true),
            _field(_salt, 'Sale (g)', numeric: true),
            _field(_notes, 'Note', maxLines: 4),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Salva ingrediente'),
            ),
          ],
        ),
      ),
    );
  }
}
