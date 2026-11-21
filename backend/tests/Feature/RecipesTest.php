<?php

namespace Tests\Feature;

use App\Modules\Identity\Models\User;
use App\Modules\Notifications\Models\AppNotification;
use App\Modules\Recipes\Models\RecipeVersion;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use LogicException;
use Tests\TestCase;

class RecipesTest extends TestCase
{
    public function test_create_dish_with_first_version_as_main(): void
    {
        $me = $this->actingAsUser();
        $res = $this->createDish();

        $this->assertSame((string) $me->id, $res['recipe']['author_id']);
        $this->assertSame($res['version']['id'], $res['recipe']['main_version_id']);
        $this->assertSame(1, $res['version']['number']);
        $this->assertSame('Versión original', $res['version']['title']);
        $this->assertSame(['Cortar', 'Mezclar'], $res['version']['steps']);
        $this->assertCount(3, $res['version']['ingredients']);
    }

    public function test_validation_of_versions(): void
    {
        $this->actingAsUser();
        $payload = $this->versionPayload(['steps' => [], 'ingredients' => []]);
        $this->postJson('/api/v1/recipes', ['name' => 'X', 'category_id' => 999, 'version' => $payload])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['name', 'category_id', 'version.ingredients', 'version.steps']);

        // Bought in grams but used in units: the cost can't be computed.
        $bad = $this->versionPayload();
        $bad['ingredients'][0]['purchase'] = ['price' => 5, 'quantity' => 1, 'unit' => 'unit'];
        $this->postJson('/api/v1/recipes', ['name' => 'Causa', 'category_id' => 1, 'version' => $bad])
            ->assertJsonValidationErrors('version.ingredients.0.purchase.unit');
    }

    public function test_someone_elses_version_stays_in_the_dish_and_notifies_the_author(): void
    {
        $author = $this->actingAsUser(['name' => 'Paul Suárez']);
        $dish = $this->createDish();

        $maria = User::factory()->create(['name' => 'María Quispe']);
        Sanctum::actingAs($maria);
        $payload = $this->versionPayload(['title' => 'Con rocoto'], 4); // adds the 4th ingredient
        array_shift($payload['ingredients']); // removes the 1st
        $v2 = $this->postJson("/api/v1/recipes/{$dish['recipe']['id']}/versions", [
            'parent_version_id' => $dish['version']['id'], ...$payload,
        ])->assertCreated()->json();

        $this->assertSame(2, $v2['number']);
        $this->assertSame((string) $maria->id, $v2['created_by']);
        $this->assertSame($dish['version']['id'], $v2['parent_version_id']);

        $this->assertDatabaseHas('app_notifications', ['user_id' => $author->id, 'title' => 'María preparó tu plato a su manera']);
        $body = AppNotification::where('user_id', $author->id)->value('body');
        $this->assertStringContainsString('Agregó:', $body);
        $this->assertStringContainsString('Quitó:', $body);
        $this->assertDatabaseMissing('app_notifications', ['user_id' => $maria->id]);
    }

    public function test_parent_must_belong_to_the_same_dish(): void
    {
        $this->actingAsUser();
        $a = $this->createDish();
        $b = $this->createDish(['name' => 'Otro']);
        $this->postJson("/api/v1/recipes/{$a['recipe']['id']}/versions", [
            'parent_version_id' => $b['version']['id'], ...$this->versionPayload(),
        ])->assertJsonValidationErrors('parent_version_id');
    }

    public function test_only_the_author_changes_main_version_or_archives(): void
    {
        $this->actingAsUser();
        $dish = $this->createDish();
        $id = $dish['recipe']['id'];
        $v2 = $this->postJson("/api/v1/recipes/$id/versions", ['parent_version_id' => $dish['version']['id'], ...$this->versionPayload()])->json();

        Sanctum::actingAs(User::factory()->create());
        $this->patchJson("/api/v1/recipes/$id", ['status' => 'archived'])->assertForbidden()
            ->assertJsonPath('message', 'No tienes permiso para hacer esto.');

        Sanctum::actingAs(User::find($dish['recipe']['author_id']));
        $this->patchJson("/api/v1/recipes/$id", ['main_version_id' => $v2['id'], 'status' => 'archived'])
            ->assertOk()->assertJsonPath('main_version_id', $v2['id'])->assertJsonPath('status', 'archived');
    }

    public function test_versions_are_immutable(): void
    {
        $this->actingAsUser();
        $dish = $this->createDish();
        $this->expectException(LogicException::class);
        RecipeVersion::find($dish['version']['id'])->update(['title' => 'Cambio']);
    }

    public function test_favorites(): void
    {
        $this->actingAsUser();
        $id = $this->createDish()['recipe']['id'];
        $this->putJson("/api/v1/favorites/$id")->assertOk()->assertExactJson([$id]);
        $this->putJson("/api/v1/favorites/$id")->assertExactJson([$id]);
        $this->deleteJson("/api/v1/favorites/$id")->assertExactJson([]);
    }

    public function test_ingredient_find_or_create(): void
    {
        $this->actingAsUser();
        $this->postJson('/api/v1/ingredients', ['name' => 'limón', 'default_unit' => 'unit'])->assertOk()->assertJsonPath('name', 'Limón');
        $this->postJson('/api/v1/ingredients', ['name' => '  ají   amarillo ', 'default_unit' => 'gram'])
            ->assertCreated()->assertJsonPath('name', 'Ají amarillo')->assertJsonPath('category', 'Otros');
    }

    public function test_upload_dish_photo(): void
    {
        Storage::fake('public');
        $this->actingAsUser();
        $res = $this->post('/api/v1/uploads/images', ['image' => UploadedFile::fake()->image('plato.jpg')], ['Accept' => 'application/json'])
            ->assertCreated();
        Storage::disk('public')->assertExists($res->json('path'));
        $this->assertStringEndsWith('/storage/'.$res->json('path'), $res->json('url'));

        $dish = $this->createDish(['image_url' => $res->json('path')]);
        $this->assertSame($res->json('url'), $dish['recipe']['image_url']);
    }
}
