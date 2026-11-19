enum UnitDimension { mass, volume, count }

/// Units of measure. Conversion is only allowed inside the same dimension.
enum MeasureUnit {
  gram('g', 'Gramos', UnitDimension.mass, 1),
  kilogram('kg', 'Kilogramos', UnitDimension.mass, 1000),
  milliliter('ml', 'Mililitros', UnitDimension.volume, 1),
  liter('L', 'Litros', UnitDimension.volume, 1000),
  teaspoon('cdta', 'Cucharaditas', UnitDimension.volume, 5),
  tablespoon('cda', 'Cucharadas', UnitDimension.volume, 15),
  cup('taza', 'Tazas', UnitDimension.volume, 240),
  unit('und', 'Unidades', UnitDimension.count, 1);

  const MeasureUnit(this.symbol, this.label, this.dimension, this.baseFactor);

  final String symbol;
  final String label;
  final UnitDimension dimension;
  final double baseFactor;

  bool isCompatibleWith(MeasureUnit other) => dimension == other.dimension;

  Iterable<MeasureUnit> get compatibleUnits => MeasureUnit.values.where(isCompatibleWith);

  double convert(double quantity, MeasureUnit to) {
    if (!isCompatibleWith(to)) {
      throw ArgumentError('Cannot convert $symbol to ${to.symbol}');
    }
    return quantity * baseFactor / to.baseFactor;
  }
}
