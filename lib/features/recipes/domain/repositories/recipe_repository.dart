import '../entities/recipe.dart';

/// Contracts the presentation layer depends on. Local and HTTP
/// implementations are interchangeable.
abstract interface class RecipeRepository {
  List<Recipe> getRecipes();
  void saveRecipe(Recipe recipe);
}

abstract interface class RecipeVersionRepository {
  List<RecipeVersion> getVersions();
  void addVersion(RecipeVersion version);
}

abstract interface class CatalogRepository {
  List<RecipeCategory> getCategories();
  List<Ingredient> getIngredients();
  void addIngredient(Ingredient ingredient);
}
