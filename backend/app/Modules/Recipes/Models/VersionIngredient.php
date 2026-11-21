<?php

namespace App\Modules\Recipes\Models;

use App\Modules\Catalog\Enums\MeasureUnit;
use App\Modules\Catalog\Models\Ingredient;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class VersionIngredient extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'version_id', 'ingredient_id', 'position', 'quantity', 'unit', 'note',
        'purchase_price', 'purchase_quantity', 'purchase_unit',
    ];

    protected function casts(): array
    {
        return [
            'quantity' => 'float',
            'purchase_price' => 'float',
            'purchase_quantity' => 'float',
            'unit' => MeasureUnit::class,
            'purchase_unit' => MeasureUnit::class,
        ];
    }

    public function ingredient(): BelongsTo
    {
        return $this->belongsTo(Ingredient::class);
    }
}
