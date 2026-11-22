<?php

namespace App\Modules\Recipes\Http\Controllers;

use App\Modules\Recipes\Enums\RecipeStatus;
use App\Modules\Recipes\Http\Requests\StoreRecipeRequest;
use App\Modules\Recipes\Http\Requests\StoreVersionRequest;
use App\Modules\Recipes\Http\Resources\RecipeResource;
use App\Modules\Recipes\Http\Resources\VersionResource;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Recipes\Services\VersionPublisher;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\Gate;
use Illuminate\Validation\Rule;

class RecipeController
{
    public function __construct(private readonly VersionPublisher $publisher) {}

    /** Active dishes plus the caller's own archived ones. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $recipes = Recipe::query()
            ->where(fn ($q) => $q->where('status', RecipeStatus::Active)->orWhere('author_id', $request->user()->id))
            ->latest()->get();

        return RecipeResource::collection($recipes);
    }

    public function show(Recipe $recipe): JsonResponse
    {
        return response()->json([
            'recipe' => new RecipeResource($recipe),
            'versions' => VersionResource::collection($recipe->versions()->with(['ingredients', 'steps'])->orderBy('number')->get()),
        ]);
    }

    public function store(StoreRecipeRequest $request): JsonResponse
    {
        $data = $request->validated();
        [$recipe, $version] = $this->publisher->createDish($request->user(), $data, $data['version']);

        return response()->json([
            'recipe' => new RecipeResource($recipe->fresh()),
            'version' => new VersionResource($version),
        ], 201);
    }

    public function storeVersion(StoreVersionRequest $request, Recipe $recipe): JsonResponse
    {
        $version = $this->publisher->addVersion($recipe, $request->user(), $request->validated());

        return (new VersionResource($version))->response()->setStatusCode(201);
    }

    public function showVersion(RecipeVersion $version): VersionResource
    {
        return new VersionResource($version->load(['ingredients', 'steps']));
    }

    /** Author-only: main version, archive / restore, and the dish card. */
    public function update(Request $request, Recipe $recipe): RecipeResource
    {
        Gate::authorize('manage', $recipe);

        $data = $request->validate([
            'main_version_id' => ['sometimes', 'integer', Rule::exists('recipe_versions', 'id')->where('recipe_id', $recipe->id)],
            'status' => ['sometimes', Rule::enum(RecipeStatus::class)],
            'name' => ['sometimes', 'string', 'min:3', 'max:100'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],
            'image_url' => ['sometimes', 'nullable', 'string', 'max:500'],
            'category_id' => ['sometimes', 'integer', 'exists:categories,id'],
        ]);

        $recipe->update(collect($data)->map(fn ($v, $k) => in_array($k, ['description', 'image_url']) ? (string) $v : $v)->all());

        return new RecipeResource($recipe->fresh());
    }
}
