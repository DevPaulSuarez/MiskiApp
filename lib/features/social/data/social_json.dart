import '../../recipes/data/recipe_json.dart';
import '../domain/social_entities.dart';

abstract final class SocialJson {
  static AppUser user(Json j) => AppUser(
    id: j['id'] as String,
    name: j['name'] as String,
    handle: j['handle'] as String,
    bio: j['bio'] as String? ?? '',
    birthday: j['birthday'] == null ? null : DateTime.parse(j['birthday'] as String),
    favoriteCategoryIds: (j['favorite_category_ids'] as List? ?? const []).cast<String>(),
    favoriteFoods: (j['favorite_foods'] as List? ?? const []).cast<String>(),
  );

  static Invitation invitation(Json j) => Invitation(
    id: j['id'] as String,
    recipeId: j['recipe_id'] as String,
    versionId: j['version_id'] as String,
    fromUserId: j['from_user_id'] as String,
    toUserId: j['to_user_id'] as String,
    message: j['message'] as String? ?? '',
    status: InvitationStatus.values.byName(j['status'] as String),
    createdAt: parseDate(j['created_at']),
  );

  static Rating rating(Json j) => Rating(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    recipeId: j['recipe_id'] as String,
    versionId: j['version_id'] as String,
    invitationId: j['invitation_id'] as String?,
    stars: j['stars'] as int,
    flavor: j['flavor'] as int? ?? 0,
    presentation: j['presentation'] as int? ?? 0,
    ease: j['ease'] as int? ?? 0,
    value: j['value'] as int? ?? 0,
    comment: j['comment'] as String? ?? '',
    createdAt: parseDate(j['created_at']),
  );

  static Comment comment(Json j) => Comment(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    versionId: j['version_id'] as String,
    text: j['text'] as String,
    createdAt: parseDate(j['created_at']),
  );

  static AppNotification notification(Json j) => AppNotification(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
    route: j['route'] as String?,
    read: j['read'] as bool? ?? false,
    createdAt: parseDate(j['created_at']),
  );
}
