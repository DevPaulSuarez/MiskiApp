import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miski_app/core/network/api_client.dart';
import 'package:miski_app/core/network/api_exception.dart';
import 'package:miski_app/core/session/api_sync_repository.dart';
import 'package:miski_app/features/recipes/data/api_recipe_repositories.dart';
import 'package:miski_app/features/recipes/domain/entities/measure_unit.dart';
import 'package:miski_app/features/recipes/domain/entities/recipe.dart';
import 'package:miski_app/features/recipes/domain/repositories/recipe_repository.dart';

/// JSON in the exact shape the Laravel resources return.
final _sync = {
  'server_time': '2026-11-21T10:00:00Z',
  'me': {
    'id': '1',
    'name': 'Paul Suárez',
    'handle': '@paul',
    'bio': '',
    'birthday': '1995-03-18',
    'favorite_category_ids': ['3'],
    'favorite_foods': ['Ceviche'],
    'email': 'paul@miski.test',
  },
  'users': [
    {
      'id': '1',
      'name': 'Paul Suárez',
      'handle': '@paul',
      'bio': '',
      'birthday': null,
      'favorite_category_ids': [],
      'favorite_foods': [],
    },
  ],
  'categories': [
    {'id': '3', 'name': 'Platos principales', 'emoji': '🍽️'},
  ],
  'ingredients': [
    {'id': '1', 'name': 'Filete de tilapia', 'category': 'Pescados', 'default_unit': 'gram', 'description': ''},
  ],
  'recipes': [
    {
      'id': '1',
      'name': 'Ceviche',
      'description': '',
      'image_url': 'http://192.168.1.5:8000/storage/recipes/a.jpg',
      'category_id': '3',
      'author_id': '1',
      'created_at': '2026-11-01T12:00:00Z',
      'main_version_id': '2',
      'status': 'active',
    },
  ],
  'versions': [
    {
      'id': '2',
      'recipe_id': '1',
      'number': 1,
      'title': 'Versión original',
      'parent_version_id': null,
      'created_by': '1',
      'created_at': '2026-11-01T12:00:00Z',
      'servings': 2,
      'prep_minutes': 20,
      'cook_minutes': 0,
      'difficulty': 'easy',
      'notes': '',
      'ingredients': [
        {
          'ingredient_id': '1',
          'quantity': 500,
          'unit': 'gram',
          'note': '',
          'purchase': {'price': 12.5, 'quantity': 1, 'unit': 'kilogram'},
        },
      ],
      'steps': ['Cortar', 'Marinar'],
    },
  ],
  'ratings': [
    {
      'id': '1',
      'user_id': '1',
      'recipe_id': '1',
      'version_id': '2',
      'invitation_id': null,
      'stars': 5,
      'flavor': 5,
      'presentation': 0,
      'ease': 0,
      'value': 0,
      'comment': '',
      'created_at': '2026-11-02T12:00:00Z',
    },
  ],
  'comments': [],
  'invitations': [],
  'notifications': [
    {
      'id': '9',
      'user_id': '1',
      'title': 'Hola',
      'body': '...',
      'route': '/invitations',
      'read': false,
      'created_at': '2026-11-02T12:00:00Z',
    },
  ],
  'favorite_recipe_ids': ['1'],
};

void main() {
  test('parses the sync snapshot and sends the token', () async {
    late http.Request sent;
    final api = ApiClient(
      baseUrl: 'http://server/api/v1',
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode(_sync), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    )..token = 'abc';

    final s = await ApiSyncRepository(api).fetch();

    expect(sent.url.toString(), 'http://server/api/v1/sync');
    expect(sent.headers['Authorization'], 'Bearer abc');
    expect(s.me.name, 'Paul Suárez');
    expect(s.email, 'paul@miski.test');
    expect(s.me.birthday, DateTime(1995, 3, 18));
    final v = s.versions.single;
    expect(v.difficulty, Difficulty.easy);
    expect(v.ingredients.single.quantity, 500);
    expect(v.ingredients.single.purchase!.unit, MeasureUnit.kilogram);
    expect(v.steps, ['Cortar', 'Marinar']);
    expect(s.recipes.single.mainVersionId, '2');
    expect(s.notifications.single.read, isFalse);
    expect(s.favoriteRecipeIds, {'1'});
  });

  test('validation errors become readable messages per field', () async {
    final api = ApiClient(
      baseUrl: 'http://server/api/v1',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'version.steps': ['El campo pasos es obligatorio.'],
            },
          }),
          422,
        ),
      ),
    );
    final repo = ApiRecipeRepository(api);
    const draft = VersionDraft(
      title: '',
      servings: 2,
      prepMinutes: 10,
      cookMinutes: 0,
      difficulty: Difficulty.easy,
      ingredients: [],
      steps: [],
    );

    final error = await repo
        .createDish(const DishDraft(name: 'X', description: '', imageUrl: '', categoryId: '3'), draft)
        .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);

    expect(error!.message, 'El campo pasos es obligatorio.');
    expect(error.errorFor('version.steps'), 'El campo pasos es obligatorio.');
    expect(error.statusCode, 422);
  });

  test('an expired token signs the user out', () async {
    var expired = false;
    final api = ApiClient(
      baseUrl: 'http://server/api/v1',
      httpClient: MockClient((_) async => http.Response('{"message":"Unauthenticated."}', 401)),
      onUnauthorized: () => expired = true,
    );
    await expectLater(
      api.get('sync'),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauthorized', true)),
    );
    expect(expired, isTrue);
  });

  test('no connection gives a clear message', () async {
    final api = ApiClient(
      baseUrl: 'http://server/api/v1',
      httpClient: MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    await expectLater(api.get('sync'), throwsA(ApiException.offline));
  });
}
