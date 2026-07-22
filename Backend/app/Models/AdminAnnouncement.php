<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AdminAnnouncement extends Model
{
    protected $fillable = [
        'title',
        'body',
        'sent_at',
        'push_attempted',
        'push_succeeded',
    ];

    protected function casts(): array
    {
        return [
            'sent_at' => 'datetime',
            'push_attempted' => 'integer',
            'push_succeeded' => 'integer',
        ];
    }
}
