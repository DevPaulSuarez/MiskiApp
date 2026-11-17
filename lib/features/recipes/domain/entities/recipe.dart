import 'measure_unit.dart';

enum Difficulty {
  easy('Fácil'),
  medium('Media'),
  hard('Difícil');

  const Difficulty(this.label);
  final String label;
}

enum RecipeStatus { active, archived }

/// Categories are data, not an enum, so new ones can be added freely.
class RecipeCategory {
  const RecipeCategory({required this.id, required this.name, required this.emoji});
  final String id;
  final String name;
  final String emoji;
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultUnit,
    this.description = '',
  });

  final String id;
  final String name;
  final String category;
  final MeasureUnit defaultUnit;
  final String description;
}

class PurchaseInfo {
  const PurchaseInfo({required this.price, required this.quantity, required this.unit});
  final double price;
  final double quantity;
  final MeasureUnit unit;
}

/// An ingredient as used inside one specific version.
class VersionIngredient {
  const VersionIngredient({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.purchase,
  });

  final String ingredientId;
  final double quantity;
  final MeasureUnit unit;
  final String note;
  final PurchaseInfo? purchase;

  VersionIngredient copyWith({
    double? quantity,
    MeasureUnit? unit,
    String? note,
    PurchaseInfo? purchase,
  }) =>
      VersionIngredient(
        ingredientId: ingredientId,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        note: note ?? this.note,
        purchase: purchase ?? this.purchase,
      );
}

/// Immutable snapshot of a preparation. Editing always creates a new version.
class RecipeVersion {
  const RecipeVersion({
    required this.id,
    required this.recipeId,
    required this.number,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.difficulty,
    required this.ingredients,
    required this.steps,
    this.parentVersionId,
    this.notes = '',
  });

  final String id;
  final String recipeId;
  final int number;
  final String title;
  final String? parentVersionId;
  final String createdBy;
  final DateTime createdAt;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final Difficulty difficulty;
  final List<VersionIngredient> ingredients;
  final List<String> steps;
  final String notes;

  int get totalMinutes => prepMinutes + cookMinutes;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.categoryId,
    required this.authorId,
    required this.createdAt,
    required this.mainVersionId,
    this.status = RecipeStatus.active,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final String categoryId;
  final String authorId;
  final DateTime createdAt;
  final String mainVersionId;
  final RecipeStatus status;

  Recipe copyWith({String? mainVersionId, RecipeStatus? status}) => Recipe(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        categoryId: categoryId,
        authorId: authorId,
        createdAt: createdAt,
        mainVersionId: mainVersionId ?? this.mainVersionId,
        status: status ?? this.status,
      );
}
