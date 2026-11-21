<?php

namespace App\Modules\Catalog\Enums;

/** Same names as the app's MeasureUnit enum. Conversion only within a dimension. */
enum MeasureUnit: string
{
    case Gram = 'gram';
    case Kilogram = 'kilogram';
    case Milliliter = 'milliliter';
    case Liter = 'liter';
    case Teaspoon = 'teaspoon';
    case Tablespoon = 'tablespoon';
    case Cup = 'cup';
    case Unit = 'unit';

    public function dimension(): string
    {
        return match ($this) {
            self::Gram, self::Kilogram => 'mass',
            self::Unit => 'count',
            default => 'volume',
        };
    }

    public function isCompatibleWith(self $other): bool
    {
        return $this->dimension() === $other->dimension();
    }
}
