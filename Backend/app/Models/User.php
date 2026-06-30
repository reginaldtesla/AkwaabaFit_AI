<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Notifications\ApiPasswordResetNotification;
use Database\Factories\UserFactory;
use Illuminate\Auth\Passwords\CanResetPassword;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

#[Fillable([
    'name',
    'email',
    'username',
    'phone',
    'avatar_url',
    'password',
    'is_public_on_leaderboard',
    'is_nutrition_advisor',
    'is_staff_admin',
    'age',
    'gender',
    'height',
    'weight',
    'activity_level',
    'step_goal',
    'daily_calories_target',
    'goal',
    'health_conditions',
    'eating_pattern',
    'life_stage',
    'meal_source_preference',
    'activity_context',
    'water_goal_ml',
    'meal_reminders_enabled',
    'accountability_code',
    'workout_time_preference',
    'workout_days_per_week',
    'profile_completed',
])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use CanResetPassword, HasApiTokens, HasFactory, Notifiable;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_public_on_leaderboard' => 'boolean',
            'is_nutrition_advisor' => 'boolean',
            'is_staff_admin' => 'boolean',
            'age' => 'integer',
            'height' => 'integer',
            'weight' => 'integer',
            'step_goal' => 'integer',
            'daily_calories_target' => 'integer',
            'workout_days_per_week' => 'integer',
            'profile_completed' => 'boolean',
            'health_conditions' => 'array',
            'water_goal_ml' => 'integer',
            'meal_reminders_enabled' => 'boolean',
        ];
    }

    public function dailyStepLogs(): HasMany
    {
        return $this->hasMany(DailyStepLog::class);
    }

    public function consultations(): HasMany
    {
        return $this->hasMany(Consultation::class);
    }

    public function mealLogs(): HasMany
    {
        return $this->hasMany(MealLog::class);
    }

    public function waterLogs(): HasMany
    {
        return $this->hasMany(WaterLog::class);
    }

    /**
     * Resolve user by username, phone digits, or email (same rules as API login).
     */
    public static function findByLoginIdentifier(string $login): ?self
    {
        $login = trim($login);
        if ($login === '') {
            return null;
        }

        $user = static::query()
            ->whereRaw('LOWER(username) = ?', [mb_strtolower($login)])
            ->first();

        if ($user !== null) {
            return $user;
        }

        $digits = preg_replace('/\D+/', '', $login);
        if ($digits !== '') {
            $byPhone = static::query()->where('phone', $digits)->first();
            if ($byPhone !== null) {
                return $byPhone;
            }
        }

        if (filter_var($login, FILTER_VALIDATE_EMAIL)) {
            return static::query()
                ->whereRaw('LOWER(email) = ?', [mb_strtolower($login)])
                ->first();
        }

        return null;
    }

    public function sendPasswordResetNotification($token): void
    {
        $this->notify(new ApiPasswordResetNotification($token));
    }
}
