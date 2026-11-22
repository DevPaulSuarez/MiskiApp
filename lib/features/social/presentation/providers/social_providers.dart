import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/session_controller.dart';
import '../../../profile/data/profile_data_providers.dart';
import '../../../profile/domain/profile_repository.dart';
import '../../data/social_data_providers.dart';
import '../../domain/social_entities.dart';
import '../../domain/social_repository.dart';

SocialRepository _social(Ref ref) => ref.read(socialRepositoryProvider);

// --- Users ---
class UsersNotifier extends Notifier<List<AppUser>> {
  @override
  List<AppUser> build() => ref.watch(snapshotProvider).users;

  /// Updates the signed-in user's profile.
  Future<AppUser> updateMe(ProfileUpdate update) async {
    final me = await ref.read(profileRepositoryProvider).updateProfile(update);
    state = [for (final u in state) u.id == me.id ? me : u];
    return me;
  }

  Future<void> setFavoriteFoods(List<String> foods) => updateMe(ProfileUpdate(favoriteFoods: foods));
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

/// Someone not loaded yet (e.g. a person who just signed up) shows as a placeholder.
final userByIdProvider = Provider.family<AppUser, String>(
  (ref, id) =>
      ref.watch(usersProvider).where((u) => u.id == id).firstOrNull ??
      AppUser(id: id, name: 'Usuario de Miski', handle: '@miski', bio: ''),
);

// --- Notifications (server-generated) ---
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => ref.watch(snapshotProvider).notifications;

  /// Fetches the latest notifications; returns true when there are new ones.
  Future<bool> reload() async {
    final known = {for (final n in state) n.id};
    state = await _social(ref).fetchNotifications();
    return state.any((n) => !known.contains(n.id));
  }

  Future<void> markRead(String id) async {
    state = [for (final n in state) n.id == id ? n.markRead() : n];
    await _social(ref).markNotificationRead(id);
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) n.markRead()];
    await _social(ref).markAllNotificationsRead();
  }
}

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

final myNotificationsProvider = Provider((ref) {
  final me = ref.watch(currentUserIdProvider);
  return ref.watch(notificationsProvider).where((n) => n.userId == me).toList();
});

final unreadCountProvider = Provider((ref) => ref.watch(myNotificationsProvider).where((n) => !n.read).length);

// --- Invitations ---
class InvitationsNotifier extends Notifier<List<Invitation>> {
  @override
  List<Invitation> build() => ref.watch(snapshotProvider).invitations;

  void _put(Invitation inv) => state = [for (final i in state) i.id == inv.id ? inv : i];

  Future<void> send({required String versionId, required List<String> toUserIds, required String message}) async {
    final sent = await _social(ref).sendInvitations(versionId: versionId, toUserIds: toUserIds, message: message);
    state = [...sent, ...state];
  }

  Future<void> answer(String id, {required bool accept}) async =>
      _put(await _social(ref).answerInvitation(id, accept: accept));

  void _replace(Invitation inv) => _put(inv);
}

final invitationsProvider = NotifierProvider<InvitationsNotifier, List<Invitation>>(InvitationsNotifier.new);

/// People the current user has exchanged invitations with (sent or received).
final friendIdsProvider = Provider<Set<String>>((ref) {
  final me = ref.watch(currentUserIdProvider);
  return {
    for (final i in ref.watch(invitationsProvider))
      if (i.fromUserId == me) i.toUserId else if (i.toUserId == me) i.fromUserId,
  };
});

// --- Ratings ---
class RatingsNotifier extends Notifier<List<Rating>> {
  @override
  List<Rating> build() => ref.watch(snapshotProvider).ratings;

  /// One rating per completed invitation.
  bool canRateInvitation(String invitationId) => !state.any((r) => r.invitationId == invitationId);

  /// Saves the rating; its comment and the completed invitation come back with it.
  Future<void> rate(RatingDraft draft) async {
    final res = await _social(ref).rate(draft);
    state = [res.rating, ...state];
    if (res.comment case final c?) ref.read(commentsProvider.notifier)._put(c);
    if (res.invitation case final i?) ref.read(invitationsProvider.notifier)._replace(i);
  }
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
  List<Comment> build() => ref.watch(snapshotProvider).comments;

  void _put(Comment c) => state = [...state, c];

  Future<void> add(String versionId, String text) async => _put(await _social(ref).addComment(versionId, text));
}

final commentsProvider = NotifierProvider<CommentsNotifier, List<Comment>>(CommentsNotifier.new);

final commentsOfVersionProvider = Provider.family<List<Comment>, String>(
  (ref, versionId) => ref.watch(commentsProvider).where((c) => c.versionId == versionId).toList(),
);
