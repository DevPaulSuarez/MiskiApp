<?php

namespace App\Modules\Social\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class CommentResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'user_id' => (string) $this->user_id,
            'version_id' => (string) $this->version_id,
            'text' => $this->text,
            'created_at' => $this->created_at->toIso8601ZuluString(),
        ];
    }
}
