import 'package:flutter_test/flutter_test.dart';
import 'package:miski_app/core/mock/mock_data.dart';
import 'package:miski_app/features/recipes/domain/entities/measure_unit.dart';
import 'package:miski_app/features/recipes/domain/entities/recipe.dart';
import 'package:miski_app/features/recipes/domain/services/recipe_calculators.dart';
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
}
