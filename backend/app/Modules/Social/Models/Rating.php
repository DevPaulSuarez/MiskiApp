<?php

namespace App\Modules\Social\Models;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Models\RecipeVersion;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Rating extends Model
{
    protected $fillable = [
        'user_id', 'recipe_id', 'version_id', 'invitation_id',
        'stars', 'flavor', 'presentation', 'ease', 'value', 'comment',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function version(): BelongsTo
    {
        return $this->belongsTo(RecipeVersion::class, 'version_id');
    }
}
