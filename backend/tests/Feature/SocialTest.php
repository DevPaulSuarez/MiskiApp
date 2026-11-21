<?php

namespace Tests\Feature;

use App\Modules\Identity\Models\User;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SocialTest extends TestCase
{
    private function invite(User $host, User $guest): array
    {
        Sanctum::actingAs($host);
        $dish = $this->createDish();
        $inv = $this->postJson('/api/v1/invitations', [
            'version_id' => $dish['version']['id'], 'to_user_ids' => [$guest->id], 'message' => '¡Ven!',
        ])->assertCreated()->json(0);

        return [$dish, $inv];
    }

    public function test_full_invitation_flow(): void
    {
        $host = User::factory()->create(['name' => 'Paul Suárez']);
        $guest = User::factory()->create(['name' => 'Lucía Ramos']);
        [$dish, $inv] = $this->invite($host, $guest);
        $this->assertDatabaseHas('app_notifications', ['user_id' => $guest->id, 'title' => 'Nueva invitación']);

        // Only the guest answers, and must accept before rating.
        $this->patchJson("/api/v1/invitations/{$inv['id']}", ['status' => 'accepted'])->assertForbidden();
        Sanctum::actingAs($guest);
        $rate = fn () => $this->postJson('/api/v1/ratings', [
            'version_id' => $dish['version']['id'], 'invitation_id' => $inv['id'], 'stars' => 4, 'flavor' => 5, 'comment' => 'Muy rico',
        ]);
        $rate()->assertJsonValidationErrors('invitation_id');

        $this->patchJson("/api/v1/invitations/{$inv['id']}", ['status' => 'accepted'])->assertOk()->assertJsonPath('status', 'accepted');
        $this->patchJson("/api/v1/invitations/{$inv['id']}", ['status' => 'rejected'])->assertJsonValidationErrors('status');
        $this->assertDatabaseHas('app_notifications', ['user_id' => $host->id, 'title' => 'Invitación aceptada']);

        $res = $rate()->assertCreated();
        $res->assertJsonPath('invitation.status', 'completed')->assertJsonPath('comment.text', 'Muy rico');
        $this->assertDatabaseHas('app_notifications', ['user_id' => $host->id, 'title' => 'Nueva calificación']);

        $rate()->assertJsonValidationErrors('invitation_id'); // one rating per invitation
    }

    public function test_cannot_invite_yourself(): void
    {
        $me = $this->actingAsUser();
        $dish = $this->createDish();
        $this->postJson('/api/v1/invitations', ['version_id' => $dish['version']['id'], 'to_user_ids' => [$me->id]])
            ->assertJsonValidationErrors('to_user_ids.0');
    }

    public function test_rating_without_invitation(): void
    {
        $author = $this->actingAsUser();
        $dish = $this->createDish();
        $vid = $dish['version']['id'];
        $this->postJson('/api/v1/ratings', ['version_id' => $vid, 'stars' => 5])->assertJsonValidationErrors('version_id');

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/v1/ratings', ['version_id' => $vid, 'stars' => 3])->assertCreated();
        $this->postJson('/api/v1/ratings', ['version_id' => $vid, 'stars' => 3])->assertJsonValidationErrors('version_id');
        $this->postJson('/api/v1/ratings', ['version_id' => $vid, 'stars' => 9])->assertJsonValidationErrors('stars');
    }

    public function test_comments_and_notifications(): void
    {
        $author = $this->actingAsUser();
        $vid = $this->createDish()['version']['id'];

        $fan = User::factory()->create(['name' => 'Diego Torres']);
        Sanctum::actingAs($fan);
        $this->postJson("/api/v1/versions/$vid/comments", ['text' => '  '])->assertJsonValidationErrors('text');
        $this->postJson("/api/v1/versions/$vid/comments", ['text' => '¡Buenazo!'])->assertCreated();
        $this->getJson("/api/v1/versions/$vid/comments")->assertJsonCount(1)->assertJsonPath('0.text', '¡Buenazo!');

        Sanctum::actingAs($author);
        $n = $this->getJson('/api/v1/notifications')->assertJsonCount(1)->assertJsonPath('0.read', false)->json(0);
        $this->assertSame("/version/$vid/comments", $n['route']);
        $this->postJson("/api/v1/notifications/{$n['id']}/read")->assertJsonPath('read', true);

        Sanctum::actingAs($fan);
        $this->postJson("/api/v1/notifications/{$n['id']}/read")->assertNotFound(); // not theirs
    }
}
