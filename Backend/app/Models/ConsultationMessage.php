<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['consultation_id', 'sender', 'body', 'read_at', 'attachments'])]
class ConsultationMessage extends Model
{
    protected function casts(): array
    {
        return [
            'read_at' => 'datetime',
            'attachments' => 'array',
        ];
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }
}
