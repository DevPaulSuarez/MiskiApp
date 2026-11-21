<?php

namespace App\Modules\Notifications\Listeners;

use App\Modules\Notifications\Models\AppNotification;
use App\Modules\Recipes\Events\VersionPublished;
use App\Modules\Social\Enums\InvitationStatus;
use App\Modules\Social\Events\CommentPosted;
use App\Modules\Social\Events\InvitationAnswered;
use App\Modules\Social\Events\InvitationSent;
use App\Modules\Social\Events\RatingCreated;

/**
 * Turns what happens in other modules into in-app notifications. Nobody is
 * notified about their own actions (the app confirms those on screen).
 */
class SendActivityNotifications
{
    public function versionPublished(VersionPublished $e): void
    {
        $recipe = $e->recipe;
        $v = $e->version;
        if ($e->isNewDish || $recipe->author_id === $v->created_by) {
            return;
        }
        // My way of preparing someone else's dish: tell the author only which
        // ingredients were added or removed (quantities and steps are ignored).
        $changes = $e->ingredientChanges();
        $parts = array_filter([
            $changes['added'] ? 'Agregó: '.implode(', ', $changes['added']) : null,
            $changes['removed'] ? 'Quitó: '.implode(', ', $changes['removed']) : null,
        ]);
        AppNotification::send(
            $recipe->author_id,
            $this->firstName($v->creator->name).' preparó tu plato a su manera',
            "{$recipe->name} · V{$v->number} — ".($parts ? implode(' · ', $parts) : 'Sin cambios de ingredientes'),
            "/version/{$v->id}",
        );
    }

    public function invitationSent(InvitationSent $e): void
    {
        $i = $e->invitation->load(['sender', 'recipe', 'version']);
        AppNotification::send(
            $i->to_user_id,
            'Nueva invitación',
            $this->firstName($i->sender->name)." te invitó a probar \"{$i->recipe->name} · V{$i->version->number}\".",
            '/invitations',
        );
    }

    public function invitationAnswered(InvitationAnswered $e): void
    {
        $i = $e->invitation->load(['guest', 'recipe']);
        $accepted = $i->status === InvitationStatus::Accepted;
        AppNotification::send(
            $i->from_user_id,
            $accepted ? 'Invitación aceptada' : 'Invitación rechazada',
            $this->firstName($i->guest->name).($accepted ? ' aceptó' : ' no podrá aceptar')." tu invitación a probar \"{$i->recipe->name}\".",
            '/invitations',
        );
    }

    public function ratingCreated(RatingCreated $e): void
    {
        $r = $e->rating->load(['user', 'version.recipe']);
        if ($r->version->created_by === $r->user_id) {
            return;
        }
        $stars = $r->stars === 1 ? '1 estrella' : "{$r->stars} estrellas";
        AppNotification::send(
            $r->version->created_by,
            'Nueva calificación',
            $this->firstName($r->user->name)." calificó tu {$r->version->recipe->name} (V{$r->version->number}) con $stars.",
            "/version/{$r->version_id}",
        );
    }

    public function commentPosted(CommentPosted $e): void
    {
        $c = $e->comment->load(['user', 'version.recipe']);
        if ($c->version->created_by === $c->user_id) {
            return;
        }
        AppNotification::send(
            $c->version->created_by,
            'Nuevo comentario',
            $this->firstName($c->user->name)." comentó tu versión de \"{$c->version->recipe->name}\".",
            "/version/{$c->version_id}/comments",
        );
    }

    private function firstName(string $name): string
    {
        return explode(' ', trim($name))[0];
    }
}
