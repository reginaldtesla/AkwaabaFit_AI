<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['consultation_id', 'actor_user_id', 'action', 'meta'])]
class ConsultationActivityLog extends Model
{
    public $timestamps = false;

    protected static function booted(): void
    {
        static::creating(function (ConsultationActivityLog $log): void {
            if ($log->created_at === null) {
                $log->created_at = now();
            }
        });
    }

    protected function casts(): array
    {
        return [
            'meta' => 'array',
            'created_at' => 'datetime',
        ];
    }

    public function consultation(): BelongsTo
    {
        return $this->belongsTo(Consultation::class);
    }

    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
