import '../../features/recipes/data/recipe_json.dart';
import '../../features/social/data/social_json.dart';
import '../network/api_client.dart';
import 'app_snapshot.dart';

class ApiSyncRepository implements SyncRepository {
  const ApiSyncRepository(this._api);
  final ApiClient _api;

  @override
  Future<AppSnapshot> fetch() async {
    final j = await _api.get('sync') as Json;
    List<T> list<T>(String key, T Function(Json) f) => [for (final e in (j[key] as List).cast<Json>()) f(e)];
    final me = j['me'] as Json;
    return AppSnapshot(
      me: SocialJson.user(me),
      email: me['email'] as String,
      users: list('users', SocialJson.user),
      categories: list('categories', RecipeJson.category),
      ingredients: list('ingredients', RecipeJson.ingredient),
      recipes: list('recipes', RecipeJson.recipe),
      versions: list('versions', RecipeJson.version),
      ratings: list('ratings', SocialJson.rating),
      comments: list('comments', SocialJson.comment),
      invitations: list('invitations', SocialJson.invitation),
      notifications: list('notifications', SocialJson.notification),
      favoriteRecipeIds: (j['favorite_recipe_ids'] as List).cast<String>().toSet(),
    );
  }
}
