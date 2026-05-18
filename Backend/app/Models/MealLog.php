<?php

namespace App\Models;

use Database\Factories\MealLogFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MealLog extends Model
{
    /** @use HasFactory<MealLogFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'eaten_at',
        'meal_type',
        'name',
        'calories',
        'protein_g',
        'carbs_g',
        'fat_g',
        'safety_status',
        'insight_message',
        'image_url',
        'source',
        'meta',
    ];

    protected $casts = [
        'eaten_at' => 'datetime',
        'calories' => 'integer',
        'protein_g' => 'integer',
        'carbs_g' => 'integer',
        'fat_g' => 'integer',
        'meta' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
