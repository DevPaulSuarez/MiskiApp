<?php

namespace App\Modules\Social\Http\Controllers;

use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Enums\InvitationStatus;
use App\Modules\Social\Events\RatingCreated;
use App\Modules\Social\Http\Resources\CommentResource;
use App\Modules\Social\Http\Resources\InvitationResource;
use App\Modules\Social\Http\Resources\RatingResource;
use App\Modules\Social\Models\Comment;
use App\Modules\Social\Models\Invitation;
use App\Modules\Social\Models\Rating;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class RatingController
{
    public function store(Request $request): JsonResponse
    {
        $me = $request->user();
        $data = $request->validate([
            'version_id' => ['required', 'integer', 'exists:recipe_versions,id'],
            'invitation_id' => ['nullable', 'integer', 'exists:invitations,id'],
            'stars' => ['required', 'integer', 'between:1,5'],
            'flavor' => ['nullable', 'integer', 'between:0,5'],
            'presentation' => ['nullable', 'integer', 'between:0,5'],
            'ease' => ['nullable', 'integer', 'between:0,5'],
            'value' => ['nullable', 'integer', 'between:0,5'],
            'comment' => ['nullable', 'string', 'max:2000'],
        ]);
        $version = RecipeVersion::findOrFail($data['version_id']);
        $invitation = isset($data['invitation_id']) ? Invitation::findOrFail($data['invitation_id']) : null;

        if ($invitation) {
            $this->checkInvitation($invitation, $me->id, $version->id);
        } elseif ($version->created_by === $me->id) {
            throw ValidationException::withMessages(['version_id' => 'No puedes calificar tu propia versión.']);
        } elseif (Rating::where(['user_id' => $me->id, 'version_id' => $version->id])->exists()) {
            throw ValidationException::withMessages(['version_id' => 'Ya calificaste esta versión.']);
        }

        $comment = trim((string) ($data['comment'] ?? ''));
        [$rating, $posted] = DB::transaction(function () use ($me, $version, $invitation, $data, $comment) {
            $rating = Rating::create([
                'user_id' => $me->id,
                'recipe_id' => $version->recipe_id,
                'version_id' => $version->id,
                'invitation_id' => $invitation?->id,
                'stars' => $data['stars'],
                'flavor' => $data['flavor'] ?? 0,
                'presentation' => $data['presentation'] ?? 0,
                'ease' => $data['ease'] ?? 0,
                'value' => $data['value'] ?? 0,
                'comment' => $comment,
            ]);
            // The written opinion also shows up in the version's comments.
            $posted = $comment !== '' ? Comment::create(['user_id' => $me->id, 'version_id' => $version->id, 'text' => $comment]) : null;
            $invitation?->update(['status' => InvitationStatus::Completed]);

            return [$rating, $posted];
        });

        RatingCreated::dispatch($rating);

        return response()->json([
            'rating' => new RatingResource($rating),
            'comment' => $posted ? new CommentResource($posted) : null,
            'invitation' => $invitation ? new InvitationResource($invitation) : null,
        ], 201);
    }

    private function checkInvitation(Invitation $invitation, int $me, int $versionId): void
    {
        if ($invitation->to_user_id !== $me || $invitation->version_id !== $versionId) {
            abort(403, 'Esta invitación no es para ti.');
        }
        if ($invitation->status === InvitationStatus::Completed || Rating::where('invitation_id', $invitation->id)->exists()) {
            throw ValidationException::withMessages(['invitation_id' => 'Ya calificaste esta invitación.']);
        }
        if ($invitation->status !== InvitationStatus::Accepted) {
            throw ValidationException::withMessages(['invitation_id' => 'Primero acepta la invitación.']);
        }
    }
}
