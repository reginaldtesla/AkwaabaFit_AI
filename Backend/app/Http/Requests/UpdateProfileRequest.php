<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Partial PATCH supported (e.g. step_goal-only sync from mobile).
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'is_public_on_leaderboard' => ['sometimes', 'required', 'boolean'],
            'age' => ['nullable', 'integer', 'min:1', 'max:120'],
            'gender' => ['nullable', 'string', 'in:Male,Female,Other,Prefer not to say'],
            'height' => ['nullable', 'integer', 'min:50', 'max:250'],
            'weight' => ['nullable', 'integer', 'min:20', 'max:300'],
            'activity_level' => ['nullable', 'string', 'in:Sedentary,Lightly active,Moderately active,Very active,Extremely active'],
            'step_goal' => ['nullable', 'integer', 'min:10', 'max:1000000'],
            'daily_calories_target' => ['nullable', 'integer', 'min:800', 'max:8000'],
            // New mobile onboarding values
            'goal' => ['nullable', 'string', 'in:Gain weight,Lose weight,Maintain weight'],
            'workout_time_preference' => ['nullable', 'string', 'in:Morning,Evening,Flexible'],
            'workout_days_per_week' => ['nullable', 'integer', 'min:1', 'max:7'],
            'profile_completed' => ['boolean'],
        ];
    }
}
