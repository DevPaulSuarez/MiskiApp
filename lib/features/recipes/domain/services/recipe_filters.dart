import '../entities/recipe.dart';

/// "Tamaño": how many people the dish serves (main version).
enum SizeFilter {
  any('Cualquiera'),
  small('1–2 personas'),
  medium('3–4 personas'),
  large('5 o más');

  const SizeFilter(this.label);
  final String label;

  bool matches(int servings) => switch (this) {
    SizeFilter.any => true,
    SizeFilter.small => servings <= 2,
    SizeFilter.medium => servings >= 3 && servings <= 4,
    SizeFilter.large => servings >= 5,
  };
}

/// "Tiempo": total minutes (prep + cooking) of the main version.
enum TimeFilter {
  any('Cualquiera'),
  upTo15('Hasta 15 min'),
  upTo30('Hasta 30 min'),
  upTo60('Hasta 1 h'),
  over60('Más de 1 h');

  const TimeFilter(this.label);
  final String label;

  bool matches(int minutes) => switch (this) {
    TimeFilter.any => true,
    TimeFilter.upTo15 => minutes <= 15,
    TimeFilter.upTo30 => minutes <= 30,
    TimeFilter.upTo60 => minutes <= 60,
    TimeFilter.over60 => minutes > 60,
  };
}

enum RecipeSort {
  /// Highest average first; averages with too few reviews go after reliable ones.
  bestRated('Mejores reseñas'),

  /// Most reviews first.
  mostVoted('Más votadas');

  const RecipeSort(this.label);
  final String label;
}

class RecipeFilters {
  const RecipeFilters({
    this.categoryId,
    this.size = SizeFilter.any,
    this.time = TimeFilter.any,
    this.sort = RecipeSort.bestRated,
  });

  final String? categoryId;
  final SizeFilter size;
  final TimeFilter time;
  final RecipeSort sort;

  /// Filters that narrow the list (sorting alone doesn't count).
  int get activeCount =>
      (categoryId != null ? 1 : 0) + (size != SizeFilter.any ? 1 : 0) + (time != TimeFilter.any ? 1 : 0);

  RecipeFilters copyWith({String? Function()? categoryId, SizeFilter? size, TimeFilter? time, RecipeSort? sort}) =>
      RecipeFilters(
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        size: size ?? this.size,
        time: time ?? this.time,
        sort: sort ?? this.sort,
      );
}

typedef RatingStats = ({double average, int count, bool reliable});

/// Applies [filters] to [recipes] and sorts them.
List<Recipe> applyRecipeFilters(
  List<Recipe> recipes,
  RecipeFilters filters, {
  required RecipeVersion? Function(Recipe) mainVersionOf,
  required RatingStats Function(Recipe) ratingOf,
}) {
  final out = recipes.where((r) {
    if (filters.categoryId != null && r.categoryId != filters.categoryId) return false;
    final v = mainVersionOf(r);
    if (v == null) return filters.size == SizeFilter.any && filters.time == TimeFilter.any;
    return filters.size.matches(v.servings) && filters.time.matches(v.totalMinutes);
  }).toList();

  final stats = {for (final r in out) r.id: ratingOf(r)};
  out.sort((a, b) {
    final sa = stats[a.id]!, sb = stats[b.id]!;
    switch (filters.sort) {
      case RecipeSort.mostVoted:
        final byCount = sb.count.compareTo(sa.count);
        return byCount != 0 ? byCount : sb.average.compareTo(sa.average);
      case RecipeSort.bestRated:
        if (sa.reliable != sb.reliable) return sa.reliable ? -1 : 1;
        final byAvg = sb.average.compareTo(sa.average);
        return byAvg != 0 ? byAvg : sb.count.compareTo(sa.count);
    }
  });
  return out;
}

/// Best dishes by reviews received in the [days] before [now]: higher average first, then more reviews.
List<({String recipeId, double average, int count})> bestOfPeriod(
  Iterable<({String recipeId, int stars, DateTime createdAt})> ratings, {
  required DateTime now,
  int days = 7,
}) {
  final from = now.subtract(Duration(days: days));
  final byRecipe = <String, List<int>>{};
  for (final r in ratings) {
    if (r.createdAt.isBefore(from) || r.createdAt.isAfter(now)) continue;
    byRecipe.putIfAbsent(r.recipeId, () => []).add(r.stars);
  }
  final out =
      [
        for (final e in byRecipe.entries)
          (recipeId: e.key, average: e.value.reduce((a, b) => a + b) / e.value.length, count: e.value.length),
      ]..sort((a, b) {
        final byAvg = b.average.compareTo(a.average);
        return byAvg != 0 ? byAvg : b.count.compareTo(a.count);
      });
  return out;
}
