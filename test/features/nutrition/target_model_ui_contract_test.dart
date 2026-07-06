import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings expose sources formulas limits and component fallback', () {
    final String source = File(
      'lib/features/profile/presentation/profile_settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Fonti, formule e limiti'));
    expect(source, contains('Passi degli allenamenti'));
    expect(source, contains('Data di entrata in vigore'));
    expect(source, contains('Evita il doppio conteggio'));
    expect(source, contains('parzialmente provvisorio'));
    expect(source, contains('Dati registrati con fallback per componente'));
    expect(source, contains('Mifflin–St Jeor'));
    expect(source, contains('IN STALLO'));
  });

  test('day details expose approved model variables and no total sugar target',
      () {
    final String source = File(
      'lib/features/nutrition/presentation/food_v01_screens.dart',
    ).readAsStringSync();

    expect(source, contains('Pendenza robusta peso'));
    expect(source, contains('Lunghezza passo'));
    expect(source, contains('Regola fallback'));
    expect(source, contains('Zuccheri totali · nessun limite automatico'));
    expect(source, contains('Fonti, formule e limiti'));
    expect(source, contains('Passi degli allenamenti'));
    expect(source, contains('Data di entrata in vigore'));
    expect(source, contains('Obiettivo passi configurato'));
    expect(source, contains('estimated_active_calories'));
    expect(source, contains('modello interno dell’allenamento è fuori ambito'));
  });
}
