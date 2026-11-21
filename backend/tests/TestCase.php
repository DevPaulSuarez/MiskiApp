<?php

namespace Tests;

use App\Modules\Catalog\Models\Category;
use App\Modules\Catalog\Models\Ingredient;
use App\Modules\Identity\Models\User;
use Database\Seeders\CatalogSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    protected string $seeder = CatalogSeeder::class;

    protected function actingAsUser(array $attrs = []): User
    {
        $user = User::factory()->create($attrs);
        Sanctum::actingAs($user);

        return $user;
    }

    /** A valid version payload using the first [count] catalog ingredients. */
    protected function versionPayload(array $override = [], int $count = 3): array
    {
        $ids = Ingredient::orderBy('id')->limit($count)->pluck('id');

        return array_merge([
            'title' => '',
            'servings' => 2,
            'prep_minutes' => 15,
            'cook_minutes' => 0,
            'difficulty' => 'easy',
            'notes' => '',
            'ingredients' => $ids->map(fn ($id) => ['ingredient_id' => $id, 'quantity' => 100, 'unit' => 'gram', 'note' => '', 'purchase' => null])->all(),
            'steps' => ['Cortar', 'Mezclar'],
        ], $override);
    }

    protected function createDish(array $override = []): array
    {
        return $this->postJson('/api/v1/recipes', array_merge([
            'name' => 'Causa limeña',
            'description' => 'Clásica',
            'image_url' => 'https://example.com/causa.jpg',
            'category_id' => Category::first()->id,
            'version' => $this->versionPayload(),
        ], $override))->assertCreated()->json();
    }
}
