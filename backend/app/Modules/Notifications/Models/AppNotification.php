<?php

namespace App\Modules\Notifications\Models;

use Illuminate\Database\Eloquent\Model;

class AppNotification extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['user_id', 'title', 'body', 'route', 'read_at'];

    protected function casts(): array
    {
        return ['read_at' => 'datetime'];
    }

    public static function send(int $to, string $title, string $body, ?string $route = null): self
    {
        return static::create(['user_id' => $to, 'title' => $title, 'body' => $body, 'route' => $route]);
    }
}
