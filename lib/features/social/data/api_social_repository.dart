import '../../../core/network/api_client.dart';
import '../../recipes/data/recipe_json.dart';
import '../domain/social_entities.dart';
import '../domain/social_repository.dart';
import 'social_json.dart';

Object _id(String id) => int.tryParse(id) ?? id;

class ApiSocialRepository implements SocialRepository {
  const ApiSocialRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<Invitation>> sendInvitations({
    required String versionId,
    required List<String> toUserIds,
    String message = '',
  }) async {
    final res = await _api.post('invitations', {
      'version_id': _id(versionId),
      'to_user_ids': [for (final u in toUserIds) _id(u)],
      'message': message,
    });
    return [for (final j in (res as List).cast<Json>()) SocialJson.invitation(j)];
  }

  @override
  Future<Invitation> answerInvitation(String invitationId, {required bool accept}) async {
    final res = await _api.patch('invitations/$invitationId', {'status': accept ? 'accepted' : 'rejected'});
    return SocialJson.invitation(res as Json);
  }

  @override
  Future<List<Invitation>> fetchInvitations() async => [
    for (final j in (await _api.get('invitations') as List).cast<Json>()) SocialJson.invitation(j),
  ];

  @override
  Future<RatingResult> rate(RatingDraft d) async {
    final res = await _api.post('ratings', {
      'version_id': _id(d.versionId),
      if (d.invitationId != null) 'invitation_id': _id(d.invitationId!),
      'stars': d.stars,
      'flavor': d.flavor,
      'presentation': d.presentation,
      'ease': d.ease,
      'value': d.value,
      'comment': d.comment,
    }) as Json;
    return (
      rating: SocialJson.rating(res['rating'] as Json),
      comment: res['comment'] == null ? null : SocialJson.comment(res['comment'] as Json),
      invitation: res['invitation'] == null ? null : SocialJson.invitation(res['invitation'] as Json),
    );
  }

  @override
  Future<Comment> addComment(String versionId, String text) async =>
      SocialJson.comment(await _api.post('versions/$versionId/comments', {'text': text}) as Json);

  @override
  Future<List<AppNotification>> fetchNotifications() async => [
    for (final j in (await _api.get('notifications') as List).cast<Json>()) SocialJson.notification(j),
  ];

  @override
  Future<void> markNotificationRead(String id) => _api.post('notifications/$id/read');

  @override
  Future<void> markAllNotificationsRead() => _api.post('notifications/read-all');
}
