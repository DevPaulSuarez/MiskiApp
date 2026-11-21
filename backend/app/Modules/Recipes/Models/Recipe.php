<?php

namespace App\Modules\Recipes\Models;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Enums\RecipeStatus;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Recipe extends Model
{
    protected $fillable = ['name', 'description', 'image_url', 'category_id', 'author_id', 'main_version_id', 'status'];

    protected $attributes = ['description' => '', 'image_url' => '', 'status' => 'active'];

    protected function casts(): array
    {
        return ['status' => RecipeStatus::class];
    }

    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class, 'author_id');
    }

    public function versions(): HasMany
    {
        return $this->hasMany(RecipeVersion::class);
    }

    public function mainVersion(): BelongsTo
    {
        return $this->belongsTo(RecipeVersion::class, 'main_version_id');
    }

    public function isAuthoredBy(User $user): bool
    {
        return $this->author_id === $user->id;
    }
}
