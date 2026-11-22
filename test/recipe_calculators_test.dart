import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/core/mock/mock_data.dart';
import 'package:miski_app/features/recipes/domain/entities/measure_unit.dart';
import 'package:miski_app/features/recipes/domain/entities/recipe.dart';
import 'package:miski_app/features/recipes/domain/services/dish_matcher.dart';
import 'package:miski_app/features/recipes/domain/services/recipe_calculators.dart';
import 'package:miski_app/features/recipes/domain/services/recipe_filters.dart';
import 'package:miski_app/features/social/domain/social_entities.dart';

RecipeVersion v(String id) => MockData.versions.firstWhere((x) => x.id == id);

void main() {
  test('serving factor: 2 -> 6 people triples quantities', () {
    const calc = ServingCalculator();
    final f = calc.factor(originalServings: 2, desiredServings: 6);
    expect(calc.scale(500, f), 1500);
  });

  test('unit conversion only within the same dimension', () {
    expect(MeasureUnit.kilogram.convert(1, MeasureUnit.gram), 1000);
    expect(MeasureUnit.tablespoon.convert(2, MeasureUnit.milliliter), 30);
    expect(() => MeasureUnit.gram.convert(1, MeasureUnit.liter), throwsArgumentError);
  });

  test('cost is proportional to the quantity used (500 g of a \$12/kg tilapia = \$6)', () {
    const line = VersionIngredient(
      ingredientId: 'i1',
      quantity: 500,
      unit: MeasureUnit.gram,
      purchase: PurchaseInfo(price: 12, quantity: 1, unit: MeasureUnit.kilogram),
    );
    expect(const CostCalculator().lineCost(line, 500), closeTo(6, 1e-9));
  });

  test('scaling servings scales total cost but not per-person cost', () {
    const calc = CostCalculator();
    final base = calc.breakdown(v('v1'));
    final doubled = calc.breakdown(v('v1'), servings: 4);
    expect(doubled.total, closeTo(base.total * 2, 1e-9));
    expect(doubled.perServing, closeTo(base.perServing, 1e-9));
    // Stored quantities are untouched.
    expect(v('v1').ingredients.first.quantity, 500);
  });

  test('compare V1 vs V2: more lemon, less onion', () {
    final diff = const VersionComparator().compare(v('v1'), v('v2'));
    expect(diff.added, isEmpty);
    expect(diff.removed, isEmpty);
    expect(diff.changed.map((c) => c.before.ingredientId), containsAll(['i2', 'i3']));
  });

  test('compare V2 vs V3: added/removed ingredients and reordered steps', () {
    final diff = const VersionComparator().compare(v('v2'), v('v3'));
    expect(diff.added.map((i) => i.ingredientId), containsAll(['i9', 'i10', 'i11', 'i12']));
    expect(diff.removed.map((i) => i.ingredientId), containsAll(['i4', 'i8']));
    expect(diff.stepsReordered, isTrue);
  });

  test('rating summary flags low-count averages as not reliable', () {
    final v3 = RatingSummary(MockData.ratings.where((r) => r.versionId == 'v3').toList());
    final v2 = RatingSummary(MockData.ratings.where((r) => r.versionId == 'v2').toList());
    expect(v3.average, 5);
    expect(v3.isReliable, isFalse);
    expect(v2.isReliable, isTrue);
  });

  test('ingredient change summary lists only added and removed ingredients', () {
    String nameOf(String id) => MockData.ingredients.firstWhere((i) => i.id == id).name;
    final s = const VersionComparator().ingredientChanges(v('v2'), v('v3'), nameOf);
    expect(s.added, ['Rocoto', 'Kion (jengibre)', 'Apio', 'Cancha serrana']);
    expect(s.removed, ['Ají limo', 'Choclo']);
    // Culantro went 10 g -> 15 g: quantity changes are not reported.
    expect(s.describe(), isNot(contains('Culantro')));
    expect(s.describe(), 'Agregó: Rocoto, Kion (jengibre), Apio, Cancha serrana · Quitó: Ají limo, Choclo');
  });

  test('same ingredients means no ingredient changes', () {
    final s = const VersionComparator().ingredientChanges(v('v2'), v('v2'), (id) => id);
    expect(s.isEmpty, isTrue);
    expect(s.describe(), 'Sin cambios de ingredientes');
  });

  test('days until birthday wraps to next year and handles today', () {
    final u = MockData.users.firstWhere((u) => u.id == 'u3'); // 9 dic
    expect(u.daysUntilBirthday(DateTime(2026, 11, 19)), 20);
    expect(u.daysUntilBirthday(DateTime(2026, 12, 9, 18)), 0);
    expect(u.daysUntilBirthday(DateTime(2026, 12, 10)), 364);
  });

  group('dish matcher', () {
    const matcher = DishMatcher();

    test('ingredient similarity is shared over all distinct ingredients', () {
      expect(ingredientSimilarity(['a', 'b', 'c'], ['a', 'b', 'd']), 0.5);
      expect(ingredientSimilarity(['a'], ['a']), 1);
      expect(ingredientSimilarity(<String>[], <String>[]), 0);
    });

    test('name match ignores connector words', () {
      final hits = matcher.byName('Ceviche de Paul', MockData.recipes);
      expect(hits.map((r) => r.id), ['r1']);
      expect(matcher.byName('de la con', MockData.recipes), isEmpty);
    });

    test('a ceviche with one ingredient swapped is detected as the same dish', () {
      // V2 without choclo (i8), plus cancha (i12): 7 of 9 distinct ingredients shared.
      // V1 has the same ingredients as V2; the main version (V2) wins the tie.
      final mine = ['i1', 'i2', 'i3', 'i4', 'i5', 'i6', 'i7', 'i12'];
      final m = matcher.byIngredients(mine, MockData.recipes, MockData.versions)!;
      expect(m.recipe.id, 'r1');
      expect(m.version.id, 'v2');
      expect(m.percent, 78);
    });

    test('a different dish is not matched', () {
      // Salmon, lemon and ice cream: no existing dish shares 70% of these.
      expect(matcher.byIngredients(['i20', 'i2', 'i25'], MockData.recipes, MockData.versions), isNull);
    });

    test('preparations keep each author best version, best rated first', () {
      final ceviche = MockData.versions.where((x) => x.recipeId == 'r1').toList();
      final ratings = {'v1': (average: 4.0, count: 4), 'v2': (average: 4.5, count: 4), 'v3': (average: 5.0, count: 1)};
      final preps = preparationsByAuthor(ceviche, (id) => ratings[id] ?? (average: 0.0, count: 0));
      expect(preps.map((p) => p.authorId), ['u3', 'u2', 'u1']);
    });
  });

  group('recipe filters', () {
    final byId = {for (final x in MockData.versions) x.id: x};
    RatingStats rating(String id) => switch (id) {
      'r1' => (average: 4.5, count: 10, reliable: true),
      'r2' => (average: 5.0, count: 1, reliable: false),
      'r3' => (average: 4.0, count: 20, reliable: true),
      _ => (average: 0.0, count: 0, reliable: false),
    };
    List<String> run(RecipeFilters f) => applyRecipeFilters(
      MockData.recipes,
      f,
      mainVersionOf: (r) => byId[r.mainVersionId],
      ratingOf: (r) => rating(r.id),
    ).map((r) => r.id).toList();

    test('best rated puts reliable averages first', () {
      expect(run(const RecipeFilters()).take(3), ['r1', 'r3', 'r2']);
    });

    test('most voted sorts by number of reviews', () {
      expect(run(const RecipeFilters(sort: RecipeSort.mostVoted)).take(2), ['r3', 'r1']);
    });

    test('size and time use the main version', () {
      for (final id in run(const RecipeFilters(size: SizeFilter.small, time: TimeFilter.upTo30))) {
        final v = byId[MockData.recipes.firstWhere((r) => r.id == id).mainVersionId]!;
        expect(v.servings <= 2 && v.totalMinutes <= 30, isTrue);
      }
      expect(
        run(const RecipeFilters(categoryId: 'c4'))
            .every((id) => MockData.recipes.firstWhere((r) => r.id == id).categoryId == 'c4'),
        isTrue,
      );
    });

    test('best of the week only counts reviews from the last 7 days', () {
      final now = DateTime(2026, 11, 19);
      final best = bestOfPeriod([
        (recipeId: 'a', stars: 5, createdAt: DateTime(2026, 11, 18)),
        (recipeId: 'a', stars: 4, createdAt: DateTime(2026, 11, 17)),
        (recipeId: 'b', stars: 5, createdAt: DateTime(2026, 11, 15)),
        (recipeId: 'c', stars: 5, createdAt: DateTime(2026, 11, 1)), // too old
      ], now: now);
      expect(best.map((e) => e.recipeId), ['b', 'a']);
      expect(best.last.average, 4.5);
    });
  });
}
