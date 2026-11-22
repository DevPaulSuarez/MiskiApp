<?php

namespace App\Modules\Recipes\Http\Requests;

use App\Modules\Catalog\Enums\MeasureUnit;
use App\Modules\Recipes\Enums\Difficulty;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

/** Validation shared by "new dish" and "new version" (prefix = where the version payload lives). */
final class VersionRules
{
    public static function rules(string $p = ''): array
    {
        return [
            "{$p}title" => ['nullable', 'string', 'max:100'],
            "{$p}servings" => ['required', 'integer', 'between:1,100'],
            "{$p}prep_minutes" => ['required', 'integer', 'between:0,1440'],
            "{$p}cook_minutes" => ['required', 'integer', 'between:0,1440'],
            "{$p}difficulty" => ['required', Rule::enum(Difficulty::class)],
            "{$p}notes" => ['nullable', 'string', 'max:2000'],
            "{$p}ingredients" => ['required', 'array', 'min:1', 'max:60'],
            "{$p}ingredients.*.ingredient_id" => ['required', 'integer', 'distinct', 'exists:ingredients,id'],
            "{$p}ingredients.*.quantity" => ['required', 'numeric', 'gt:0', 'max:1000000'],
            "{$p}ingredients.*.unit" => ['required', Rule::enum(MeasureUnit::class)],
            "{$p}ingredients.*.note" => ['nullable', 'string', 'max:120'],
            "{$p}ingredients.*.purchase" => ['nullable', 'array'],
            "{$p}ingredients.*.purchase.price" => ["required_with:{$p}ingredients.*.purchase", 'numeric', 'min:0', 'max:100000'],
            "{$p}ingredients.*.purchase.quantity" => ["required_with:{$p}ingredients.*.purchase", 'numeric', 'gt:0'],
            "{$p}ingredients.*.purchase.unit" => ["required_with:{$p}ingredients.*.purchase", Rule::enum(MeasureUnit::class)],
            "{$p}steps" => ['required', 'array', 'min:1', 'max:60'],
            "{$p}steps.*" => ['required', 'string', 'max:2000'],
        ];
    }

    /** The purchase unit must be convertible to the unit used in the recipe. */
    public static function checkUnits(Validator $validator, array $ingredients, string $p = ''): void
    {
        foreach ($ingredients as $i => $line) {
            $unit = MeasureUnit::tryFrom((string) ($line['unit'] ?? ''));
            $bought = MeasureUnit::tryFrom((string) ($line['purchase']['unit'] ?? ''));
            if ($unit && $bought && ! $unit->isCompatibleWith($bought)) {
                $validator->errors()->add("{$p}ingredients.$i.purchase.unit", 'La unidad de compra no es compatible con la unidad usada en la receta.');
            }
        }
    }
}
