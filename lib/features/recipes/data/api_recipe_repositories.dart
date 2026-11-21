import '../../../core/network/api_client.dart';
import '../domain/entities/measure_unit.dart';
import '../domain/entities/recipe.dart';
import '../domain/repositories/recipe_repository.dart';
import 'recipe_json.dart';

Object _id(String id) => int.tryParse(id) ?? id;

class ApiRecipeRepository implements RecipeRepository {
  const ApiRecipeRepository(this._api);
  final ApiClient _api;

  @override
  Future<(Recipe, RecipeVersion)> createDish(DishDraft dish, VersionDraft version) async {
    final res = await _api.post('recipes', {
      'name': dish.name,
      'description': dish.description,
      'image_url': dish.imageUrl,
      'category_id': _id(dish.categoryId),
      'version': RecipeJson.versionDraft(version),
    }) as Json;
    return (RecipeJson.recipe(res['recipe'] as Json), RecipeJson.version(res['version'] as Json));
  }

  @override
  Future<RecipeVersion> addVersion(String recipeId, String parentVersionId, VersionDraft version) async {
    final res = await _api.post('recipes/$recipeId/versions', {
      'parent_version_id': _id(parentVersionId),
      ...RecipeJson.versionDraft(version),
    });
    return RecipeJson.version(res as Json);
  }

  @override
  Future<Recipe> updateRecipe(String recipeId, {String? mainVersionId, RecipeStatus? status}) async {
    final res = await _api.patch('recipes/$recipeId', {
      if (mainVersionId != null) 'main_version_id': _id(mainVersionId),
      if (status != null) 'status': status.name,
    });
    return RecipeJson.recipe(res as Json);
  }

  @override
  Future<Set<String>> setFavorite(String recipeId, {required bool favorite}) async {
    final res = favorite ? await _api.put('favorites/$recipeId') : await _api.delete('favorites/$recipeId');
    return (res as List).cast<String>().toSet();
  }

  @override
  Future<String> uploadImage(String filePath) async {
    final res = await _api.upload('uploads/images', 'image', filePath) as Json;
    return res['path'] as String;
  }
}

class ApiCatalogRepository implements CatalogRepository {
  const ApiCatalogRepository(this._api);
  final ApiClient _api;

  @override
  Future<Ingredient> findOrCreateIngredient(String name, MeasureUnit defaultUnit) async {
    final res = await _api.post('ingredients', {'name': name, 'default_unit': defaultUnit.name});
    return RecipeJson.ingredient(res as Json);
  }
}
