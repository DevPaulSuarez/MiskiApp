import '../../features/auth/domain/auth_repository.dart';
import '../../features/profile/domain/profile_repository.dart';
import '../../features/recipes/domain/entities/measure_unit.dart';
import '../../features/recipes/domain/entities/recipe.dart';
import '../../features/recipes/domain/repositories/recipe_repository.dart';
import '../../features/recipes/domain/services/recipe_calculators.dart';
import '../../features/social/domain/social_entities.dart';
import '../../features/social/domain/social_repository.dart';
import '../mock/mock_data.dart';
import '../network/api_exception.dart';
import '../session/app_snapshot.dart';

/// In-memory stand-in for the Miski API, seeded with [MockData]. Used when the
/// app is built without MISKI_API_URL (demo mode) and by the widget tests.
/// It applies the same main rules as the server; the server stays the source of truth.
class DemoBackend
    implements
        AuthRepository,
        SyncRepository,
        RecipeRepository,
        CatalogRepository,
        SocialRepository,
        ProfileRepository {
  DemoBackend({String? signedInAs = MockData.currentUserId}) : _me = signedInAs;

  static const password = 'miski1234';

  String? _me;
  final _users = [...MockData.users];
  final _emails = {for (final u in MockData.users) u.id: '${u.handle.substring(1)}@miski.test'};
  final _ingredients = [...MockData.ingredients];
  final _recipes = [...MockData.recipes];
  final _versions = [...MockData.versions];
  final _ratings = [...MockData.ratings];
  final _comments = [...MockData.comments];
  final _invitations = [...MockData.invitations];
  final _notifications = [...MockData.notifications];
  final _favorites = <String, Set<String>>{
    MockData.currentUserId: {...MockData.favoriteRecipeIds},
  };
  int _seq = 0;

  String _id(String prefix) => '$prefix-demo-${++_seq}';

  String get _uid => _me ?? (throw const ApiException('Tu sesión expiró. Vuelve a iniciar sesión.', statusCode: 401));

  AppUser _user(String id) => _users.firstWhere((u) => u.id == id);

  void _notify(String to, String title, String body, String route) => _notifications.insert(
    0,
    AppNotification(id: _id('n'), userId: to, title: title, body: body, createdAt: DateTime.now(), route: route),
  );

  // --- Auth ---
  @override
  Future<AuthResult> login({required String email, required String password}) async {
    final id = _emails.entries.where((e) => e.value == email.trim().toLowerCase()).firstOrNull?.key;
    if (id == null || password != DemoBackend.password) {
      throw const ApiException(
        'El correo o la contraseña no son correctos.',
        statusCode: 422,
        fieldErrors: {
          'email': ['El correo o la contraseña no son correctos.'],
        },
      );
    }
    _me = id;
    return AuthResult(token: 'demo-$id', user: _user(id), email: _emails[id]!);
  }

  @override
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    DateTime? birthday,
  }) async {
    final mail = email.trim().toLowerCase();
    if (_emails.containsValue(mail)) {
      throw const ApiException(
        'Este correo ya está registrado.',
        statusCode: 422,
        fieldErrors: {
          'email': ['Este correo ya está registrado.'],
        },
      );
    }
    final user = AppUser(
      id: _id('u'),
      name: name.trim(),
      handle: '@${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}',
      bio: '',
      birthday: birthday,
    );
    _users.add(user);
    _emails[user.id] = mail;
    _me = user.id;
    return AuthResult(token: 'demo-${user.id}', user: user, email: mail);
  }

  @override
  Future<void> logout() async => _me = null;

  // --- Sync ---
  @override
  Future<AppSnapshot> fetch() async {
    final me = _uid;
    return AppSnapshot(
      me: _user(me),
      email: _emails[me]!,
      users: [..._users],
      categories: MockData.categories,
      ingredients: [..._ingredients],
      recipes: [
        for (final r in _recipes)
          if (r.status == RecipeStatus.active || r.authorId == me) r,
      ],
      versions: [..._versions],
      ratings: [..._ratings],
      comments: [..._comments],
      invitations: [
        for (final i in _invitations)
          if (i.fromUserId == me || i.toUserId == me) i,
      ],
      notifications: [
        for (final n in _notifications)
          if (n.userId == me) n,
      ],
      favoriteRecipeIds: {...?_favorites[me]},
    );
  }

  // --- Recipes ---
  @override
  Future<(Recipe, RecipeVersion)> createDish(DishDraft dish, VersionDraft draft) async {
    final recipeId = _id('r');
    final version = _version(recipeId, 1, null, draft);
    final recipe = Recipe(
      id: recipeId,
      name: dish.name.trim(),
      description: dish.description.trim(),
      imageUrl: dish.imageUrl,
      categoryId: dish.categoryId,
      authorId: _uid,
      createdAt: DateTime.now(),
      mainVersionId: version.id,
    );
    _recipes.insert(0, recipe);
    _versions.add(version);
    return (recipe, version);
  }

  @override
  Future<RecipeVersion> addVersion(String recipeId, String parentVersionId, VersionDraft draft) async {
    final recipe = _recipes.firstWhere((r) => r.id == recipeId);
    final parent = _versions.firstWhere((v) => v.id == parentVersionId && v.recipeId == recipeId);
    final number = _versions.where((v) => v.recipeId == recipeId).fold(0, (m, v) => v.number > m ? v.number : m) + 1;
    final version = _version(recipeId, number, parentVersionId, draft);
    _versions.add(version);

    if (recipe.authorId != _uid) {
      final changes = const VersionComparator().ingredientChanges(
        parent,
        version,
        (id) => _ingredients.firstWhere((i) => i.id == id).name,
      );
      _notify(
        recipe.authorId,
        '${_user(_uid).firstName} preparó tu plato a su manera',
        '${recipe.name} · V$number — ${changes.describe()}',
        '/version/${version.id}',
      );
    }
    return version;
  }

  RecipeVersion _version(String recipeId, int number, String? parentId, VersionDraft d) => RecipeVersion(
    id: _id('v'),
    recipeId: recipeId,
    number: number,
    title: d.title.trim().isNotEmpty ? d.title.trim() : (number == 1 ? 'Versión original' : 'Versión $number'),
    parentVersionId: parentId,
    createdBy: _uid,
    createdAt: DateTime.now(),
    servings: d.servings,
    prepMinutes: d.prepMinutes,
    cookMinutes: d.cookMinutes,
    difficulty: d.difficulty,
    ingredients: d.ingredients,
    steps: d.steps,
    notes: d.notes.trim(),
  );

  @override
  Future<Recipe> updateRecipe(String recipeId, {String? mainVersionId, RecipeStatus? status}) async {
    final i = _recipes.indexWhere((r) => r.id == recipeId);
    if (_recipes[i].authorId != _uid) throw const ApiException('No tienes permiso para hacer esto.', statusCode: 403);
    return _recipes[i] = _recipes[i].copyWith(mainVersionId: mainVersionId, status: status);
  }

  @override
  Future<Set<String>> setFavorite(String recipeId, {required bool favorite}) async {
    final set = _favorites.putIfAbsent(_uid, () => {});
    favorite ? set.add(recipeId) : set.remove(recipeId);
    return {...set};
  }

  @override
  Future<String> uploadImage(String filePath) async => filePath;

  @override
  Future<Ingredient> findOrCreateIngredient(String name, MeasureUnit defaultUnit) async {
    final clean = name.trim();
    final existing = _ingredients.where((i) => i.name.toLowerCase() == clean.toLowerCase()).firstOrNull;
    if (existing != null) return existing;
    final created = Ingredient(id: _id('i'), name: clean, category: 'Otros', defaultUnit: defaultUnit);
    _ingredients.add(created);
    return created;
  }

  // --- Social ---
  @override
  Future<List<Invitation>> sendInvitations({
    required String versionId,
    required List<String> toUserIds,
    String message = '',
  }) async {
    final version = _versions.firstWhere((v) => v.id == versionId);
    final sent = [
      for (final to in toUserIds)
        Invitation(
          id: _id('inv'),
          recipeId: version.recipeId,
          versionId: versionId,
          fromUserId: _uid,
          toUserId: to,
          message: message.trim(),
          createdAt: DateTime.now(),
        ),
    ];
    _invitations.insertAll(0, sent);
    return sent;
  }

  @override
  Future<Invitation> answerInvitation(String invitationId, {required bool accept}) async {
    final i = _invitations.indexWhere((x) => x.id == invitationId);
    final inv = _invitations[i];
    if (inv.toUserId != _uid) throw const ApiException('Solo la persona invitada puede responder.', statusCode: 403);
    if (inv.status != InvitationStatus.pending) throw const ApiException('Esta invitación ya fue respondida.');
    return _invitations[i] = inv.withStatus(accept ? InvitationStatus.accepted : InvitationStatus.rejected);
  }

  @override
  Future<List<Invitation>> fetchInvitations() async => [
    for (final i in _invitations)
      if (i.fromUserId == _uid || i.toUserId == _uid) i,
  ];

  @override
  Future<RatingResult> rate(RatingDraft d) async {
    final version = _versions.firstWhere((v) => v.id == d.versionId);
    Invitation? inv;
    if (d.invitationId != null) {
      if (_ratings.any((r) => r.invitationId == d.invitationId)) {
        throw const ApiException('Ya calificaste esta invitación.');
      }
      final i = _invitations.indexWhere((x) => x.id == d.invitationId);
      inv = _invitations[i] = _invitations[i].withStatus(InvitationStatus.completed);
    }
    final rating = Rating(
      id: _id('ra'),
      userId: _uid,
      recipeId: version.recipeId,
      versionId: version.id,
      invitationId: d.invitationId,
      stars: d.stars,
      flavor: d.flavor,
      presentation: d.presentation,
      ease: d.ease,
      value: d.value,
      comment: d.comment.trim(),
      createdAt: DateTime.now(),
    );
    _ratings.insert(0, rating);
    final comment = d.comment.trim().isEmpty ? null : await addComment(version.id, d.comment);
    return (rating: rating, comment: comment, invitation: inv);
  }

  @override
  Future<Comment> addComment(String versionId, String text) async {
    final c = Comment(id: _id('co'), userId: _uid, versionId: versionId, text: text.trim(), createdAt: DateTime.now());
    _comments.add(c);
    return c;
  }

  @override
  Future<List<AppNotification>> fetchNotifications() async => [
    for (final n in _notifications)
      if (n.userId == _uid) n,
  ];

  @override
  Future<void> markNotificationRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i >= 0) _notifications[i] = _notifications[i].markRead();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].userId == _uid) _notifications[i] = _notifications[i].markRead();
    }
  }

  // --- Profile ---
  @override
  Future<AppUser> updateProfile(ProfileUpdate u) async {
    final i = _users.indexWhere((x) => x.id == _uid);
    final old = _users[i];
    return _users[i] = AppUser(
      id: old.id,
      name: u.name ?? old.name,
      handle: u.handle == null ? old.handle : '@${u.handle!.replaceFirst('@', '').toLowerCase()}',
      bio: u.bio ?? old.bio,
      birthday: u.clearBirthday ? null : (u.birthday ?? old.birthday),
      favoriteCategoryIds: u.favoriteCategoryIds ?? old.favoriteCategoryIds,
      favoriteFoods: u.favoriteFoods ?? old.favoriteFoods,
    );
  }
}
