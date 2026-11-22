<?php

use App\Modules\Social\Http\Controllers\CommentController;
use App\Modules\Social\Http\Controllers\InvitationController;
use App\Modules\Social\Http\Controllers\RatingController;
use Illuminate\Support\Facades\Route;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('invitations', [InvitationController::class, 'index']);
    Route::post('invitations', [InvitationController::class, 'store']);
    Route::patch('invitations/{invitation}', [InvitationController::class, 'update']);

    Route::post('ratings', [RatingController::class, 'store']);

    Route::get('versions/{version}/comments', [CommentController::class, 'index']);
    Route::post('versions/{version}/comments', [CommentController::class, 'store']);
});
