// End-to-end check of the app's data layer against a running API:
//   dart run tool/api_smoke_test.dart http://127.0.0.1:8000/api/v1
// Uses the demo accounts (php artisan migrate:fresh --seed). Creates real data.
import 'dart:convert';
import 'dart:io';

import 'package:miski_app/core/network/api_client.dart';
import 'package:miski_app/core/network/api_exception.dart';
import 'package:miski_app/core/session/api_sync_repository.dart';
import 'package:miski_app/features/auth/data/api_auth_repository.dart';
import 'package:miski_app/features/profile/data/api_profile_repository.dart';
import 'package:miski_app/features/profile/domain/profile_repository.dart';
import 'package:miski_app/features/recipes/data/api_recipe_repositories.dart';
import 'package:miski_app/features/recipes/domain/entities/measure_unit.dart';
import 'package:miski_app/features/recipes/domain/entities/recipe.dart';
import 'package:miski_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:miski_app/features/social/data/api_social_repository.dart';
import 'package:miski_app/features/social/domain/social_entities.dart';
import 'package:miski_app/features/social/domain/social_repository.dart';

void check(bool ok, String what) {
  stdout.writeln('${ok ? '✔' : '✘'} $what');
  if (!ok) exitCode = 1;
}

Future<ApiClient> signIn(String url, String email) async {
  final api = ApiClient(baseUrl: url);
  api.token = (await ApiAuthRepository(api).login(email: email, password: 'miski1234')).token;
  return api;
}

Future<void> main(List<String> args) async {
  final url = args.isEmpty ? 'http://127.0.0.1:8000/api/v1' : args.first;

  // Paul
  final paul = await signIn(url, 'paul@miski.test');
  var snap = await ApiSyncRepository(paul).fetch();
  check(snap.me.handle == '@paul' && snap.recipes.length == 8 && snap.versions.length == 10, 'sync carga datos demo');
  final ceviche = snap.recipes.firstWhere((r) => r.name == 'Ceviche peruano de tilapia');
  check(snap.versions.where((v) => v.recipeId == ceviche.id).length == 3, 'ceviche con 3 versiones');

  final recipes = ApiRecipeRepository(paul);
  final catalog = ApiCatalogRepository(paul);
  final papa = await catalog.findOrCreateIngredient('Papa amarilla', MeasureUnit.kilogram);
  final limon = await catalog.findOrCreateIngredient('limón', MeasureUnit.unit);
  check(limon.name == 'Limón', 'ingrediente existente se reutiliza');

  final draft = VersionDraft(
    title: '',
    servings: 4,
    prepMinutes: 40,
    cookMinutes: 25,
    difficulty: Difficulty.medium,
    ingredients: [
      VersionIngredient(
        ingredientId: papa.id,
        quantity: 1,
        unit: MeasureUnit.kilogram,
        purchase: const PurchaseInfo(price: 4.5, quantity: 1, unit: MeasureUnit.kilogram),
      ),
      VersionIngredient(ingredientId: limon.id, quantity: 3, unit: MeasureUnit.unit),
    ],
    steps: ['Sancochar las papas', 'Prensar y sazonar'],
  );
  final photo = File('${Directory.systemTemp.path}/miski_smoke.png')
    ..writeAsBytesSync(
      base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='),
    );
  final path = await recipes.uploadImage(photo.path);
  final (causa, v1) = await recipes.createDish(
    DishDraft(name: 'Causa limeña', description: 'Prueba', imageUrl: path, categoryId: snap.categories.first.id),
    draft,
  );
  check(v1.number == 1 && v1.title == 'Versión original' && causa.mainVersionId == v1.id, 'crear plato con V1');
  check(causa.imageUrl.startsWith('http') && causa.imageUrl.endsWith(path), 'foto subida: ${causa.imageUrl}');
  final img = await HttpClient().getUrl(Uri.parse(causa.imageUrl)).then((r) => r.close());
  check(img.statusCode == 200, 'la foto se puede descargar');
  check(v1.ingredients.first.purchase?.price == 4.5, 'precio de compra guardado');

  check((await recipes.setFavorite(causa.id, favorite: true)).contains(causa.id), 'favorito');

  // María prepares Paul's dish her way and gets invited
  final maria = await signIn(url, 'mariaq@miski.test');
  final mariaId = (await ApiSyncRepository(maria).fetch()).me.id;
  final rocoto = await ApiCatalogRepository(maria).findOrCreateIngredient('Rocoto', MeasureUnit.unit);
  final v2 = await ApiRecipeRepository(maria).addVersion(
    causa.id,
    v1.id,
    VersionDraft(
      title: 'Con rocoto',
      servings: 4,
      prepMinutes: 40,
      cookMinutes: 25,
      difficulty: Difficulty.medium,
      ingredients: [
        draft.ingredients.first,
        VersionIngredient(ingredientId: rocoto.id, quantity: 1, unit: MeasureUnit.unit),
      ],
      steps: draft.steps,
    ),
  );
  check(
    v2.number == 2 && v2.createdBy == mariaId && v2.parentVersionId == v1.id,
    'versión de otra persona dentro del plato',
  );

  try {
    await ApiRecipeRepository(maria).updateRecipe(causa.id, status: RecipeStatus.archived);
    check(false, 'solo el autor archiva');
  } on ApiException catch (e) {
    check(e.statusCode == 403, 'solo el autor archiva (${e.message})');
  }

  final social = ApiSocialRepository(paul);
  final notes = await social.fetchNotifications();
  check(
    notes.first.title == 'María preparó tu plato a su manera' && notes.first.body.contains('Agregó: Rocoto'),
    'aviso al autor: ${notes.first.body}',
  );

  final inv = (await social.sendInvitations(versionId: v1.id, toUserIds: [mariaId], message: '¡Ven a probar!')).single;
  final mariaSocial = ApiSocialRepository(maria);
  check((await mariaSocial.fetchNotifications()).first.title == 'Nueva invitación', 'invitación notificada');
  final accepted = await mariaSocial.answerInvitation(inv.id, accept: true);
  check(accepted.status == InvitationStatus.accepted, 'invitación aceptada');
  final res = await mariaSocial.rate(
    RatingDraft(versionId: v1.id, invitationId: inv.id, stars: 5, flavor: 5, comment: '¡Buenaza!'),
  );
  check(
    res.invitation?.status == InvitationStatus.completed && res.comment?.text == '¡Buenaza!',
    'calificar completa la invitación',
  );
  try {
    await mariaSocial.rate(RatingDraft(versionId: v1.id, invitationId: inv.id, stars: 4));
    check(false, 'una calificación por invitación');
  } on ApiException catch (e) {
    check(e.statusCode == 422, 'una calificación por invitación (${e.message})');
  }
  await mariaSocial.addComment(v1.id, 'La haré el domingo');

  await social.markAllNotificationsRead();
  check((await social.fetchNotifications()).every((n) => n.read), 'marcar notificaciones leídas');

  final me = await ApiProfileRepository(paul).updateProfile(const ProfileUpdate(favoriteFoods: ['Ceviche', 'Causa']));
  check(me.favoriteFoods.join(',') == 'Ceviche,Causa', 'perfil: comidas favoritas');

  snap = await ApiSyncRepository(paul).fetch();
  check(
    snap.recipes.any((r) => r.id == causa.id) && snap.comments.where((c) => c.versionId == v1.id).length == 2,
    'todo persiste en la base de datos',
  );

  await ApiAuthRepository(paul).logout();
  try {
    await ApiSyncRepository(paul).fetch();
    check(false, 'token revocado al cerrar sesión');
  } on ApiException catch (e) {
    check(e.isUnauthorized, 'token revocado al cerrar sesión');
  }
  stdout.writeln(exitCode == 0 ? '\nTodo OK' : '\nHay fallas');
}
