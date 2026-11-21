<?php

use App\Modules\Catalog\Http\Controllers\CatalogController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('categories', [CatalogController::class, 'categories']);
    Route::get('ingredients', [CatalogController::class, 'ingredients']);
    Route::post('ingredients', [CatalogController::class, 'storeIngredient']);
});
