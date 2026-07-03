import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/database/objectbox_providers.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/services/open_food_facts_import_service.dart';
import '../data/services/open_food_facts_service.dart';

class OpenFoodFactsProductPreviewScreen extends ConsumerStatefulWidget {
  const OpenFoodFactsProductPreviewScreen({
    required this.barcode,
    this.initialProduct,
    super.key,
  });

  final String barcode;
  final OpenFoodFactsProduct? initialProduct;

  @override
  ConsumerState<OpenFoodFactsProductPreviewScreen> createState() =>
      _OpenFoodFactsProductPreviewScreenState();
}

class _OpenFoodFactsProductPreviewScreenState
    extends ConsumerState<OpenFoodFactsProductPreviewScreen> {
  OpenFoodFactsProduct? _product;
  Object? _error;
  bool _loading = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    if (_product == null) {
      Future<void>.microtask(_load);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final OpenFoodFactsProduct? value = await ref
          .read(openFoodFactsServiceProvider)
          .findByBarcode(widget.barcode);
      if (!mounted) return;
      setState(() => _product = value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final OpenFoodFactsProduct? product = _product;
    if (product == null) return;
    setState(() => _importing = true);

    try {
      final IngredientEntity ingredient = OpenFoodFactsImportService(
        ref.read(ingredientRepositoryProvider),
      ).importProduct(product);

      if (!mounted) return;
      context.pop(ingredient);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Widget _metric(
    BuildContext context,
    String label,
    double value, {
    String suffix = 'g',
  }) {
    final String formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '$formatted $suffix',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final OpenFoodFactsProduct? product = _product;

    return Scaffold(
      appBar: AppBar(title: const Text('Open Food Facts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : product == null
                  ? const Center(
                      child: Text(
                        'Alimento non trovato su Open Food Facts.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        120,
                      ),
                      children: <Widget>[
                        if (product.preferredImageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                product.preferredImageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const ColoredBox(
                                  color: Color(0x11000000),
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          product.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (product.brand.isNotEmpty)
                          Text(
                            product.brand,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 12),
                        Text('Barcode: ${product.code}'),
                        if (product.quantity.isNotEmpty)
                          Text('Confezione: ${product.quantity}'),
                        if (product.categories.isNotEmpty)
                          Text('Categorie: ${product.categories}'),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 2.1,
                          children: <Widget>[
                            _metric(
                              context,
                              'Calorie',
                              product.kcal100,
                              suffix: 'kcal',
                            ),
                            _metric(
                              context,
                              'Proteine',
                              product.protein100,
                            ),
                            _metric(
                              context,
                              'Carboidrati',
                              product.carbs100,
                            ),
                            _metric(
                              context,
                              'Grassi',
                              product.fat100,
                            ),
                            _metric(
                              context,
                              'Fibre',
                              product.fiber100,
                            ),
                            _metric(
                              context,
                              'Zuccheri',
                              product.sugar100,
                            ),
                            _metric(
                              context,
                              'Sale',
                              product.salt100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Fonte: Open Food Facts · ODbL 1.0 · '
                          '© Open Food Facts contributors',
                        ),
                      ],
                    ),
      bottomNavigationBar: product == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download_outlined),
                label: const Text('Importa alimento'),
              ),
            ),
    );
  }
}

class OpenFoodFactsScannerScreen extends ConsumerStatefulWidget {
  const OpenFoodFactsScannerScreen({super.key});

  @override
  ConsumerState<OpenFoodFactsScannerScreen> createState() =>
      _OpenFoodFactsScannerScreenState();
}

class _OpenFoodFactsScannerScreenState
    extends ConsumerState<OpenFoodFactsScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || capture.barcodes.isEmpty) return;
    final String code = capture.barcodes.first.rawValue?.trim() ?? '';
    if (code.isEmpty) return;
    await _openBarcode(code);
  }

  Future<void> _openBarcode(String code) async {
    if (_handling) return;
    setState(() => _handling = true);
    try {
      await _controller.stop();
      final OpenFoodFactsProduct? product =
          await ref.read(openFoodFactsServiceProvider).findByBarcode(code);
      if (!mounted) return;

      if (product == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Alimento non trovato su Open Food Facts.',
            ),
          ),
        );
        await _controller.start();
        return;
      }

      final IngredientEntity? imported = await context.push<IngredientEntity>(
        '/food/ingredients/off/product/'
        '${Uri.encodeComponent(code)}',
        extra: product,
      );
      if (!mounted) return;

      if (imported != null) {
        context.pop(imported);
        return;
      }
      await _controller.start();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      try {
        await _controller.start();
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  Future<void> _manualBarcode() async {
    final TextEditingController input = TextEditingController();
    try {
      final String? code = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text('Cerca tramite barcode'),
          content: TextField(
            controller: input,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Codice a barre',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final String value = input.text.trim();
                if (RegExp(r'^\d{6,18}$').hasMatch(value)) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Cerca'),
            ),
          ],
        ),
      );
      if (code != null && mounted) {
        await _openBarcode(code);
      }
    } finally {
      input.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona barcode'),
        actions: <Widget>[
          IconButton(
            onPressed: _handling ? null : _manualBarcode,
            icon: const Icon(Icons.keyboard_outlined),
            tooltip: 'Inserisci barcode',
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 270,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_handling)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x88000000),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
