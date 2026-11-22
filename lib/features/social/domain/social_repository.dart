import 'social_entities.dart';

class RatingDraft {
  const RatingDraft({
    required this.versionId,
    required this.stars,
    this.invitationId,
    this.flavor = 0,
    this.presentation = 0,
    this.ease = 0,
    this.value = 0,
    this.comment = '',
  });

  final String versionId;
  final String? invitationId;
  final int stars;
  final int flavor;
  final int presentation;
  final int ease;
  final int value;
  final String comment;
}

/// A rating also publishes its comment and completes its invitation.
typedef RatingResult = ({Rating rating, Comment? comment, Invitation? invitation});

abstract interface class SocialRepository {
  Future<List<Invitation>> sendInvitations({
    required String versionId,
    required List<String> toUserIds,
    String message,
  });
  Future<Invitation> answerInvitation(String invitationId, {required bool accept});
  Future<List<Invitation>> fetchInvitations();
  Future<RatingResult> rate(RatingDraft draft);
  Future<Comment> addComment(String versionId, String text);

  Future<List<AppNotification>> fetchNotifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();
}
