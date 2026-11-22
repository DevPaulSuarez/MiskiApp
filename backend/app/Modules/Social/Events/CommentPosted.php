<?php

namespace App\Modules\Social\Events;

use App\Modules\Social\Models\Comment;
use Illuminate\Foundation\Events\Dispatchable;

class CommentPosted
{
    use Dispatchable;

    public function __construct(public readonly Comment $comment) {}
}
