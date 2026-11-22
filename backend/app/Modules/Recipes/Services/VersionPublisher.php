<?php

namespace App\Modules\Recipes\Services;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Events\VersionPublished;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use Illuminate\Support\Facades\DB;

class VersionPublisher
{
    /** Creates a dish together with its first version, which becomes the main one. */
    public function createDish(User $author, array $dish, array $version): array
    {
        [$recipe, $v] = DB::transaction(function () use ($author, $dish, $version) {
            $recipe = Recipe::create([
                'name' => trim($dish['name']),
                'description' => trim((string) ($dish['description'] ?? '')),
                'image_url' => (string) ($dish['image_url'] ?? ''),
                'category_id' => $dish['category_id'],
                'author_id' => $author->id,
            ]);
            $v = $this->insertVersion($recipe, $author, $version, number: 1, parentId: null);
            $recipe->update(['main_version_id' => $v->id]);

            return [$recipe, $v];
        });

        VersionPublished::dispatch($recipe, $v, true);

        return [$recipe, $v];
    }

    /** Anyone can add their way of preparing a dish; it stays inside that dish under their name. */
    public function addVersion(Recipe $recipe, User $creator, array $version): RecipeVersion
    {
        $v = DB::transaction(function () use ($recipe, $creator, $version) {
            // Lock the dish row so two people publishing at once never get the same number.
            Recipe::whereKey($recipe->id)->lockForUpdate()->first();
            $number = (int) RecipeVersion::where('recipe_id', $recipe->id)->max('number') + 1;

            return $this->insertVersion($recipe, $creator, $version, $number, (int) $version['parent_version_id']);
        });

        VersionPublished::dispatch($recipe, $v, false);

        return $v;
    }

    private function insertVersion(Recipe $recipe, User $creator, array $data, int $number, ?int $parentId): RecipeVersion
    {
        $title = trim((string) ($data['title'] ?? ''));
        $version = RecipeVersion::create([
            'recipe_id' => $recipe->id,
            'number' => $number,
            'title' => $title !== '' ? $title : ($number === 1 ? 'Versión original' : "Versión $number"),
            'parent_version_id' => $parentId,
            'created_by' => $creator->id,
            'servings' => $data['servings'],
            'prep_minutes' => $data['prep_minutes'],
            'cook_minutes' => $data['cook_minutes'],
            'difficulty' => $data['difficulty'],
            'notes' => trim((string) ($data['notes'] ?? '')),
        ]);

        foreach (array_values($data['ingredients']) as $i => $line) {
            $purchase = $line['purchase'] ?? null;
            $version->ingredients()->create([
                'ingredient_id' => $line['ingredient_id'],
                'position' => $i,
                'quantity' => $line['quantity'],
                'unit' => $line['unit'],
                'note' => trim((string) ($line['note'] ?? '')),
                'purchase_price' => $purchase['price'] ?? null,
                'purchase_quantity' => $purchase['quantity'] ?? null,
                'purchase_unit' => $purchase['unit'] ?? null,
            ]);
        }

        foreach (array_values($data['steps']) as $i => $text) {
            $version->steps()->create(['position' => $i, 'text' => trim($text)]);
        }

        return $version->load(['ingredients', 'steps']);
    }
}
