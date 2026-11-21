import '../../../core/network/api_client.dart';
import '../../recipes/data/recipe_json.dart';
import '../../social/data/social_json.dart';
import '../../social/domain/social_entities.dart';
import '../domain/profile_repository.dart';

class ApiProfileRepository implements ProfileRepository {
  const ApiProfileRepository(this._api);
  final ApiClient _api;

  @override
  Future<AppUser> updateProfile(ProfileUpdate u) async {
    final res = await _api.patch('me', {
      'name': ?u.name,
      'handle': ?u.handle,
      'bio': ?u.bio,
      if (u.birthday != null || u.clearBirthday) 'birthday': u.birthday?.toIso8601String().substring(0, 10),
      'favorite_foods': ?u.favoriteFoods,
      if (u.favoriteCategoryIds != null)
        'favorite_category_ids': [for (final c in u.favoriteCategoryIds!) int.tryParse(c) ?? c],
    });
    return SocialJson.user(res as Json);
  }
}
