<?php

namespace App\Modules\Social\Enums;

enum InvitationStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Rejected = 'rejected';
    case Completed = 'completed'; // the guest tried it and rated it
}
