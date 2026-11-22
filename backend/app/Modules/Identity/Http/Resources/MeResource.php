<?php

namespace App\Modules\Identity\Http\Resources;

use Illuminate\Http\Request;

/** The signed-in user's own profile (adds private fields). */
class MeResource extends UserResource
{
    public function toArray(Request $request): array
    {
        return [...parent::toArray($request), 'email' => $this->email];
    }
}
