<?php

namespace App\Modules\Recipes\Http\Controllers;

use App\Modules\Recipes\Models\Recipe;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class FavoriteController
{
    public function index(Request $request): JsonResponse
    {
        return response()->json(self::idsFor($request->user()->id));
    }

    public function store(Request $request, Recipe $recipe): JsonResponse
    {
        DB::table('favorites')->insertOrIgnore(['user_id' => $request->user()->id, 'recipe_id' => $recipe->id, 'created_at' => now()]);

        return response()->json(self::idsFor($request->user()->id));
    }

    public function destroy(Request $request, Recipe $recipe): JsonResponse
    {
        DB::table('favorites')->where(['user_id' => $request->user()->id, 'recipe_id' => $recipe->id])->delete();

        return response()->json(self::idsFor($request->user()->id));
    }

    public static function idsFor(int $userId): array
    {
        return DB::table('favorites')->where('user_id', $userId)->orderByDesc('created_at')
            ->pluck('recipe_id')->map(fn ($id) => (string) $id)->all();
    }
}
