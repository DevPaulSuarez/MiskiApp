import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_data.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../domain/social_entities.dart';

final usersProvider = Provider<List<AppUser>>((_) => MockData.users);

final userByIdProvider = Provider.family<AppUser, String>(
  (ref, id) => ref.watch(usersProvider).firstWhere((u) => u.id == id),
);

// --- Notifications ---
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [...MockData.notifications];

  void push(String title, String body, {String? route}) => state = [
        AppNotification(id: newId('n'), title: title, body: body, createdAt: DateTime.now(), route: route),
        ...state,
      ];

  void markRead(String id) => state = [for (final n in state) n.id == id ? n.markRead() : n];
  void markAllRead() => state = [for (final n in state) n.markRead()];
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

final unreadCountProvider = Provider((ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);

// --- Invitations ---
class InvitationsNotifier extends Notifier<List<Invitation>> {
  @override
  List<Invitation> build() => [...MockData.invitations];

  void send({
    required String recipeId,
    required String versionId,
    required List<String> toUserIds,
    required String message,
  }) {
    final from = ref.read(currentUserIdProvider);
    state = [
      for (final to in toUserIds)
        Invitation(
          id: newId('inv$to'),
          recipeId: recipeId,
          versionId: versionId,
          fromUserId: from,
          toUserId: to,
          message: message,
          createdAt: DateTime.now(),
        ),
      ...state,
    ];
  }

  void setStatus(String id, InvitationStatus status) =>
      state = [for (final i in state) i.id == id ? i.withStatus(status) : i];
}

final invitationsProvider = NotifierProvider<InvitationsNotifier, List<Invitation>>(InvitationsNotifier.new);

// --- Ratings ---
class RatingsNotifier extends Notifier<List<Rating>> {
  @override
  List<Rating> build() => [...MockData.ratings];

  /// One rating per completed invitation.
  bool canRateInvitation(String invitationId) => !state.any((r) => r.invitationId == invitationId);

  void add(Rating rating) => state = [rating, ...state];
}

final ratingsProvider = NotifierProvider<RatingsNotifier, List<Rating>>(RatingsNotifier.new);

final ratingSummaryProvider = Provider.family<RatingSummary, String>(
  (ref, versionId) => RatingSummary(ref.watch(ratingsProvider).where((r) => r.versionId == versionId).toList()),
);

final recipeRatingSummaryProvider = Provider.family<RatingSummary, String>(
  (ref, recipeId) => RatingSummary(ref.watch(ratingsProvider).where((r) => r.recipeId == recipeId).toList()),
);

// --- Comments ---
class CommentsNotifier extends Notifier<List<Comment>> {
  @override
  List<Comment> build() => [...MockData.comments];

  void add(String versionId, String text) => state = [
        ...state,
        Comment(
          id: newId('co'),
          userId: ref.read(currentUserIdProvider),
          versionId: versionId,
          text: text,
          createdAt: DateTime.now(),
        ),
      ];
}

final commentsProvider = NotifierProvider<CommentsNotifier, List<Comment>>(CommentsNotifier.new);

final commentsOfVersionProvider = Provider.family<List<Comment>, String>(
  (ref, versionId) => ref.watch(commentsProvider).where((c) => c.versionId == versionId).toList(),
);
