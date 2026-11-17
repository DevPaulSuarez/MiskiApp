import '../entities/recipe.dart';

/// Scales quantities without touching the stored values.
class ServingCalculator {
  const ServingCalculator();

  double factor({required int originalServings, required int desiredServings}) =>
      desiredServings / originalServings;

  double scale(double quantity, double factor) => quantity * factor;
}

class IngredientCost {
  const IngredientCost({
    required this.ingredientId,
    required this.usedQuantity,
    required this.line,
    required this.cost,
  });

  final String ingredientId;
  final double usedQuantity;
  final VersionIngredient line;

  /// Null when there is no purchase info or units are incompatible.
  final double? cost;
}

class CostBreakdown {
  const CostBreakdown({required this.lines, required this.servings});
  final List<IngredientCost> lines;
  final int servings;

  double get total => lines.fold(0, (sum, l) => sum + (l.cost ?? 0));
  double get perServing => servings == 0 ? 0 : total / servings;
  int get missingPrices => lines.where((l) => l.cost == null).length;
}

/// Cost of the quantity actually used, proportional to the purchase.
class CostCalculator {
  const CostCalculator();

  double? lineCost(VersionIngredient line, double usedQuantity) {
    final p = line.purchase;
    if (p == null || p.quantity <= 0 || !line.unit.isCompatibleWith(p.unit)) return null;
    final usedInPurchaseUnit = line.unit.convert(usedQuantity, p.unit);
    return p.price * usedInPurchaseUnit / p.quantity;
  }

  CostBreakdown breakdown(RecipeVersion version, {int? servings}) {
    final desired = servings ?? version.servings;
    final factor = desired / version.servings;
    return CostBreakdown(
      servings: desired,
      lines: [
        for (final line in version.ingredients)
          IngredientCost(
            ingredientId: line.ingredientId,
            usedQuantity: line.quantity * factor,
            line: line,
            cost: lineCost(line, line.quantity * factor),
          ),
      ],
    );
  }
}

class IngredientChange {
  const IngredientChange(this.before, this.after);
  final VersionIngredient before;
  final VersionIngredient after;
}

class VersionDiff {
  const VersionDiff({
    required this.added,
    required this.removed,
    required this.changed,
    required this.stepsAdded,
    required this.stepsRemoved,
    required this.stepsReordered,
  });

  final List<VersionIngredient> added;
  final List<VersionIngredient> removed;
  final List<IngredientChange> changed;
  final List<String> stepsAdded;
  final List<String> stepsRemoved;
  final bool stepsReordered;
}

class VersionComparator {
  const VersionComparator();

  VersionDiff compare(RecipeVersion a, RecipeVersion b) {
    final aMap = {for (final i in a.ingredients) i.ingredientId: i};
    final bMap = {for (final i in b.ingredients) i.ingredientId: i};

    final changed = <IngredientChange>[];
    for (final entry in aMap.entries) {
      final other = bMap[entry.key];
      if (other == null) continue;
      final before = entry.value;
      final sameUnit = before.unit == other.unit;
      if (!sameUnit || (before.quantity - other.quantity).abs() > 1e-9) {
        changed.add(IngredientChange(before, other));
      }
    }

    final aSteps = a.steps.toSet();
    final bSteps = b.steps.toSet();
    final common = a.steps.where(bSteps.contains).toList();
    final commonInB = b.steps.where(aSteps.contains).toList();

    return VersionDiff(
      added: [for (final e in bMap.entries) if (!aMap.containsKey(e.key)) e.value],
      removed: [for (final e in aMap.entries) if (!bMap.containsKey(e.key)) e.value],
      changed: changed,
      stepsAdded: b.steps.where((s) => !aSteps.contains(s)).toList(),
      stepsRemoved: a.steps.where((s) => !bSteps.contains(s)).toList(),
      stepsReordered: common.join('|') != commonInB.join('|'),
    );
  }
}
