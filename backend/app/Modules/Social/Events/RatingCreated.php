<?php

namespace App\Modules\Social\Events;

use App\Modules\Social\Models\Rating;
use Illuminate\Foundation\Events\Dispatchable;

class RatingCreated
{
    use Dispatchable;

    public function __construct(public readonly Rating $rating) {}
}
