import '../entities/recipe.dart';

/// Short connector words ignored when comparing dish names or search terms.
const dishStopwords = {'de', 'del', 'la', 'el', 'los', 'las', 'con', 'y', 'en', 'al', 'a', 'un', 'una'};

/// Lower-case words longer than 2 letters, without connectors.
List<String> meaningfulWords(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-záéíóúüñ0-9]+'))
    .where((w) => w.length > 2 && !dishStopwords.contains(w))
    .toList();

/// Share of ingredients two preparations have in common (Jaccard: shared / all distinct), 0..1.
double ingredientSimilarity(Iterable<String> a, Iterable<String> b) {
  final sa = a.toSet(), sb = b.toSet();
  if (sa.isEmpty && sb.isEmpty) return 0;
  return sa.intersection(sb).length / sa.union(sb).length;
}

class DishMatch {
  const DishMatch({required this.recipe, required this.version, required this.similarity});
  final Recipe recipe;

  /// The existing version closest to the new preparation (used as its parent).
  final RecipeVersion version;
  final double similarity;

  int get percent => (similarity * 100).round();
}

/// Finds existing dishes a "new recipe" probably duplicates, so it can be
/// saved as one more version of that dish instead.
class DishMatcher {
  const DishMatcher({this.threshold = 0.7});

  /// Minimum ingredient similarity to suggest merging into an existing dish.
  final double threshold;

  /// Active dishes whose name shares a meaningful word with [name].
  List<Recipe> byName(String name, List<Recipe> recipes) {
    final words = meaningfulWords(name).toSet();
    if (words.isEmpty) return const [];
    return recipes
        .where((r) => r.status == RecipeStatus.active && meaningfulWords(r.name).any(words.contains))
        .toList();
  }

  /// Most similar active dish by ingredients, if it reaches [threshold].
  /// The returned version is the closest one (the dish's main version on ties).
  DishMatch? byIngredients(
    Iterable<String> ingredientIds,
    List<Recipe> recipes,
    List<RecipeVersion> versions,
  ) {
    final active = {for (final r in recipes) if (r.status == RecipeStatus.active) r.id: r};
    DishMatch? best;
    for (final v in versions) {
      final recipe = active[v.recipeId];
      if (recipe == null) continue;
      final s = ingredientSimilarity(ingredientIds, v.ingredients.map((i) => i.ingredientId));
      if (s < threshold) continue;
      // On ties prefer the dish's main version as the base.
      final better = best == null ||
          s > best.similarity ||
          (s == best.similarity && v.id == recipe.mainVersionId && best.version.id != best.recipe.mainVersionId);
      if (better) {
        best = DishMatch(recipe: recipe, version: v, similarity: s);
      }
    }
    return best;
  }
}

/// One person's way of preparing a dish: their best-rated version (latest on ties).
class Preparation {
  const Preparation({required this.version, required this.average, required this.ratingCount});
  final RecipeVersion version;
  final double average;
  final int ratingCount;

  String get authorId => version.createdBy;
}

/// Groups a dish's versions by author, keeping each author's best version,
/// sorted by rating (then number of ratings, then most recent).
List<Preparation> preparationsByAuthor(
  List<RecipeVersion> versions,
  ({double average, int count}) Function(String versionId) ratingOf,
) {
  final best = <String, Preparation>{};
  for (final v in versions) {
    final r = ratingOf(v.id);
    final p = Preparation(version: v, average: r.average, ratingCount: r.count);
    final current = best[v.createdBy];
    if (current == null || _compare(p, current) < 0) best[v.createdBy] = p;
  }
  return best.values.toList()..sort(_compare);
}

int _compare(Preparation a, Preparation b) {
  final byAvg = b.average.compareTo(a.average);
  if (byAvg != 0) return byAvg;
  final byCount = b.ratingCount.compareTo(a.ratingCount);
  if (byCount != 0) return byCount;
  return b.version.createdAt.compareTo(a.version.createdAt);
}
