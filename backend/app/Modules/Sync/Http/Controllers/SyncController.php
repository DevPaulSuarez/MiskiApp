<?php

namespace App\Modules\Sync\Http\Controllers;

use App\Modules\Catalog\Http\Resources\CategoryResource;
use App\Modules\Catalog\Http\Resources\IngredientResource;
use App\Modules\Catalog\Models\Category;
use App\Modules\Catalog\Models\Ingredient;
use App\Modules\Identity\Http\Resources\MeResource;
use App\Modules\Identity\Http\Resources\UserResource;
use App\Modules\Identity\Models\User;
use App\Modules\Notifications\Http\Controllers\NotificationController;
use App\Modules\Notifications\Http\Resources\NotificationResource;
use App\Modules\Recipes\Enums\RecipeStatus;
use App\Modules\Recipes\Http\Controllers\FavoriteController;
use App\Modules\Recipes\Http\Resources\RecipeResource;
use App\Modules\Recipes\Http\Resources\VersionResource;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Http\Resources\CommentResource;
use App\Modules\Social\Http\Resources\InvitationResource;
use App\Modules\Social\Http\Resources\RatingResource;
use App\Modules\Social\Models\Comment;
use App\Modules\Social\Models\Invitation;
use App\Modules\Social\Models\Rating;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Everything the app needs to start, in one request. Fine for v1 (a cookbook
 * shared among friends); when the catalog grows, the app can switch to the
 * per-module paginated endpoints without changing its screens.
 */
class SyncController
{
    public function __invoke(Request $request): JsonResponse
    {
        $me = $request->user();

        $recipes = Recipe::query()
            ->where(fn ($q) => $q->where('status', RecipeStatus::Active)->orWhere('author_id', $me->id)
                // Archived dishes stay reachable from invitations that point to them.
                ->orWhereIn('id', Invitation::select('recipe_id')->where('to_user_id', $me->id)->orWhere('from_user_id', $me->id)))
            ->latest()->latest('id')->get();
        $recipeIds = $recipes->pluck('id');
        $versionIds = RecipeVersion::whereIn('recipe_id', $recipeIds)->pluck('id');

        return response()->json([
            'server_time' => now()->toIso8601ZuluString(),
            'me' => new MeResource($me->load('favoriteCategories')),
            'users' => UserResource::collection(User::with('favoriteCategories')->orderBy('name')->get()),
            'categories' => CategoryResource::collection(Category::orderBy('position')->orderBy('id')->get()),
            'ingredients' => IngredientResource::collection(Ingredient::orderBy('name')->get()),
            'recipes' => RecipeResource::collection($recipes),
            'versions' => VersionResource::collection(
                RecipeVersion::whereIn('id', $versionIds)->with(['ingredients', 'steps'])->orderBy('recipe_id')->orderBy('number')->get()
            ),
            'ratings' => RatingResource::collection(Rating::whereIn('version_id', $versionIds)->latest()->get()),
            'comments' => CommentResource::collection(Comment::whereIn('version_id', $versionIds)->oldest()->oldest('id')->get()),
            'invitations' => InvitationResource::collection(
                Invitation::where('from_user_id', $me->id)->orWhere('to_user_id', $me->id)->latest()->latest('id')->get()
            ),
            'notifications' => NotificationResource::collection(NotificationController::latestFor($me->id)),
            'favorite_recipe_ids' => FavoriteController::idsFor($me->id),
        ]);
    }
}
