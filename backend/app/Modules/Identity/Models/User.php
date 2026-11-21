<?php

namespace App\Modules\Identity\Models;

use App\Modules\Catalog\Models\Category;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\UseFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;

#[UseFactory(UserFactory::class)]
class User extends Authenticatable
{
    use HasApiTokens, HasFactory;

    protected $fillable = ['name', 'handle', 'email', 'password', 'bio', 'birthday', 'favorite_foods'];

    protected $hidden = ['password', 'remember_token'];

    protected $attributes = ['bio' => ''];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'birthday' => 'date',
            'favorite_foods' => 'array',
        ];
    }

    public function favoriteCategories(): BelongsToMany
    {
        return $this->belongsToMany(Category::class, 'user_favorite_categories');
    }

    /** A free handle derived from the name: "María Quispe" -> "mariaquispe", "mariaquispe2"... */
    public static function uniqueHandleFrom(string $name): string
    {
        $base = Str::limit(Str::slug($name, ''), 24, '') ?: 'cocinero';
        $handle = $base;
        for ($i = 2; static::where('handle', $handle)->exists(); $i++) {
            $handle = $base.$i;
        }

        return $handle;
    }
}
