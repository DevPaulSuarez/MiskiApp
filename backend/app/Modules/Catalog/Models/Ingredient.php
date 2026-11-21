<?php

namespace App\Modules\Catalog\Models;

use App\Modules\Catalog\Enums\MeasureUnit;
use Illuminate\Database\Eloquent\Model;

class Ingredient extends Model
{
    protected $fillable = ['name', 'category', 'default_unit', 'description', 'created_by'];

    protected $attributes = ['category' => 'Otros', 'description' => ''];

    protected function casts(): array
    {
        return ['default_unit' => MeasureUnit::class];
    }
}
