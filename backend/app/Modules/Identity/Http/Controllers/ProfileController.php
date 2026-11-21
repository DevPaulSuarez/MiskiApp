<?php

namespace App\Modules\Identity\Http\Controllers;

use App\Modules\Identity\Http\Requests\UpdateProfileRequest;
use App\Modules\Identity\Http\Resources\MeResource;
use App\Modules\Identity\Http\Resources\UserResource;
use App\Modules\Identity\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProfileController
{
    public function index(): AnonymousResourceCollection
    {
        return UserResource::collection(User::with('favoriteCategories')->orderBy('name')->get());
    }

    public function show(User $user): UserResource
    {
        return new UserResource($user->load('favoriteCategories'));
    }

    public function update(UpdateProfileRequest $request): MeResource
    {
        $user = $request->user();
        $data = $request->validated();

        $user->update(collect($data)->except('favorite_category_ids')->map(fn ($v, $k) => $k === 'bio' ? (string) $v : $v)->all());

        if (array_key_exists('favorite_category_ids', $data)) {
            $user->favoriteCategories()->sync($data['favorite_category_ids']);
        }

        return new MeResource($user->fresh()->load('favoriteCategories'));
    }
}
