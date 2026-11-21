<?php

namespace App\Modules\Social\Models;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Models\Recipe;
use App\Modules\Recipes\Models\RecipeVersion;
use App\Modules\Social\Enums\InvitationStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Invitation extends Model
{
    protected $fillable = ['recipe_id', 'version_id', 'from_user_id', 'to_user_id', 'message', 'status'];

    protected $attributes = ['message' => '', 'status' => 'pending'];

    protected function casts(): array
    {
        return ['status' => InvitationStatus::class];
    }

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(Recipe::class);
    }

    public function version(): BelongsTo
    {
        return $this->belongsTo(RecipeVersion::class, 'version_id');
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'from_user_id');
    }

    public function guest(): BelongsTo
    {
        return $this->belongsTo(User::class, 'to_user_id');
    }
}
