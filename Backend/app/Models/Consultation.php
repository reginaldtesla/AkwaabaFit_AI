<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'dietician_name', 'scheduled_time', 'payment_status', 'paystack_reference'])]
class Consultation extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'scheduled_time' => 'datetime',
        ];
    }

    // --- Relationships ---
    
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}