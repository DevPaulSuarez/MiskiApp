import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_data.dart';
import '../../data/in_memory_recipe_repositories.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/services/recipe_calculators.dart';

// --- Dependency injection (swap implementations here) ---
final recipeRepositoryProvider = Provider<RecipeRepository>((_) => InMemoryRecipeRepository());
final versionRepositoryProvider = Provider<RecipeVersionRepository>((_) => InMemoryRecipeVersionRepository());
final catalogRepositoryProvider = Provider<CatalogRepository>((_) => InMemoryCatalogRepository());

final costCalculatorProvider = Provider((_) => const CostCalculator());
final servingCalculatorProvider = Provider((_) => const ServingCalculator());
final versionComparatorProvider = Provider((_) => const VersionComparator());

final currentUserIdProvider = Provider((_) => MockData.currentUserId);

String newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

// --- Recipes ---
class RecipesNotifier extends Notifier<List<Recipe>> {
  RecipeRepository get _repo => ref.read(recipeRepositoryProvider);

  @override
  List<Recipe> build() => _repo.getRecipes();

  void save(Recipe recipe) {
    _repo.saveRecipe(recipe);
    state = _repo.getRecipes();
  }

  /// Only the dish's author may change its main version or archive it.
  bool canManage(String recipeId) => byId(recipeId).authorId == ref.read(currentUserIdProvider);

  void setMainVersion(String recipeId, String versionId) {
    _requireAuthor(recipeId);
    save(byId(recipeId).copyWith(mainVersionId: versionId));
  }

  void toggleArchive(String recipeId) {
    _requireAuthor(recipeId);
    final r = byId(recipeId);
    save(r.copyWith(status: r.status == RecipeStatus.active ? RecipeStatus.archived : RecipeStatus.active));
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
  RecipeVersionRepository get _repo => ref.read(versionRepositoryProvider);

  @override
  List<RecipeVersion> build() => _repo.getVersions();

  RecipeVersion add(RecipeVersion version) {
    _repo.addVersion(version);
    state = _repo.getVersions();
    return version;
  }

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
final categoriesProvider = Provider((ref) => ref.watch(catalogRepositoryProvider).getCategories());

class IngredientsNotifier extends Notifier<List<Ingredient>> {
  @override
  List<Ingredient> build() => ref.read(catalogRepositoryProvider).getIngredients();

  /// Avoids duplicates by matching names case-insensitively.
  Ingredient findOrCreate(String name, Ingredient Function() create) {
    final existing = state.where((i) => i.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;
    if (existing != null) return existing;
    final created = create();
    ref.read(catalogRepositoryProvider).addIngredient(created);
    state = ref.read(catalogRepositoryProvider).getIngredients();
    return created;
  }
}

final ingredientsProvider = NotifierProvider<IngredientsNotifier, List<Ingredient>>(IngredientsNotifier.new);

final ingredientByIdProvider = Provider.family<Ingredient?, String>(
  (ref, id) => ref.watch(ingredientsProvider).where((i) => i.id == id).firstOrNull,
);

// --- Favorites ---
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {...MockData.favoriteRecipeIds};

  void toggle(String recipeId) =>
      state = state.contains(recipeId) ? ({...state}..remove(recipeId)) : {...state, recipeId};
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(FavoritesNotifier.new);
