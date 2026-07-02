import 'package:objectbox/objectbox.dart';

import '../../../../core/identifiers/uuid_generator.dart';
import '../../../../core/time/clock.dart';
import '../entities/nutrition_tracking_entities.dart';
import '../entities/ingredient_entity.dart';

class RecipeDetails {
  const RecipeDetails({
    required this.recipe,
    required this.ingredients,
    required this.steps,
  });

  final RecipeEntity recipe;
  final List<RecipeIngredientEntity> ingredients;
  final List<RecipeStepEntity> steps;
}

class RecipeRepository {
  RecipeRepository(
    Store store, {
    Clock clock = const Clock(),
    UuidGenerator? uuidGenerator,
  })  : _store = store,
        _clock = clock,
        _uuidGenerator = uuidGenerator ?? UuidGenerator();

  final Store _store;
  final Clock _clock;
  final UuidGenerator _uuidGenerator;

  Box<RecipeEntity> get _recipeBox => _store.box<RecipeEntity>();
  Box<RecipeIngredientEntity> get _ingredientBox {
    return _store.box<RecipeIngredientEntity>();
  }

  Box<RecipeStepEntity> get _stepBox => _store.box<RecipeStepEntity>();

  RecipeEntity save(RecipeEntity recipe) {
    _normalize(recipe);
    _validate(recipe);
    _prepareForSave(recipe);
    recipe.id = _recipeBox.put(recipe);
    return recipe;
  }

  RecipeDetails saveRecipeWithChildren(
    RecipeEntity recipe, {
    List<RecipeIngredientEntity> ingredients = const <RecipeIngredientEntity>[],
    List<RecipeStepEntity> steps = const <RecipeStepEntity>[],
  }) {
    return _store.runInTransaction(TxMode.write, () {
      save(recipe);
      final List<int> oldIngredientIds = getIngredients(recipe.id)
          .map((RecipeIngredientEntity ingredient) => ingredient.id)
          .toList();
      final List<int> oldStepIds =
          getSteps(recipe.id).map((RecipeStepEntity step) => step.id).toList();
      if (oldIngredientIds.isNotEmpty) {
        _ingredientBox.removeMany(oldIngredientIds);
      }
      if (oldStepIds.isNotEmpty) {
        _stepBox.removeMany(oldStepIds);
      }

      for (int index = 0; index < ingredients.length; index += 1) {
        final RecipeIngredientEntity ingredient = ingredients[index];
        ingredient.position = index;
        _prepareIngredientForSave(ingredient);
        ingredient.recipe.target = recipe;
        ingredient.id = _ingredientBox.put(ingredient);
      }
      for (int index = 0; index < steps.length; index += 1) {
        final RecipeStepEntity step = steps[index];
        step.position = index;
        _prepareStepForSave(step);
        step.recipe.target = recipe;
        step.id = _stepBox.put(step);
      }
      return RecipeDetails(
        recipe: recipe,
        ingredients: ingredients,
        steps: steps,
      );
    });
  }

  RecipeEntity? getById(int id) {
    final RecipeEntity? recipe = _recipeBox.get(id);
    if (recipe == null || recipe.deletedAtEpochMs != null) {
      return null;
    }
    return recipe;
  }

  RecipeDetails? getDetails(int id) {
    final RecipeEntity? recipe = getById(id);
    if (recipe == null) {
      return null;
    }
    return RecipeDetails(
      recipe: recipe,
      ingredients: getIngredients(recipe.id),
      steps: getSteps(recipe.id),
    );
  }

  List<RecipeEntity> getAllActive() {
    return _recipeBox
        .getAll()
        .where((RecipeEntity recipe) => recipe.deletedAtEpochMs == null)
        .toList()
      ..sort((RecipeEntity a, RecipeEntity b) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
  }

  RecipeDetails addIngredientItem({
    required int recipeId,
    required IngredientEntity ingredient,
    required double grams,
  }) {
    if (grams <= 0) {
      throw ArgumentError.value(grams, 'grams', 'Must be greater than zero.');
    }
    return _store.runInTransaction(TxMode.write, () {
      final recipe = getById(recipeId);
      if (recipe == null) {
        throw StateError('Recipe not found: $recipeId');
      }
      final current = getIngredients(recipeId);
      final reference = ingredient.nutritionReferenceAmount <= 0
          ? 100.0
          : ingredient.nutritionReferenceAmount;
      final factor = grams / reference;
      final value = RecipeIngredientEntity(
        uuid: '',
        position: current.length,
        ingredientUuid: ingredient.uuid,
        nameSnapshot: ingredient.name,
        grams: grams,
        calories: ingredient.kcalPerReference * factor,
        proteinGrams: ingredient.proteinPerReference * factor,
        carbsGrams: ingredient.carbsPerReference * factor,
        fatGrams: ingredient.fatPerReference * factor,
        fiberGrams: ingredient.fiberPerReference * factor,
        sugarGrams: ingredient.sugarPerReference * factor,
        preparationNote: ingredient.sourceAttribution,
        createdAtEpochMs: 0,
        updatedAtEpochMs: 0,
      );
      _prepareIngredientForSave(value);
      value.recipe.target = recipe;
      value.id = _ingredientBox.put(value);
      final all = <RecipeIngredientEntity>[...current, value];
      final totalWeight = all.fold<double>(0, (sum, item) => sum + item.grams);
      final calories = all.fold<double>(0, (sum, item) => sum + item.calories);
      final protein =
          all.fold<double>(0, (sum, item) => sum + item.proteinGrams);
      final carbs = all.fold<double>(0, (sum, item) => sum + item.carbsGrams);
      final fat = all.fold<double>(0, (sum, item) => sum + item.fatGrams);
      final fiber = all.fold<double>(0, (sum, item) => sum + item.fiberGrams);
      final sugar = all.fold<double>(0, (sum, item) => sum + item.sugarGrams);
      recipe
        ..totalWeightGrams = totalWeight
        ..caloriesTotal = calories
        ..proteinTotalGrams = protein
        ..carbsTotalGrams = carbs
        ..fatTotalGrams = fat
        ..fiberTotalGrams = fiber
        ..sugarTotalGrams = sugar
        ..kcalPerServing = calories / recipe.servings
        ..kcalPer100Grams =
            totalWeight <= 0 ? null : calories * 100 / totalWeight
        ..proteinPer100Grams =
            totalWeight <= 0 ? null : protein * 100 / totalWeight
        ..carbsPer100Grams = totalWeight <= 0 ? null : carbs * 100 / totalWeight
        ..fatPer100Grams = totalWeight <= 0 ? null : fat * 100 / totalWeight
        ..updatedAtEpochMs = _clock.nowEpochMs();
      _recipeBox.put(recipe);
      return RecipeDetails(
        recipe: recipe,
        ingredients: all,
        steps: getSteps(recipeId),
      );
    });
  }

  void softDeleteAndDetachMealItems(RecipeEntity recipe) {
    _store.runInTransaction(TxMode.write, () {
      final int now = _clock.nowEpochMs();
      final RecipeEntity? current = _recipeBox.get(recipe.id);
      if (current == null || current.deletedAtEpochMs != null) {
        return;
      }
      final Box<MealItemEntity> mealItemBox = _store.box<MealItemEntity>();
      final List<MealItemEntity> linkedItems = mealItemBox
          .getAll()
          .where(
            (MealItemEntity item) =>
                item.deletedAtEpochMs == null &&
                item.kindCode == 'recipe' &&
                item.sourceUuid == current.uuid,
          )
          .toList();
      for (final MealItemEntity item in linkedItems) {
        item.sourceUuid = '';
        item.notes = item.notes.trim().isEmpty
            ? 'Ricetta rimossa dall archivio; dati mantenuti come snapshot.'
            : item.notes;
        item.updatedAtEpochMs = now;
      }
      if (linkedItems.isNotEmpty) {
        mealItemBox.putMany(linkedItems);
      }
      current.deletedAtEpochMs = now;
      current.updatedAtEpochMs = now;
      _recipeBox.put(current);
    });
  }

  List<RecipeIngredientEntity> getIngredients(int recipeId) {
    return _ingredientBox
        .getAll()
        .where(
          (RecipeIngredientEntity ingredient) =>
              ingredient.recipe.targetId == recipeId &&
              ingredient.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((RecipeIngredientEntity a, RecipeIngredientEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  List<RecipeStepEntity> getSteps(int recipeId) {
    return _stepBox
        .getAll()
        .where(
          (RecipeStepEntity step) =>
              step.recipe.targetId == recipeId && step.deletedAtEpochMs == null,
        )
        .toList()
      ..sort((RecipeStepEntity a, RecipeStepEntity b) {
        return a.position.compareTo(b.position);
      });
  }

  void _prepareForSave(RecipeEntity recipe) {
    final int now = _clock.nowEpochMs();
    if (recipe.uuid.trim().isEmpty) {
      recipe.uuid = _uuidGenerator.generate();
    }
    if (recipe.createdAtEpochMs == 0) {
      recipe.createdAtEpochMs = now;
    }
    recipe.updatedAtEpochMs = now;
  }

  void _prepareIngredientForSave(RecipeIngredientEntity ingredient) {
    final int now = _clock.nowEpochMs();
    if (ingredient.uuid.trim().isEmpty) {
      ingredient.uuid = _uuidGenerator.generate();
    }
    if (ingredient.createdAtEpochMs == 0) {
      ingredient.createdAtEpochMs = now;
    }
    ingredient.updatedAtEpochMs = now;
  }

  void _prepareStepForSave(RecipeStepEntity step) {
    final int now = _clock.nowEpochMs();
    if (step.uuid.trim().isEmpty) {
      step.uuid = _uuidGenerator.generate();
    }
    if (step.createdAtEpochMs == 0) {
      step.createdAtEpochMs = now;
    }
    step.updatedAtEpochMs = now;
  }

  void _normalize(RecipeEntity recipe) {
    recipe.title = recipe.title.trim();
    recipe.subtitle = recipe.subtitle.trim();
    recipe.summary = recipe.summary.trim();
    recipe.difficultyCode = recipe.difficultyCode.trim();
    recipe.source = recipe.source.trim();
  }

  void _validate(RecipeEntity recipe) {
    if (recipe.title.isEmpty) {
      throw ArgumentError.value(recipe.title, 'title', 'Title is required.');
    }
    if (recipe.servings <= 0) {
      throw ArgumentError.value(
        recipe.servings,
        'servings',
        'Servings must be greater than zero.',
      );
    }
  }
}
