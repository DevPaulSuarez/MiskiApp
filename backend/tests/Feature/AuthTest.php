<?php

namespace Tests\Feature;

use App\Modules\Identity\Models\User;
use Tests\TestCase;

class AuthTest extends TestCase
{
    public function test_register_returns_token_and_generated_handle(): void
    {
        $res = $this->postJson('/api/v1/auth/register', [
            'name' => 'María Quispe', 'email' => 'Maria@Example.com', 'password' => 'secreta123', 'birthday' => '1992-12-09',
        ])->assertCreated();

        $res->assertJsonPath('user.handle', '@mariaquispe')
            ->assertJsonPath('user.email', 'maria@example.com')
            ->assertJsonPath('user.birthday', '1992-12-09');
        $this->getJson('/api/v1/auth/me', ['Authorization' => 'Bearer '.$res->json('token')])
            ->assertOk()->assertJsonPath('name', 'María Quispe');
    }

    public function test_register_rejects_duplicate_email_and_short_password(): void
    {
        User::factory()->create(['email' => 'a@b.com']);
        $this->postJson('/api/v1/auth/register', ['name' => 'X Y', 'email' => 'a@b.com', 'password' => '123'])
            ->assertUnprocessable()->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_login_and_logout(): void
    {
        User::factory()->create(['email' => 'paul@miski.test', 'password' => 'miski1234']);

        $this->postJson('/api/v1/auth/login', ['email' => 'paul@miski.test', 'password' => 'mala'])
            ->assertUnprocessable()->assertJsonValidationErrors('email');

        $token = $this->postJson('/api/v1/auth/login', ['email' => 'PAUL@miski.test', 'password' => 'miski1234'])
            ->assertOk()->json('token');

        $this->postJson('/api/v1/auth/logout', [], ['Authorization' => "Bearer $token"])->assertNoContent();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_protected_routes_need_a_token(): void
    {
        $this->getJson('/api/v1/sync')->assertUnauthorized()->assertJsonPath('message', 'Tu sesión expiró. Vuelve a iniciar sesión.');
    }

    public function test_errors_are_in_spanish(): void
    {
        $this->actingAsUser();
        $this->getJson('/api/v1/recipes/999')->assertNotFound()->assertJsonPath('message', 'No encontramos lo que buscabas.');
        $this->postJson('/api/v1/auth/register', ['name' => 'X Y', 'email' => 'malo', 'password' => '12345678'])
            ->assertJsonPath('errors.email.0', 'El campo correo debe ser un correo válido.');
    }

    public function test_update_profile(): void
    {
        $this->actingAsUser();
        User::factory()->create(['handle' => 'tomado']);

        $this->patchJson('/api/v1/me', ['handle' => '@tomado'])->assertJsonValidationErrors('handle');

        $this->patchJson('/api/v1/me', [
            'name' => 'Paul S.',
            'handle' => '@Paul_S',
            'bio' => 'Hola',
            'birthday' => '1995-03-18',
            'favorite_foods' => ['Ceviche', ' ceviche ', 'Lomo saltado', ''],
            'favorite_category_ids' => [1, 3],
        ])->assertOk()
            ->assertJsonPath('handle', '@paul_s')
            ->assertJsonPath('favorite_foods', ['Ceviche', 'Lomo saltado'])
            ->assertJsonPath('favorite_category_ids', ['1', '3']);
    }

    public function test_public_profile_hides_email(): void
    {
        $this->actingAsUser();
        $other = User::factory()->create();
        $this->getJson("/api/v1/users/{$other->id}")->assertOk()->assertJsonMissingPath('email');
    }
}
