<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['user_id', 'log_date', 'hour', 'step_count'])]
class HourlyStepLog extends Model
{
    use HasFactory;

    protected function casts(): array
    {
        return [
            'log_date' => 'date',
            'hour' => 'integer',
            'step_count' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}

