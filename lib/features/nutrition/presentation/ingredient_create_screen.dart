import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/widgets/primary_bottom_navigation.dart';
import '../../../core/database/objectbox_providers.dart';
import '../data/entities/ingredient_entity.dart';
import '../data/services/ingredient_image_storage_service.dart';
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
  bool _pickingImage = false;
  bool _saved = false;
  String? _ownedPendingImagePath;

  @override
  void dispose() {
    final String? pendingPath = _ownedPendingImagePath;
    if (!_saved && pendingPath != null) {
      try {
        File(pendingPath).deleteSync();
      } catch (_) {
        // La pulizia best-effort non deve interrompere dispose().
      }
    }
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

  Future<void> _scanBarcode() async {
    final String? code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const _BarcodeCapturePage(),
      ),
    );
    if (code == null || !mounted) return;
    _barcode.text = code;
    setState(() {});
  }

  Future<void> _pickImage() async {
    if (_pickingImage) return;
    setState(() => _pickingImage = true);
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      final PlatformFile? selected =
          result == null || result.files.isEmpty ? null : result.files.single;
      if (selected == null) return;
      if (selected.size > IngredientImageStorageService.maximumBytes) {
        throw const IngredientImageStorageException(
          'L’immagine supera il limite di 8 MB.',
        );
      }

      Uint8List? bytes = selected.bytes;
      if (bytes == null && selected.path != null) {
        bytes = await File(selected.path!).readAsBytes();
      }
      if (bytes == null) {
        throw const IngredientImageStorageException(
          'Il file selezionato non è leggibile.',
        );
      }

      final String persistentPath = await IngredientImageStorageService.persist(
        bytes: bytes,
        originalName: selected.name,
      );
      final String? previousPath = _ownedPendingImagePath;
      _ownedPendingImagePath = persistentPath;
      if (previousPath != null && previousPath != persistentPath) {
        try {
          await File(previousPath).delete();
        } catch (_) {
          // Un file temporaneo non deve bloccare il nuovo allegato.
        }
      }
      if (!mounted) return;
      _image.text = persistentPath;
      setState(() {});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final String? pendingPath = _ownedPendingImagePath;
      if (pendingPath != null && _image.text.trim() != pendingPath) {
        try {
          await File(pendingPath).delete();
        } catch (_) {
          // La pulizia dell'allegato sostituito è best-effort.
        }
        _ownedPendingImagePath = null;
      }

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
      _saved = true;
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
    Widget? suffixIcon,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        maxLines: maxLines,
        onChanged: (_) {
          if (controller == _image || controller == _barcode) {
            setState(() {});
          }
        },
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(),
        ),
        validator: validator ??
            (String? value) {
              if (required && (value?.trim().isEmpty ?? true)) {
                return 'Campo obbligatorio';
              }
              if (numeric &&
                  (value?.trim().isNotEmpty ?? false) &&
                  double.tryParse(
                        value!.trim().replaceAll(',', '.'),
                      ) ==
                      null) {
                return 'Valore numerico non valido';
              }
              return null;
            },
      ),
    );
  }

  Widget _imagePreview() {
    final String value = _image.text.trim();
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    final Uri? uri = Uri.tryParse(value);
    Widget image;
    if (uri != null && uri.isScheme('https')) {
      try {
        final String safeUrl =
            IngredientImageStorageService.validateRemoteImageUrl(value);
        image = Image.network(
          safeUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ImageError(),
        );
      } catch (_) {
        image = const _ImageError();
      }
    } else {
      image = Image.file(
        File(value),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _ImageError(),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: image,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo ingrediente')),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentSection: 'food',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Identità alimento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _field(_name, 'Nome', required: true),
                    _field(_brand, 'Brand'),
                    _field(
                      _barcode,
                      'Barcode',
                      helperText:
                          'Puoi digitarlo oppure acquisirlo con la fotocamera.',
                      suffixIcon: IconButton(
                        tooltip: 'Scansiona barcode',
                        onPressed: _scanBarcode,
                        icon: const Icon(Icons.qr_code_scanner_outlined),
                      ),
                      validator: (String? value) {
                        final String clean = value?.trim() ?? '';
                        if (clean.isNotEmpty &&
                            !RegExp(r'^\d{6,18}$').hasMatch(clean)) {
                          return 'Inserisci da 6 a 18 cifre';
                        }
                        return null;
                      },
                    ),
                    _field(
                      _quantity,
                      'Quantità confezione',
                      numeric: true,
                    ),
                    _field(_categories, 'Categorie'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Immagine',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _imagePreview(),
                    _field(
                      _image,
                      'URL HTTPS o immagine locale',
                      helperText:
                          'Il file selezionato viene copiato nello spazio '
                          'privato dell’app. Formati: PNG, JPEG, WebP.',
                      suffixIcon: IconButton(
                        tooltip: 'Scegli immagine',
                        onPressed: _pickingImage ? null : _pickImage,
                        icon: _pickingImage
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.folder_open_outlined),
                      ),
                      validator: (String? value) {
                        final String clean = value?.trim() ?? '';
                        if (clean.isEmpty) return null;
                        final Uri? uri = Uri.tryParse(clean);
                        if (uri != null && uri.hasScheme) {
                          try {
                            IngredientImageStorageService
                                .validateRemoteImageUrl(clean);
                            return null;
                          } catch (error) {
                            return error.toString();
                          }
                        }
                        if (clean != _ownedPendingImagePath) {
                          return 'Per file locali usa il pulsante cartella';
                        }
                        if (!File(clean).existsSync()) {
                          return 'File locale non trovato';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Valori nutrizionali per 100 g',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _field(_kcal, 'Calorie', numeric: true),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _field(
                            _protein,
                            'Proteine (g)',
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _carbs,
                            'Carboidrati (g)',
                            numeric: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _field(
                            _fat,
                            'Grassi (g)',
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _fiber,
                            'Fibre (g)',
                            numeric: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _field(
                            _sugar,
                            'Zuccheri (g)',
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(
                            _salt,
                            'Sale (g)',
                            numeric: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _field(_notes, 'Note', maxLines: 4),
              ),
            ),
            const SizedBox(height: 12),
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

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x11000000),
      child: Center(
        child: Icon(Icons.broken_image_outlined, size: 42),
      ),
    );
  }
}

class _BarcodeCapturePage extends StatefulWidget {
  const _BarcodeCapturePage();

  @override
  State<_BarcodeCapturePage> createState() => _BarcodeCapturePageState();
}

class _BarcodeCapturePageState extends State<_BarcodeCapturePage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detect(BarcodeCapture capture) {
    if (_handled) return;
    for (final Barcode barcode in capture.barcodes) {
      final String value = barcode.rawValue?.trim() ?? '';
      if (RegExp(r'^\d{6,18}$').hasMatch(value)) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acquisisci barcode'),
      ),
      bottomNavigationBar: const PrimaryBottomNavigation(
        currentSection: 'food',
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _detect,
          ),
          Center(
            child: Container(
              width: 280,
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
          const Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Inquadra il codice a barre. Il dato verrà inserito nel '
                  'form senza effettuare ricerche online.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
