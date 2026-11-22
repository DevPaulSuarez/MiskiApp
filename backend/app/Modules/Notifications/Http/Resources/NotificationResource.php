<?php

namespace App\Modules\Notifications\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class NotificationResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (string) $this->id,
            'user_id' => (string) $this->user_id,
            'title' => $this->title,
            'body' => $this->body,
            'route' => $this->route,
            'read' => $this->read_at !== null,
            'created_at' => $this->created_at->toIso8601ZuluString(),
        ];
    }
}
