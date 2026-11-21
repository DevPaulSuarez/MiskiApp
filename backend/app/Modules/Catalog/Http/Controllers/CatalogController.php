<?php

namespace App\Modules\Catalog\Http\Controllers;

use App\Modules\Catalog\Enums\MeasureUnit;
use App\Modules\Catalog\Http\Resources\CategoryResource;
use App\Modules\Catalog\Http\Resources\IngredientResource;
use App\Modules\Catalog\Models\Category;
use App\Modules\Catalog\Models\Ingredient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\Rule;

class CatalogController
{
    public function categories(): AnonymousResourceCollection
    {
        return CategoryResource::collection(Category::orderBy('position')->orderBy('id')->get());
    }

    public function ingredients(): AnonymousResourceCollection
    {
        return IngredientResource::collection(Ingredient::orderBy('name')->get());
    }

    /** Find-or-create by name (case-insensitive) so the catalog has no duplicates. */
    public function storeIngredient(Request $request): JsonResponse
    {
        $request->merge(['name' => preg_replace('/\s+/u', ' ', trim((string) $request->input('name')))]);
        $data = $request->validate([
            'name' => ['required', 'string', 'min:2', 'max:80'],
            'category' => ['nullable', 'string', 'max:40'],
            'default_unit' => ['required', Rule::enum(MeasureUnit::class)],
            'description' => ['nullable', 'string', 'max:255'],
        ]);

        $existing = Ingredient::whereRaw('LOWER(name) = ?', [mb_strtolower($data['name'])])->first();
        if ($existing) {
            return (new IngredientResource($existing))->response()->setStatusCode(200);
        }

        $ingredient = Ingredient::create([
            'name' => mb_strtoupper(mb_substr($data['name'], 0, 1)).mb_substr($data['name'], 1),
            'category' => $data['category'] ?? 'Otros',
            'default_unit' => $data['default_unit'],
            'description' => (string) ($data['description'] ?? ''),
            'created_by' => $request->user()->id,
        ]);

        return (new IngredientResource($ingredient))->response()->setStatusCode(201);
    }
}
