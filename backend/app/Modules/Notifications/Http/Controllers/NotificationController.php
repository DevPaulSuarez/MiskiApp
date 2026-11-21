<?php

namespace App\Modules\Notifications\Http\Controllers;

use App\Modules\Notifications\Http\Resources\NotificationResource;
use App\Modules\Notifications\Models\AppNotification;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\Response;

class NotificationController
{
    public const LIMIT = 100;

    public function index(Request $request): AnonymousResourceCollection
    {
        return NotificationResource::collection(self::latestFor($request->user()->id));
    }

    public function read(Request $request, AppNotification $notification): NotificationResource
    {
        abort_unless($notification->user_id === $request->user()->id, 404);
        $notification->read_at ??= now();
        $notification->save();

        return new NotificationResource($notification);
    }

    public function readAll(Request $request): Response
    {
        AppNotification::where('user_id', $request->user()->id)->whereNull('read_at')->update(['read_at' => now()]);

        return response()->noContent();
    }

    public static function latestFor(int $userId)
    {
        return AppNotification::where('user_id', $userId)->latest()->latest('id')->limit(self::LIMIT)->get();
    }
}
