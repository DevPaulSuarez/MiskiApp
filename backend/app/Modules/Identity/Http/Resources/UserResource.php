<?php

namespace App\Modules\Identity\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Public profile: what other people can see. Never includes the e-mail. */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'name' => $this->name,
            'handle' => '@'.$this->handle,
            'bio' => $this->bio,
            'birthday' => $this->birthday?->toDateString(),
            'favorite_category_ids' => $this->whenLoaded(
                'favoriteCategories',
                fn () => $this->favoriteCategories->map(fn ($c) => (string) $c->id)->values(),
                [],
            ),
            'favorite_foods' => $this->favorite_foods ?? [],
        ];
    }
}
