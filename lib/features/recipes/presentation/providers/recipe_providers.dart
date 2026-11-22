import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/session_controller.dart';
import '../../data/recipe_data_providers.dart';
import '../../domain/entities/measure_unit.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_calculators.dart';

export '../../../../core/session/session_controller.dart' show currentUserIdProvider;

final costCalculatorProvider = Provider((_) => const CostCalculator());
final servingCalculatorProvider = Provider((_) => const ServingCalculator());
final versionComparatorProvider = Provider((_) => const VersionComparator());

// State is loaded with the session (see [snapshotProvider]); writes go to the
// repository first and the local state is updated with what the server returns.

// --- Recipes ---
class RecipesNotifier extends Notifier<List<Recipe>> {
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  List<Recipe> build() => ref.watch(snapshotProvider).recipes;

  void _put(Recipe recipe) {
    state = state.any((r) => r.id == recipe.id)
        ? [for (final r in state) r.id == recipe.id ? recipe : r]
        : [recipe, ...state];
  }

  /// Publishes a new dish with its first version.
  Future<RecipeVersion> createDish(DishDraft dish, VersionDraft version) async {
    final (recipe, v) = await _repo.createDish(dish, version);
    _put(recipe);
    ref.read(versionsProvider.notifier)._put(v);
    return v;
  }

  /// Only the dish's author may change its main version or archive it.
  bool canManage(String recipeId) => byId(recipeId).authorId == ref.read(currentUserIdProvider);

  Future<void> setMainVersion(String recipeId, String versionId) async {
    _requireAuthor(recipeId);
    _put(await _repo.updateRecipe(recipeId, mainVersionId: versionId));
  }

  Future<void> toggleArchive(String recipeId) async {
    _requireAuthor(recipeId);
    final archived = byId(recipeId).status == RecipeStatus.archived;
    _put(await _repo.updateRecipe(recipeId, status: archived ? RecipeStatus.active : RecipeStatus.archived));
  }

  void _requireAuthor(String recipeId) {
    if (!canManage(recipeId)) {
      throw StateError('Solo el autor del plato puede cambiar su versión principal o archivarlo.');
    }
  }

  Recipe byId(String id) => state.firstWhere((r) => r.id == id);
}

final recipesProvider = NotifierProvider<RecipesNotifier, List<Recipe>>(RecipesNotifier.new);

final activeRecipesProvider = Provider(
  (ref) => ref.watch(recipesProvider).where((r) => r.status == RecipeStatus.active).toList(),
);

final recipeByIdProvider = Provider.family<Recipe?, String>(
  (ref, id) => ref.watch(recipesProvider).where((r) => r.id == id).firstOrNull,
);

// --- Versions ---
class VersionsNotifier extends Notifier<List<RecipeVersion>> {
  @override
  List<RecipeVersion> build() => ref.watch(snapshotProvider).versions;

  void _put(RecipeVersion v) => state = [...state.where((x) => x.id != v.id), v];

  /// Publishes a new version of [recipeId] built from [parentVersionId] (append-only).
  Future<RecipeVersion> add(String recipeId, String parentVersionId, VersionDraft draft) async {
    final v = await ref.read(recipeRepositoryProvider).addVersion(recipeId, parentVersionId, draft);
    _put(v);
    return v;
  }

  /// Next number for a preview; the server assigns the final one.
  int nextNumber(String recipeId) =>
      state.where((v) => v.recipeId == recipeId).fold(0, (m, v) => v.number > m ? v.number : m) + 1;
}

final versionsProvider = NotifierProvider<VersionsNotifier, List<RecipeVersion>>(VersionsNotifier.new);

final versionByIdProvider = Provider.family<RecipeVersion?, String>(
  (ref, id) => ref.watch(versionsProvider).where((v) => v.id == id).firstOrNull,
);

final versionsOfRecipeProvider = Provider.family<List<RecipeVersion>, String>(
  (ref, recipeId) =>
      ref.watch(versionsProvider).where((v) => v.recipeId == recipeId).toList()
        ..sort((a, b) => a.number.compareTo(b.number)),
);

// --- Catalog ---
final categoriesProvider = Provider((ref) => ref.watch(snapshotProvider).categories);

class IngredientsNotifier extends Notifier<List<Ingredient>> {
  @override
  List<Ingredient> build() => ref.watch(snapshotProvider).ingredients;

  /// Avoids duplicates: reuses the ingredient with the same name (case-insensitive).
  Future<Ingredient> findOrCreate(String name, MeasureUnit defaultUnit) async {
    final clean = name.trim();
    final local = state.where((i) => i.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
    if (local != null) return local;
    final ingredient = await ref.read(catalogRepositoryProvider).findOrCreateIngredient(clean, defaultUnit);
    if (!state.any((i) => i.id == ingredient.id)) state = [...state, ingredient];
    return ingredient;
  }
}

final ingredientsProvider = NotifierProvider<IngredientsNotifier, List<Ingredient>>(IngredientsNotifier.new);

final ingredientByIdProvider = Provider.family<Ingredient?, String>(
  (ref, id) => ref.watch(ingredientsProvider).where((i) => i.id == id).firstOrNull,
);

// --- Favorites ---
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(snapshotProvider).favoriteRecipeIds;

  /// Optimistic: the heart changes at once and is reverted if the server fails.
  Future<void> toggle(String recipeId) async {
    final before = state;
    final favorite = !before.contains(recipeId);
    state = favorite ? {...before, recipeId} : ({...before}..remove(recipeId));
    try {
      state = await ref.read(recipeRepositoryProvider).setFavorite(recipeId, favorite: favorite);
    } catch (_) {
      state = before;
      rethrow;
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
