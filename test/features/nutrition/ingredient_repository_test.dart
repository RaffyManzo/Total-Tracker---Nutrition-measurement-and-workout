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

  test('paginazione archivio ingredienti usa pagine stabili da dieci',
      () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    for (int index = 0; index < 35; index += 1) {
      repository.save(
        _ingredient(
          name: 'Ingrediente ${index.toString().padLeft(2, '0')}',
          brand: index.isEven ? 'Brand A' : 'Brand B',
        ),
      );
    }
    final IngredientEntity deleted = repository.save(
      _ingredient(name: 'Ingrediente eliminato', brand: 'Brand A'),
    );
    repository.softDelete(deleted);

    final page1 = repository.loadIngredientPage(page: 1);
    final page2 = repository.loadIngredientPage(page: 2);
    final beyond = repository.loadIngredientPage(page: 99);

    expect(page1.items, hasLength(10));
    expect(page2.items, hasLength(10));
    expect(page1.totalCount, 35);
    expect(page1.totalPages, 4);
    expect(page1.hasPrevious, isFalse);
    expect(page1.hasNext, isTrue);
    expect(
      page1.items.map((IngredientEntity item) => item.id).toSet().intersection(
            page2.items.map((IngredientEntity item) => item.id).toSet(),
          ),
      isEmpty,
    );
    expect(beyond.items, isEmpty);
    expect(
      page1.items.map((IngredientEntity item) => item.name),
      orderedEquals(<String>[
        for (int index = 0; index < 10; index += 1)
          'Ingrediente ${index.toString().padLeft(2, '0')}',
      ]),
    );
  });

  test('ricerca e brand sono applicati prima di limit e offset', () async {
    final database = await openTestDatabase();
    final repository = IngredientRepository(database.store);

    for (int index = 0; index < 18; index += 1) {
      repository.save(
        _ingredient(
          name: 'Yogurt ${index.toString().padLeft(2, '0')}',
          brand: index < 12 ? 'Greco' : 'Classico',
        ),
      );
    }
    for (int index = 0; index < 8; index += 1) {
      repository.save(_ingredient(name: 'Riso $index', brand: 'Greco'));
    }

    final page = repository.loadIngredientPage(
      page: 2,
      search: 'yogurt',
      brand: 'greco',
    );

    expect(page.totalCount, 12);
    expect(page.items, hasLength(2));
    expect(
      page.items.map((IngredientEntity item) => item.name),
      orderedEquals(<String>['Yogurt 10', 'Yogurt 11']),
    );
  });
}

IngredientEntity _ingredient({
  required String name,
  String brand = '',
  String barcode = '',
  double kcal = 100,
  double protein = 5,
}) {
  return IngredientEntity(
    uuid: '',
    name: name,
    brand: brand,
    barcode: barcode,
    kcalPerReference: kcal,
    proteinPerReference: protein,
    createdAtEpochMs: 0,
    updatedAtEpochMs: 0,
  );
}
