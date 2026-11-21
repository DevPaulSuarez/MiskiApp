<?php

namespace App\Modules\Social\Events;

use App\Modules\Social\Models\Invitation;
use Illuminate\Foundation\Events\Dispatchable;

class InvitationSent
{
    use Dispatchable;

    public function __construct(public readonly Invitation $invitation) {}
}
