<?php

namespace Tests\Feature;

use Database\Seeders\DemoData;
use Database\Seeders\DemoSeeder;
use Tests\TestCase;

class SyncTest extends TestCase
{
    public function test_demo_data_and_sync_snapshot(): void
    {
        $this->seed(DemoSeeder::class);
        $token = $this->postJson('/api/v1/auth/login', ['email' => DemoData::email('paul'), 'password' => DemoData::PASSWORD])->json('token');

        $res = $this->getJson('/api/v1/sync', ['Authorization' => "Bearer $token"])->assertOk();

        $res->assertJsonPath('me.handle', '@paul')
            ->assertJsonCount(5, 'users')
            ->assertJsonCount(9, 'categories')
            ->assertJsonCount(8, 'recipes')
            ->assertJsonCount(10, 'versions')
            ->assertJsonCount(2, 'favorite_recipe_ids')
            ->assertJsonMissingPath('users.0.email');

        $ceviche = collect($res->json('recipes'))->firstWhere('name', 'Ceviche peruano de tilapia');
        $versions = collect($res->json('versions'))->where('recipe_id', $ceviche['id']);
        $this->assertCount(3, $versions);
        $this->assertSame('Más limón, menos cebolla', $versions->firstWhere('id', $ceviche['main_version_id'])['title']);
    }

    public function test_archived_dishes_of_others_are_hidden(): void
    {
        $this->actingAsUser();
        $id = $this->createDish()['recipe']['id'];
        $this->patchJson("/api/v1/recipes/$id", ['status' => 'archived']);
        $this->getJson('/api/v1/sync')->assertJsonCount(1, 'recipes');

        $this->actingAsUser();
        $this->getJson('/api/v1/sync')->assertJsonCount(0, 'recipes');
    }
}
