<?php

namespace App\Modules\Recipes\Http\Controllers;

use App\Modules\Recipes\Http\Resources\RecipeResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class UploadController
{
    /** Stores a dish photo; the returned path goes into the dish's image_url. */
    public function image(Request $request): JsonResponse
    {
        $request->validate(['image' => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:6144']]);
        $path = $request->file('image')->store('recipes', 'public');

        return response()->json(['path' => $path, 'url' => RecipeResource::imageUrl($path)], 201);
    }
}
