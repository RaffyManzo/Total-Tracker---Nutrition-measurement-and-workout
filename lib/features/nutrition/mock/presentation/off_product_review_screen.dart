import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_primary_button.dart';
import '../../../../shared/widgets/tt_section_header.dart';

class OffProductReviewScreen extends StatefulWidget {
  const OffProductReviewScreen({super.key});

  @override
  State<OffProductReviewScreen> createState() => _OffProductReviewScreenState();
}

class _OffProductReviewScreenState extends State<OffProductReviewScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController name =
      TextEditingController(text: 'Yogurt Greco');
  final TextEditingController brand = TextEditingController(text: 'Mila');
  final TextEditingController quantity = TextEditingController(text: '150 g');
  final TextEditingController barcode =
      TextEditingController(text: '8001234567890');
  final TextEditingController categories =
      TextEditingController(text: 'Latticini, Yogurt');
  final TextEditingController kcal = TextEditingController(text: '62');
  final TextEditingController protein = TextEditingController(text: '10.0');
  final TextEditingController carbs = TextEditingController(text: '3.6');
  final TextEditingController fat = TextEditingController(text: '0.2');
  final TextEditingController fiber = TextEditingController(text: '0');
  final TextEditingController sugar = TextEditingController(text: '3.6');
  final TextEditingController salt = TextEditingController(text: '0.10');

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      name,
      brand,
      quantity,
      barcode,
      categories,
      kcal,
      protein,
      carbs,
      fat,
      fiber,
      sugar,
      salt,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prodotto verificato e salvato nella demo'),
      ),
    );
    context.go('/ingredients');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifica prodotto')),
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
            TtAppCard(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.fact_check_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Text(
                      'I valori arrivano da Open Food Facts simulato. '
                      'Controllali sempre con lâ€™etichetta prima di salvare.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(
              title: 'Prodotto trovato',
              subtitle:
                  'La revisione Ã¨ obbligatoria prima dellâ€™inserimento.',
            ),
            const SizedBox(height: AppSpacing.md),
            _requiredField(name, 'Nome'),
            const SizedBox(height: AppSpacing.md),
            _field(brand, 'Marca'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(child: _field(quantity, 'QuantitÃ ')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _field(barcode, 'Barcode')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _field(categories, 'Categorie'),
            const SizedBox(height: AppSpacing.sectionGap),
            const TtSectionHeader(title: 'Valori per 100 g'),
            const SizedBox(height: AppSpacing.md),
            _numberField(kcal, 'Calorie'),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(child: _numberField(protein, 'Proteine')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _numberField(carbs, 'Carboidrati')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(child: _numberField(fat, 'Grassi')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _numberField(fiber, 'Fibre')),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(child: _numberField(sugar, 'Zuccheri')),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _numberField(salt, 'Sale')),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TtPrimaryButton(
              label: 'Conferma e salva',
              icon: Icons.check_rounded,
              onPressed: save,
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.push('/ingredients/new/manual'),
                child: const Text('Passa allâ€™inserimento manuale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _requiredField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      validator: (String? value) {
        if (value == null || value.trim().isEmpty) {
          return 'Campo obbligatorio';
        }
        return null;
      },
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return null;
        }
        final double? parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null || parsed < 0) {
          return 'Valore non valido';
        }
        return null;
      },
      decoration: InputDecoration(labelText: '$label (g/kcal)'),
    );
  }
}
