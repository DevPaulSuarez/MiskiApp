<?php

namespace App\Modules\Social\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class InvitationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'recipe_id' => (string) $this->recipe_id,
            'version_id' => (string) $this->version_id,
            'from_user_id' => (string) $this->from_user_id,
            'to_user_id' => (string) $this->to_user_id,
            'message' => $this->message,
            'status' => $this->status->value,
            'created_at' => $this->created_at->toIso8601ZuluString(),
        ];
    }
}
