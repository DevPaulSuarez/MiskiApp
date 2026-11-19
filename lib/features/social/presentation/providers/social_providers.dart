import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock/mock_data.dart';
import '../../../recipes/presentation/providers/recipe_providers.dart';
import '../../domain/social_entities.dart';

class UsersNotifier extends Notifier<List<AppUser>> {
  @override
  List<AppUser> build() => [...MockData.users];

  void setFavoriteFoods(String userId, List<String> foods) =>
      state = [for (final u in state) u.id == userId ? u.copyWith(favoriteFoods: foods) : u];
}

final usersProvider = NotifierProvider<UsersNotifier, List<AppUser>>(UsersNotifier.new);

/// Other users whose birthday falls within the next [upcomingBirthdayDays], soonest first.
const upcomingBirthdayDays = 30;
final upcomingBirthdaysProvider = Provider<List<(AppUser, int)>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  final today = DateTime.now();
  final list = [
    for (final u in ref.watch(usersProvider))
      if (u.id != me)
        if (u.daysUntilBirthday(today) case final d? when d <= upcomingBirthdayDays) (u, d),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  return list;
});

final userByIdProvider = Provider.family<AppUser, String>(
  (ref, id) => ref.watch(usersProvider).firstWhere((u) => u.id == id),
);

// --- Notifications ---
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [...MockData.notifications];

  /// Sends to [toUserId], or to the current user when omitted.
  void push(String title, String body, {String? route, String? toUserId}) => state = [
        AppNotification(
          id: newId('n'),
          userId: toUserId ?? ref.read(currentUserIdProvider),
          title: title,
          body: body,
          createdAt: DateTime.now(),
          route: route,
        ),
        ...state,
      ];

  void markRead(String id) => state = [for (final n in state) n.id == id ? n.markRead() : n];

  void markAllRead() {
    final me = ref.read(currentUserIdProvider);
    state = [for (final n in state) n.userId == me ? n.markRead() : n];
  }
}

/// All notifications in the system (every recipient). Screens should use [myNotificationsProvider].
final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

final myNotificationsProvider = Provider((ref) {
  final me = ref.watch(currentUserIdProvider);
  return ref.watch(notificationsProvider).where((n) => n.userId == me).toList();
});

final unreadCountProvider = Provider((ref) => ref.watch(myNotificationsProvider).where((n) => !n.read).length);

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
