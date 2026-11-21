<?php

namespace App\Modules\Recipes;

use App\Modules\Core\ModuleServiceProvider;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Recipes\Policies\RecipePolicy;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Route;

/** Dishes, their versions (preparations) and favorites. */
class RecipesServiceProvider extends ModuleServiceProvider
{
    public function boot(): void
    {
        parent::boot();
        Gate::policy(Recipe::class, RecipePolicy::class);
        Route::model('version', RecipeVersion::class);
    }
}
