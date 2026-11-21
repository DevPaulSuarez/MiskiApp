import '../../features/recipes/domain/entities/recipe.dart';
import '../../features/social/domain/social_entities.dart';

/// Everything the app shows, as loaded at start-up (and on refresh).
class AppSnapshot {
  const AppSnapshot({
    required this.me,
    required this.email,
    this.users = const [],
    this.categories = const [],
    this.ingredients = const [],
    this.recipes = const [],
    this.versions = const [],
    this.ratings = const [],
    this.comments = const [],
    this.invitations = const [],
    this.notifications = const [],
    this.favoriteRecipeIds = const {},
  });

  final AppUser me;
  final String email;
  final List<AppUser> users;
  final List<RecipeCategory> categories;
  final List<Ingredient> ingredients;
  final List<Recipe> recipes;
  final List<RecipeVersion> versions;
  final List<Rating> ratings;
  final List<Comment> comments;
  final List<Invitation> invitations;
  final List<AppNotification> notifications;
  final Set<String> favoriteRecipeIds;
}

abstract interface class SyncRepository {
  Future<AppSnapshot> fetch();
}
