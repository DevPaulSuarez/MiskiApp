<?php

namespace App\Modules\Social\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RatingResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'user_id' => (string) $this->user_id,
            'recipe_id' => (string) $this->recipe_id,
            'version_id' => (string) $this->version_id,
            'invitation_id' => $this->invitation_id ? (string) $this->invitation_id : null,
            'stars' => $this->stars,
            'flavor' => $this->flavor,
            'presentation' => $this->presentation,
            'ease' => $this->ease,
            'value' => $this->value,
            'comment' => (string) $this->comment,
            'created_at' => $this->created_at->toIso8601ZuluString(),
        ];
    }
}
