<?php

namespace App\Modules\Notifications;

use App\Modules\Core\ModuleServiceProvider;
use App\Modules\Notifications\Listeners\SendActivityNotifications as L;
use App\Modules\Recipes\Events\VersionPublished;
use App\Modules\Social\Events\CommentPosted;
use App\Modules\Social\Events\InvitationAnswered;
use App\Modules\Social\Events\InvitationSent;
use App\Modules\Social\Events\RatingCreated;

/**
 * In-app notifications. Listens to the other modules' events, so those
 * modules never depend on this one (switching it off just stops notifications).
 * Push notifications (FCM) can be added later as another listener.
 */
class NotificationsServiceProvider extends ModuleServiceProvider
{
    protected array $listen = [
        VersionPublished::class => [[L::class, 'versionPublished']],
        InvitationSent::class => [[L::class, 'invitationSent']],
        InvitationAnswered::class => [[L::class, 'invitationAnswered']],
        RatingCreated::class => [[L::class, 'ratingCreated']],
        CommentPosted::class => [[L::class, 'commentPosted']],
    ];
}
