<?php

namespace App\Modules\Social\Http\Controllers;

use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Events\CommentPosted;
use App\Modules\Social\Http\Resources\CommentResource;
use App\Modules\Social\Models\Comment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class CommentController
{
    public function index(RecipeVersion $version): AnonymousResourceCollection
    {
        return CommentResource::collection(Comment::where('version_id', $version->id)->oldest()->oldest('id')->get());
    }

    public function store(Request $request, RecipeVersion $version): JsonResponse
    {
        $request->merge(['text' => trim((string) $request->input('text'))]);
        $data = $request->validate(['text' => ['required', 'string', 'max:2000']]);

        $comment = Comment::create(['user_id' => $request->user()->id, 'version_id' => $version->id, 'text' => $data['text']]);
        CommentPosted::dispatch($comment);

        return (new CommentResource($comment))->response()->setStatusCode(201);
    }
}
