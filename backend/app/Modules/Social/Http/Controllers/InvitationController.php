<?php

namespace App\Modules\Social\Http\Controllers;

use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Enums\InvitationStatus;
use App\Modules\Social\Events\InvitationAnswered;
use App\Modules\Social\Events\InvitationSent;
use App\Modules\Social\Http\Resources\InvitationResource;
use App\Modules\Social\Models\Invitation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class InvitationController
{
    /** Invitations the caller sent or received, newest first. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $me = $request->user()->id;

        return InvitationResource::collection(
            Invitation::where('from_user_id', $me)->orWhere('to_user_id', $me)->latest()->latest('id')->get()
        );
    }

    /** Invite one or more people to try a specific version. */
    public function store(Request $request): JsonResponse
    {
        $me = $request->user();
        $data = $request->validate([
            'version_id' => ['required', 'integer', 'exists:recipe_versions,id'],
            'to_user_ids' => ['required', 'array', 'min:1', 'max:50'],
            'to_user_ids.*' => ['integer', 'distinct', Rule::notIn([$me->id]), 'exists:users,id'],
            'message' => ['nullable', 'string', 'max:300'],
        ], ['to_user_ids.*.not_in' => 'No puedes invitarte a ti mismo.']);

        $invitations = DB::transaction(function () use ($me, $data) {
            // Locking the version makes two quick taps on "Enviar" wait for each other,
            // so the duplicate check below cannot be skipped by a race.
            $version = RecipeVersion::lockForUpdate()->findOrFail($data['version_id']);
            $this->rejectDuplicates($me->id, $version->id, $data['to_user_ids']);

            return collect($data['to_user_ids'])->map(fn ($to) => Invitation::create([
                'recipe_id' => $version->recipe_id,
                'version_id' => $version->id,
                'from_user_id' => $me->id,
                'to_user_id' => $to,
                'message' => trim((string) ($data['message'] ?? '')),
            ]));
        });

        $invitations->each(fn ($i) => InvitationSent::dispatch($i));

        return InvitationResource::collection($invitations)->response()->setStatusCode(201);
    }

    /**
     * You can't invite someone again to the same version while your previous
     * invitation is still open (pending or accepted without a rating). Once they
     * rejected it or already rated, a new invitation is allowed.
     */
    private function rejectDuplicates(int $from, int $versionId, array $toUserIds): void
    {
        $open = Invitation::open()->with('guest')
            ->where('from_user_id', $from)->where('version_id', $versionId)->whereIn('to_user_id', $toUserIds)
            ->get()->keyBy('to_user_id');

        $errors = [];
        foreach ($toUserIds as $i => $to) {
            if ($inv = $open->get((int) $to)) {
                $errors["to_user_ids.$i"] = 'Ya invitaste a '.explode(' ', trim($inv->guest->name))[0].' a esta versión.';
            }
        }
        if ($errors) {
            throw ValidationException::withMessages($errors);
        }
    }

    /** The guest accepts or rejects a pending invitation. */
    public function update(Request $request, Invitation $invitation): InvitationResource
    {
        abort_unless($invitation->to_user_id === $request->user()->id, 403, 'Solo la persona invitada puede responder.');
        $data = $request->validate([
            'status' => ['required', Rule::in([InvitationStatus::Accepted->value, InvitationStatus::Rejected->value])],
        ]);
        if ($invitation->status !== InvitationStatus::Pending) {
            throw ValidationException::withMessages(['status' => 'Esta invitación ya fue respondida.']);
        }

        $invitation->update(['status' => $data['status']]);
        InvitationAnswered::dispatch($invitation);

        return new InvitationResource($invitation);
    }
}
