import '../entities/measure_unit.dart';
import '../entities/recipe.dart';

/// What the user typed for a dish card (the dish exists once, shared by everyone's versions).
class DishDraft {
  const DishDraft({required this.name, required this.description, required this.imageUrl, required this.categoryId});
  final String name;
  final String description;
  final String imageUrl;
  final String categoryId;
}

/// What the user typed for a version; the server assigns id, number, author and date.
class VersionDraft {
  const VersionDraft({
    required this.title,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.notes = '',
  });

  final String title;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final Difficulty difficulty;
  final List<VersionIngredient> ingredients;
  final List<String> steps;
  final String notes;
}

/// Contracts the presentation layer depends on. The HTTP and the in-memory
/// (demo) implementations are interchangeable.
abstract interface class RecipeRepository {
  /// Creates a dish together with its first version (which becomes the main one).
  Future<(Recipe, RecipeVersion)> createDish(DishDraft dish, VersionDraft version);

  /// Adds a version of [recipeId] built from [parentVersionId]. Versions are never edited.
  Future<RecipeVersion> addVersion(String recipeId, String parentVersionId, VersionDraft version);

  /// Author-only changes.
  Future<Recipe> updateRecipe(String recipeId, {String? mainVersionId, RecipeStatus? status});

  /// Returns the user's favorite dish ids after the change.
  Future<Set<String>> setFavorite(String recipeId, {required bool favorite});

  /// Uploads a dish photo and returns the value to store as the dish's image.
  Future<String> uploadImage(String filePath);
}

abstract interface class CatalogRepository {
  /// Returns the existing ingredient with that name (case-insensitive) or a new one.
  Future<Ingredient> findOrCreateIngredient(String name, MeasureUnit defaultUnit);
}
