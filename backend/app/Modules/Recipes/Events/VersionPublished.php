<?php

namespace App\Modules\Recipes\Events;

use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use Illuminate\Foundation\Events\Dispatchable;

/** Fired after a dish or a new version of it is published. */
class VersionPublished
{
    use Dispatchable;

    public function __construct(
        public readonly Recipe $recipe,
        public readonly RecipeVersion $version,
        public readonly bool $isNewDish,
    ) {}

    /** Names of ingredients added and removed compared to the parent version. */
    public function ingredientChanges(): array
    {
        $parent = $this->version->parent;
        if (! $parent) {
            return ['added' => [], 'removed' => []];
        }
        $before = $parent->ingredients()->with('ingredient')->get()->keyBy('ingredient_id');
        $after = $this->version->ingredients()->with('ingredient')->get()->keyBy('ingredient_id');

        return [
            'added' => $after->diffKeys($before)->map(fn ($i) => $i->ingredient->name)->values()->all(),
            'removed' => $before->diffKeys($after)->map(fn ($i) => $i->ingredient->name)->values()->all(),
        ];
    }
}
