import '../domain/entities/measure_unit.dart';
import '../domain/entities/recipe.dart';
import '../domain/repositories/recipe_repository.dart';

typedef Json = Map<String, dynamic>;

DateTime parseDate(Object? v) => DateTime.parse(v as String).toLocal();

double _num(Object? v) => (v as num).toDouble();

abstract final class RecipeJson {
  static RecipeCategory category(Json j) =>
      RecipeCategory(id: j['id'] as String, name: j['name'] as String, emoji: j['emoji'] as String);

  static Ingredient ingredient(Json j) => Ingredient(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String? ?? 'Otros',
    defaultUnit: MeasureUnit.values.byName(j['default_unit'] as String),
    description: j['description'] as String? ?? '',
  );

  static Recipe recipe(Json j) => Recipe(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    imageUrl: j['image_url'] as String? ?? '',
    categoryId: j['category_id'] as String,
    authorId: j['author_id'] as String,
    createdAt: parseDate(j['created_at']),
    mainVersionId: j['main_version_id'] as String,
    status: RecipeStatus.values.byName(j['status'] as String),
  );

  static RecipeVersion version(Json j) => RecipeVersion(
    id: j['id'] as String,
    recipeId: j['recipe_id'] as String,
    number: j['number'] as int,
    title: j['title'] as String,
    parentVersionId: j['parent_version_id'] as String?,
    createdBy: j['created_by'] as String,
    createdAt: parseDate(j['created_at']),
    servings: j['servings'] as int,
    prepMinutes: j['prep_minutes'] as int,
    cookMinutes: j['cook_minutes'] as int,
    difficulty: Difficulty.values.byName(j['difficulty'] as String),
    notes: j['notes'] as String? ?? '',
    ingredients: [
      for (final i in (j['ingredients'] as List).cast<Json>())
        VersionIngredient(
          ingredientId: i['ingredient_id'] as String,
          quantity: _num(i['quantity']),
          unit: MeasureUnit.values.byName(i['unit'] as String),
          note: i['note'] as String? ?? '',
          purchase: switch (i['purchase']) {
            final Json p => PurchaseInfo(
              price: _num(p['price']),
              quantity: _num(p['quantity']),
              unit: MeasureUnit.values.byName(p['unit'] as String),
            ),
            _ => null,
          },
        ),
    ],
    steps: (j['steps'] as List).cast<String>(),
  );

  static Json versionDraft(VersionDraft d) => {
    'title': d.title,
    'servings': d.servings,
    'prep_minutes': d.prepMinutes,
    'cook_minutes': d.cookMinutes,
    'difficulty': d.difficulty.name,
    'notes': d.notes,
    'ingredients': [
      for (final i in d.ingredients)
        {
          'ingredient_id': int.tryParse(i.ingredientId) ?? i.ingredientId,
          'quantity': i.quantity,
          'unit': i.unit.name,
          'note': i.note,
          'purchase': i.purchase == null
              ? null
              : {'price': i.purchase!.price, 'quantity': i.purchase!.quantity, 'unit': i.purchase!.unit.name},
        },
    ],
    'steps': d.steps,
  };
}
