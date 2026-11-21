<?php

namespace App\Modules\Identity\Http\Controllers;

use App\Modules\Identity\Http\Requests\LoginRequest;
use App\Modules\Identity\Http\Requests\RegisterRequest;
use App\Modules\Identity\Http\Resources\MeResource;
use App\Modules\Identity\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = User::create([
            'name' => $data['name'],
            'handle' => User::uniqueHandleFrom($data['name']),
            'email' => $data['email'],
            'password' => $data['password'],
            'birthday' => $data['birthday'] ?? null,
            'favorite_foods' => [],
        ]);

        return $this->tokenResponse($user, $data['device_name'] ?? null, 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();
        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages(['email' => 'El correo o la contraseña no son correctos.']);
        }

        return $this->tokenResponse($user, $data['device_name'] ?? null);
    }

    public function me(Request $request): MeResource
    {
        return new MeResource($request->user()->load('favoriteCategories'));
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()->delete();

        return response()->noContent();
    }

    private function tokenResponse(User $user, ?string $device, int $status = 200): JsonResponse
    {
        $token = $user->createToken($device ?: 'app')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => new MeResource($user->load('favoriteCategories')),
        ], $status);
    }
}
