import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';
import '../domain/mock_ingredient.dart';

class IngredientManualFormScreen extends StatefulWidget {
  const IngredientManualFormScreen({
    this.initialIngredient,
    super.key,
  });

  final MockIngredient? initialIngredient;

  @override
  State<IngredientManualFormScreen> createState() =>
      _IngredientManualFormScreenState();
}

class _IngredientManualFormScreenState
    extends State<IngredientManualFormScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;
  String unit = 'g';
  String sourceType = 'manuale';

  @override
  void initState() {
    super.initState();
    final MockIngredient? ingredient = widget.initialIngredient;
    unit = ingredient?.unit ?? 'g';
    sourceType = ingredient?.sourceType ?? 'manuale';

    controllers = <String, TextEditingController>{
      'name': TextEditingController(text: ingredient?.name ?? ''),
      'brand': TextEditingController(text: ingredient?.brand ?? ''),
      'quantity': TextEditingController(text: ingredient?.quantity ?? ''),
      'barcode': TextEditingController(text: ingredient?.barcode ?? ''),
      'categories': TextEditingController(
        text: ingredient?.categories.join(', ') ?? '',
      ),
      'image': TextEditingController(text: ingredient?.imageUrl ?? ''),
      'sourceName': TextEditingController(
        text: ingredient?.sourceName ?? 'Inserimento manuale',
      ),
      'sourceUrl': TextEditingController(text: ingredient?.sourceUrl ?? ''),
      'kcal': TextEditingController(
        text: ingredient?.kcal100.toString() ?? '',
      ),
      'protein': TextEditingController(
        text: ingredient?.protein100.toString() ?? '',
      ),
      'carbs': TextEditingController(
        text: ingredient?.carbs100.toString() ?? '',
      ),
      'fat': TextEditingController(
        text: ingredient?.fat100.toString() ?? '',
      ),
      'fiber': TextEditingController(
        text: ingredient?.fiber100.toString() ?? '',
      ),
      'sugar': TextEditingController(
        text: ingredient?.sugar100.toString() ?? '',
      ),
      'salt': TextEditingController(
        text: ingredient?.salt100.toString() ?? '',
      ),
      'notes': TextEditingController(text: ingredient?.notes ?? ''),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Campo obbligatorio';
    }
    return null;
  }

  String? numericValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final double? parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null || parsed < 0) {
      return 'Inserisci un valore numerico non negativo';
    }
    return null;
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.initialIngredient == null
              ? 'Ingrediente salvato nella demo'
              : 'Ingrediente aggiornato nella demo',
        ),
      ),
    );
    context.go('/ingredients');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialIngredient == null
              ? 'Inserimento manuale'
              : 'Modifica ingrediente',
        ),
      ),
      body: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          children: <Widget>[
            const TtSectionHeader(
              title: 'Informazioni generali',
              subtitle: 'I campi seguono il modello previsto dal mock.',
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['name']!,
              label: 'Nome *',
              validator: requiredValidator,
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['brand']!,
              label: 'Marca',
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(
                      labelText: 'UnitÃƒÂ  base',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'g', child: Text('g')),
                      DropdownMenuItem(value: 'ml', child: Text('ml')),
                      DropdownMenuItem(
                        value: 'porzione',
                        child: Text('porzione'),
                      ),
                    ],
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          unit = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _field(
                    controller: controllers['quantity']!,
                    label: 'QuantitÃƒÂ  confezione',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['barcode']!,
              label: 'Barcode',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['categories']!,
              label: 'Categorie separate da virgola',
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['image']!,
              label: 'URL o percorso immagine',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Origine dei dati'),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: sourceType,
              decoration: const InputDecoration(labelText: 'Tipo origine'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(
                  value: 'manuale',
                  child: Text('Manuale'),
                ),
                DropdownMenuItem(
                  value: 'open_food_facts_barcode',
                  child: Text('Open Food Facts Ã‚Â· barcode'),
                ),
                DropdownMenuItem(
                  value: 'open_food_facts_search',
                  child: Text('Open Food Facts Ã‚Â· ricerca'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    sourceType = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['sourceName']!,
              label: 'Nome origine',
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['sourceUrl']!,
              label: 'URL origine',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(
              title: 'Valori per 100 g/ml',
              subtitle:
                  'Lascia vuoti i dati non disponibili. Non sono accettati valori negativi.',
            ),
            const SizedBox(height: AppSpacing.md),
            _numericField(controllers['kcal']!, 'Calorie (kcal)'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numericField(
                    controllers['protein']!,
                    'Proteine (g)',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _numericField(
                    controllers['carbs']!,
                    'Carboidrati (g)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numericField(
                    controllers['fat']!,
                    'Grassi (g)',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _numericField(
                    controllers['fiber']!,
                    'Fibre (g)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _numericField(
                    controllers['sugar']!,
                    'Zuccheri (g)',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _numericField(
                    controllers['salt']!,
                    'Sale (g)',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Note'),
            const SizedBox(height: AppSpacing.md),
            _field(
              controller: controllers['notes']!,
              label: 'Note facoltative',
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.xl),
            TtPrimaryButton(
              label: widget.initialIngredient == null
                  ? 'Salva ingrediente'
                  : 'Salva modifiche',
              icon: Icons.check_rounded,
              onPressed: save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _numericField(
    TextEditingController controller,
    String label,
  ) {
    return _field(
      controller: controller,
      label: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: numericValidator,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}
