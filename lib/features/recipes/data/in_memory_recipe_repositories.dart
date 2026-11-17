import '../../../core/mock/mock_data.dart';
import '../domain/entities/recipe.dart';
import '../domain/repositories/recipe_repository.dart';

/// In-memory implementations seeded with mock data. To be replaced by
/// local persistence / HTTP data sources without touching the UI.
class InMemoryRecipeRepository implements RecipeRepository {
  final List<Recipe> _items = [...MockData.recipes];

  @override
  List<Recipe> getRecipes() => List.unmodifiable(_items);

  @override
  void saveRecipe(Recipe recipe) {
    final i = _items.indexWhere((r) => r.id == recipe.id);
    i >= 0 ? _items[i] = recipe : _items.insert(0, recipe);
  }
}

class InMemoryRecipeVersionRepository implements RecipeVersionRepository {
  final List<RecipeVersion> _items = [...MockData.versions];

  @override
  List<RecipeVersion> getVersions() => List.unmodifiable(_items);

  /// Append-only: published versions are never modified.
  @override
  void addVersion(RecipeVersion version) => _items.add(version);
}

class InMemoryCatalogRepository implements CatalogRepository {
  final List<Ingredient> _ingredients = [...MockData.ingredients];

  @override
  List<RecipeCategory> getCategories() => MockData.categories;

  @override
  List<Ingredient> getIngredients() => List.unmodifiable(_ingredients);

  @override
  void addIngredient(Ingredient ingredient) => _ingredients.add(ingredient);
}
