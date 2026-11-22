<?php

namespace App\Modules\Recipes\Models;

use Illuminate\Database\Eloquent\Model;

class VersionStep extends Model
{
    public $timestamps = false;

    protected $fillable = ['version_id', 'position', 'text'];
}
