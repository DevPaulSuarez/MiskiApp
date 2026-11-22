// Exports the app's mock data to JSON for the backend demo seeder:
//   dart run tool/export_mock_data.dart > backend/database/seeders/data/demo.json
import 'dart:convert';
import 'dart:io';

import 'package:miski_app/core/mock/mock_data.dart';

String _d(DateTime d) => d.toUtc().toIso8601String();

void main() {
  final data = {
    'users': [
      for (final u in MockData.users)
        {
          'key': u.id,
          'name': u.name,
          'handle': u.handle.replaceFirst('@', ''),
          'bio': u.bio,
          'birthday': u.birthday?.toIso8601String().substring(0, 10),
          'favorite_category_keys': u.favoriteCategoryIds,
          'favorite_foods': u.favoriteFoods,
        },
    ],
    'categories': [
      for (final c in MockData.categories) {'key': c.id, 'name': c.name, 'emoji': c.emoji},
    ],
    'ingredients': [
      for (final i in MockData.ingredients)
        {
          'key': i.id,
          'name': i.name,
          'category': i.category,
          'default_unit': i.defaultUnit.name,
          'description': i.description,
        },
    ],
    'recipes': [
      for (final r in MockData.recipes)
        {
          'key': r.id,
          'name': r.name,
          'description': r.description,
          'image_url': r.imageUrl,
          'category_key': r.categoryId,
          'author_key': r.authorId,
          'created_at': _d(r.createdAt),
          'main_version_key': r.mainVersionId,
          'status': r.status.name,
        },
    ],
    'versions': [
      for (final v in MockData.versions)
        {
          'key': v.id,
          'recipe_key': v.recipeId,
          'number': v.number,
          'title': v.title,
          'parent_key': v.parentVersionId,
          'created_by_key': v.createdBy,
          'created_at': _d(v.createdAt),
          'servings': v.servings,
          'prep_minutes': v.prepMinutes,
          'cook_minutes': v.cookMinutes,
          'difficulty': v.difficulty.name,
          'notes': v.notes,
          'ingredients': [
            for (final i in v.ingredients)
              {
                'ingredient_key': i.ingredientId,
                'quantity': i.quantity,
                'unit': i.unit.name,
                'note': i.note,
                'purchase': i.purchase == null
                    ? null
                    : {'price': i.purchase!.price, 'quantity': i.purchase!.quantity, 'unit': i.purchase!.unit.name},
              },
          ],
          'steps': v.steps,
        },
    ],
    'invitations': [
      for (final i in MockData.invitations)
        {
          'key': i.id,
          'recipe_key': i.recipeId,
          'version_key': i.versionId,
          'from_key': i.fromUserId,
          'to_key': i.toUserId,
          'message': i.message,
          'status': i.status.name,
          'created_at': _d(i.createdAt),
        },
    ],
    'ratings': [
      for (final r in MockData.ratings)
        {
          'user_key': r.userId,
          'recipe_key': r.recipeId,
          'version_key': r.versionId,
          'invitation_key': r.invitationId,
          'stars': r.stars,
          'flavor': r.flavor,
          'presentation': r.presentation,
          'ease': r.ease,
          'value': r.value,
          'comment': r.comment,
          'created_at': _d(r.createdAt),
        },
    ],
    'comments': [
      for (final c in MockData.comments)
        {'user_key': c.userId, 'version_key': c.versionId, 'text': c.text, 'created_at': _d(c.createdAt)},
    ],
    'notifications': [
      for (final n in MockData.notifications)
        {
          'user_key': n.userId,
          'title': n.title,
          'body': n.body,
          'route': n.route,
          'read': n.read,
          'created_at': _d(n.createdAt),
        },
    ],
    'favorites': [
      for (final id in MockData.favoriteRecipeIds) {'user_key': MockData.currentUserId, 'recipe_key': id},
    ],
  };
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(data));
}
