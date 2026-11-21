<?php

namespace App\Modules\Recipes\Models;

use App\Modules\Identity\Models\User;
use App\Modules\Recipes\Enums\Difficulty;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use LogicException;

/** Immutable once published: editing always creates a new version. */
class RecipeVersion extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = [
        'recipe_id', 'number', 'title', 'parent_version_id', 'created_by',
        'servings', 'prep_minutes', 'cook_minutes', 'difficulty', 'notes',
    ];

    protected function casts(): array
    {
        return ['difficulty' => Difficulty::class];
    }

    protected static function booted(): void
    {
        static::updating(fn () => throw new LogicException('Las versiones publicadas no se modifican.'));
    }

    public function recipe(): BelongsTo
    {
        return $this->belongsTo(Recipe::class);
    }

    public function parent(): BelongsTo
    {
        return $this->belongsTo(self::class, 'parent_version_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function ingredients(): HasMany
    {
        return $this->hasMany(VersionIngredient::class, 'version_id')->orderBy('position');
    }

    public function steps(): HasMany
    {
        return $this->hasMany(VersionStep::class, 'version_id')->orderBy('position');
    }
}
