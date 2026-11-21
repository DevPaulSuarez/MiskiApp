<?php

namespace App\Modules\Recipes\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class VersionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'recipe_id' => (string) $this->recipe_id,
            'number' => $this->number,
            'title' => $this->title,
            'parent_version_id' => $this->parent_version_id ? (string) $this->parent_version_id : null,
            'created_by' => (string) $this->created_by,
            'created_at' => $this->created_at->toIso8601ZuluString(),
            'servings' => $this->servings,
            'prep_minutes' => $this->prep_minutes,
            'cook_minutes' => $this->cook_minutes,
            'difficulty' => $this->difficulty->value,
            'notes' => (string) $this->notes,
            'ingredients' => $this->ingredients->map(fn ($i) => [
                'ingredient_id' => (string) $i->ingredient_id,
                'quantity' => $i->quantity,
                'unit' => $i->unit->value,
                'note' => $i->note,
                'purchase' => $i->purchase_unit ? [
                    'price' => $i->purchase_price,
                    'quantity' => $i->purchase_quantity,
                    'unit' => $i->purchase_unit->value,
                ] : null,
            ])->values(),
            'steps' => $this->steps->pluck('text')->values(),
        ];
    }
}
