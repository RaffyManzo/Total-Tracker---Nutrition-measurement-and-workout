import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../shared/widgets/tt_primary_button.dart';

class BarcodeScannerMockScreen extends StatefulWidget {
  const BarcodeScannerMockScreen({super.key});

  @override
  State<BarcodeScannerMockScreen> createState() =>
      _BarcodeScannerMockScreenState();
}

class _BarcodeScannerMockScreenState extends State<BarcodeScannerMockScreen> {
  final TextEditingController barcodeController =
      TextEditingController(text: '8001234567890');
  bool isScanning = false;
  String status = 'Inquadra il barcode nella cornice';

  @override
  void dispose() {
    barcodeController.dispose();
    super.dispose();
  }

  Future<void> simulateScan() async {
    setState(() {
      isScanning = true;
      status = 'Lettura del codice...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }

    setState(() {
      status = 'Codice rilevato: 8001234567890';
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) {
      return;
    }

    context.push('/ingredients/new/review');
    setState(() {
      isScanning = false;
      status = 'Inquadra il barcode nella cornice';
    });
  }

  void useManualCode() {
    final String value = barcodeController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un barcode')),
      );
      return;
    }
    context.push('/ingredients/new/review');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scansiona barcode'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: <Widget>[
            const SizedBox(height: AppSpacing.lg),
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF202420),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      size: 170,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  Container(
                    width: 260,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  if (isScanning)
                    SizedBox(
                      width: 250,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.filledTonal(
                  tooltip: 'Torcia simulata',
                  onPressed: () {},
                  icon: const Icon(Icons.flashlight_on_outlined),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton.filledTonal(
                  tooltip: 'Cambia fotocamera simulata',
                  onPressed: () {},
                  icon: const Icon(Icons.cameraswitch_outlined),
                ),
                const SizedBox(width: AppSpacing.md),
                IconButton.filledTonal(
                  tooltip: 'Galleria simulata',
                  onPressed: () {},
                  icon: const Icon(Icons.photo_library_outlined),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            TtPrimaryButton(
              label: isScanning
                  ? 'Scansione in corso'
                  : 'Simula scansione riuscita',
              icon: Icons.qr_code_scanner_rounded,
              isLoading: isScanning,
              onPressed: simulateScan,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextField(
              controller: barcodeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Inserisci barcode manualmente',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF202420),
                suffixIcon: IconButton(
                  onPressed: useManualCode,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
