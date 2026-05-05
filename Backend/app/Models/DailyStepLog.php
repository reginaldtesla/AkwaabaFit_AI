<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'step_count', 'log_date'])]
class DailyStepLog extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'log_date' => 'date',
            'step_count' => 'integer',
        ];
    }

    // --- Relationships ---
    
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}