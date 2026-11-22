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

        $version = RecipeVersion::findOrFail($data['version_id']);
        $invitations = DB::transaction(fn () => collect($data['to_user_ids'])->map(fn ($to) => Invitation::create([
            'recipe_id' => $version->recipe_id,
            'version_id' => $version->id,
            'from_user_id' => $me->id,
            'to_user_id' => $to,
            'message' => trim((string) ($data['message'] ?? '')),
        ])));

        $invitations->each(fn ($i) => InvitationSent::dispatch($i));

        return InvitationResource::collection($invitations)->response()->setStatusCode(201);
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
