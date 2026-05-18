<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable([
    'user_id',
    'full_name',
    'date_of_birth',
    'age',
    'phone',
    'alt_phone',
    'professional_email',
    'ghana_card_number',
    'ghana_card_path',
    'residential_address',
    'city',
    'region',
    'highest_qualification',
    'institution',
    'years_experience',
    'license_number',
    'bio',
    'specialty',
    'category',
    'hourly_rate',
    'rating',
    'listed_hourly_rate',
    'image_url',
    'profile_photo_path',
    'certificate_path',
    'cv_path',
    'status',
    'review_notes',
    'reviewed_at',
    'submitted_at',
])]
class DietitianApplication extends Model
{
    protected function casts(): array
    {
        return [
            'date_of_birth' => 'date',
            'age' => 'integer',
            'years_experience' => 'integer',
            'hourly_rate' => 'integer',
            'rating' => 'float',
            'listed_hourly_rate' => 'integer',
            'reviewed_at' => 'datetime',
            'submitted_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
