<?php

use App\Modules\Sync\Http\Controllers\SyncController;
use Illuminate\Support\Facades\Route;

Route::get('sync', SyncController::class)->middleware('auth:sanctum');
