import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_app_card.dart';
import '../../../../shared/widgets/tt_search_field.dart';

class IngredientOnlineSearchScreen extends StatefulWidget {
  const IngredientOnlineSearchScreen({super.key});

  @override
  State<IngredientOnlineSearchScreen> createState() =>
      _IngredientOnlineSearchScreenState();
}

class _IngredientOnlineSearchScreenState
    extends State<IngredientOnlineSearchScreen> {
  String query = '';

  static const List<_OnlineProduct> products = <_OnlineProduct>[
    _OnlineProduct(
      name: 'Yogurt Greco',
      brand: 'Mila',
      quantity: '150 g',
      barcode: '8001234567890',
      completeness: 'Dati completi',
    ),
    _OnlineProduct(
      name: 'Yogurt greco bianco',
      brand: 'Fage',
      quantity: '170 g',
      barcode: '5201054010364',
      completeness: 'Valori parziali',
    ),
    _OnlineProduct(
      name: 'Skyr naturale',
      brand: 'Arla',
      quantity: '150 g',
      barcode: '5711953075166',
      completeness: 'Dati completi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final String normalized = query.trim().toLowerCase();
    final List<_OnlineProduct> visible = products.where(
      (_OnlineProduct item) {
        return normalized.isEmpty ||
            item.name.toLowerCase().contains(normalized) ||
            item.brand.toLowerCase().contains(normalized);
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Cerca online')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          TtSearchField(
            hintText: 'Cerca prodotto o marca...',
            autofocus: true,
            onChanged: (String value) {
              setState(() {
                query = value;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Risultati Open Food Facts simulati',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          ...visible.map(
            (_OnlineProduct product) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: TtAppCard(
                onTap: () => context.push('/ingredients/new/review'),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 28,
                      child: Text(product.name.substring(0, 1)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            '${product.brand} Â· ${product.quantity}\n'
                            'Barcode: ${product.barcode}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            product.completeness,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => context.push('/ingredients/new/manual'),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Prodotto non trovato: inserisci manualmente'),
          ),
        ],
      ),
    );
  }
}

class _OnlineProduct {
  const _OnlineProduct({
    required this.name,
    required this.brand,
    required this.quantity,
    required this.barcode,
    required this.completeness,
  });

  final String name;
  final String brand;
  final String quantity;
  final String barcode;
  final String completeness;
}
