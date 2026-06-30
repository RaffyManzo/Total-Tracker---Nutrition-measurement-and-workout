import 'package:flutter_test/flutter_test.dart';
import 'package:total_tracker/features/nutrition/data/entities/ingredient_entity.dart';
import 'package:total_tracker/features/nutrition/data/repositories/ingredient_repository.dart';

import '../../helpers/objectbox_test_helper.dart';

void main() {
  test('salvataggio e lettura tramite uuid', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    final ingredient = repository.save(_ingredient(name: 'Riso'));

    expect(repository.findByUuid(ingredient.uuid)?.name, 'Riso');
  });

  test('ricerca per nome', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    repository.save(_ingredient(name: 'Yogurt greco'));
    repository.save(_ingredient(name: 'Riso basmati'));

    final results = repository.searchByName('yogurt');

    expect(results.length, 1);
    expect(results.single.name, 'Yogurt greco');
  });

  test('ricerca tramite barcode', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    final ingredient = repository.save(
      _ingredient(name: 'Latte', barcode: '8001234567890'),
    );

    expect(repository.findByBarcode('8001234567890')?.id, ingredient.id);
  });

  test('archiviazione senza cancellazione fisica', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    final ingredient = repository.save(_ingredient(name: 'Pane'));
    repository.archive(ingredient);

    expect(repository.getAllActive(), isEmpty);
    expect(
        database.store.box<IngredientEntity>().get(ingredient.id), isNotNull);
  });

  test('rifiuto di calorie o macro negative', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    expect(
      () => repository.save(_ingredient(name: 'Errore', kcal: -1)),
      throwsA(isA<ArgumentError>()),
    );
    expect(
      () => repository.save(_ingredient(name: 'Errore', protein: -1)),
      throwsA(isA<ArgumentError>()),
    );
  });
}

IngredientEntity _ingredient({
  required String name,
  String barcode = '',
  double kcal = 100,
  double protein = 5,
}) {
  return IngredientEntity(
    uuid: '',
    name: name,
    barcode: barcode,
    kcalPerReference: kcal,
    proteinPerReference: protein,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}
