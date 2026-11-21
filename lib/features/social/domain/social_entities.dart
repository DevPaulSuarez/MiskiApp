class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    this.birthday,
    this.favoriteCategoryIds = const [],
    this.favoriteFoods = const [],
  });
  final String id;
  final String name;
  final String handle;
  final String bio;
  final DateTime? birthday;
  final List<String> favoriteCategoryIds;

  /// Free-text dishes the person loves (e.g. "Lomo saltado"), shown on their
  /// public profile so friends can surprise them on their birthday.
  final List<String> favoriteFoods;

  List<String> get _words => name.split(' ').where((w) => w.isNotEmpty).toList();
  String get initials => _words.take(2).map((p) => p[0]).join().toUpperCase();
  String get firstName => _words.firstOrNull ?? name;

  /// Days from [today] until the next birthday (0 = today), or null if unknown.
  int? daysUntilBirthday(DateTime today) {
    final b = birthday;
    if (b == null) return null;
    final t = DateTime(today.year, today.month, today.day);
    var next = DateTime(t.year, b.month, b.day);
    if (next.isBefore(t)) next = DateTime(t.year + 1, b.month, b.day);
    return next.difference(t).inDays;
  }

  AppUser copyWith({List<String>? favoriteFoods}) => AppUser(
    id: id,
    name: name,
    handle: handle,
    bio: bio,
    birthday: birthday,
    favoriteCategoryIds: favoriteCategoryIds,
    favoriteFoods: favoriteFoods ?? this.favoriteFoods,
  );
}

enum InvitationStatus {
  pending('Pendiente'),
  accepted('Aceptada'),
  rejected('Rechazada'),
  completed('Completada');

  const InvitationStatus(this.label);
  final String label;
}

class Invitation {
  const Invitation({
    required this.id,
    required this.recipeId,
    required this.versionId,
    required this.fromUserId,
    required this.toUserId,
    required this.createdAt,
    this.message = '',
    this.status = InvitationStatus.pending,
  });

  final String id;
  final String recipeId;
  final String versionId;
  final String fromUserId;
  final String toUserId;
  final String message;
  final InvitationStatus status;
  final DateTime createdAt;

  Invitation withStatus(InvitationStatus s) => Invitation(
    id: id,
    recipeId: recipeId,
    versionId: versionId,
    fromUserId: fromUserId,
    toUserId: toUserId,
    createdAt: createdAt,
    message: message,
    status: s,
  );
}

class Rating {
  const Rating({
    required this.id,
    required this.userId,
    required this.recipeId,
    required this.versionId,
    required this.stars,
    required this.createdAt,
    this.invitationId,
    this.flavor = 0,
    this.presentation = 0,
    this.ease = 0,
    this.value = 0,
    this.comment = '',
  });

  final String id;
  final String userId;
  final String recipeId;
  final String versionId;
  final String? invitationId;
  final int stars;
  final int flavor;
  final int presentation;
  final int ease;
  final int value;
  final String comment;
  final DateTime createdAt;
}

class RatingSummary {
  const RatingSummary(this.ratings);
  final List<Rating> ratings;

  /// Below this, an average is shown but flagged as not yet reliable.
  static const minReliableCount = 3;

  int get count => ratings.length;
  bool get isReliable => count >= minReliableCount;

  double _avg(int Function(Rating) f) {
    final vals = ratings.map(f).where((v) => v > 0).toList();
    return vals.isEmpty ? 0 : vals.reduce((a, b) => a + b) / vals.length;
  }

  double get average => _avg((r) => r.stars);
  double get flavor => _avg((r) => r.flavor);
  double get presentation => _avg((r) => r.presentation);
  double get ease => _avg((r) => r.ease);
  double get value => _avg((r) => r.value);
}

class Comment {
  const Comment({
    required this.id,
    required this.userId,
    required this.versionId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String versionId;
  final String text;
  final DateTime createdAt;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.route,
    this.read = false,
  });

  final String id;

  /// Recipient of the notification.
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? route;
  final bool read;

  AppNotification markRead() =>
      AppNotification(id: id, userId: userId, title: title, body: body, createdAt: createdAt, route: route, read: true);
}
