<?php

namespace App\Modules\Recipes\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Str;

class RecipeResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'description' => $this->description,
            'image_url' => self::imageUrl($this->image_url),
            'category_id' => (string) $this->category_id,
            'author_id' => (string) $this->author_id,
            'created_at' => $this->created_at->toIso8601ZuluString(),
            'main_version_id' => (string) $this->main_version_id,
            'status' => $this->status->value,
        ];
    }

    /** Uploaded photos are stored as paths; resolve them against the host the app is using. */
    public static function imageUrl(string $value): string
    {
        if ($value === '' || Str::startsWith($value, ['http://', 'https://'])) {
            return $value;
        }

        return url('storage/'.ltrim($value, '/'));
    }
}
