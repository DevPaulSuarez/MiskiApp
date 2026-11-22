<?php

use App\Modules\Recipes\Http\Controllers\FavoriteController;
use App\Modules\Recipes\Http\Controllers\RecipeController;
use App\Modules\Recipes\Http\Controllers\UploadController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('recipes', [RecipeController::class, 'index']);
    Route::post('recipes', [RecipeController::class, 'store']);
    Route::get('recipes/{recipe}', [RecipeController::class, 'show']);
    Route::patch('recipes/{recipe}', [RecipeController::class, 'update']);
    Route::post('recipes/{recipe}/versions', [RecipeController::class, 'storeVersion']);
    Route::get('versions/{version}', [RecipeController::class, 'showVersion']);

    Route::get('favorites', [FavoriteController::class, 'index']);
    Route::put('favorites/{recipe}', [FavoriteController::class, 'store']);
    Route::delete('favorites/{recipe}', [FavoriteController::class, 'destroy']);

    Route::post('uploads/images', [UploadController::class, 'image']);
});
