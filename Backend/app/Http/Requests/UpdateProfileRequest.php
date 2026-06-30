<?php

namespace App\Http\Requests;

use App\Support\HealthProfileOptions;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],
            'is_public_on_leaderboard' => ['sometimes', 'required', 'boolean'],
            'age' => ['nullable', 'integer', 'min:1', 'max:120'],
            'gender' => ['nullable', 'string', 'in:Male,Female,Other,Prefer not to say'],
            'height' => ['nullable', 'integer', 'min:50', 'max:250'],
            'weight' => ['nullable', 'integer', 'min:20', 'max:300'],
            'activity_level' => ['nullable', 'string', 'in:Sedentary,Lightly active,Moderately active,Very active,Extremely active'],
            'step_goal' => ['nullable', 'integer', 'min:10', 'max:1000000'],
            'daily_calories_target' => ['nullable', 'integer', 'min:800', 'max:8000'],
            'goal' => ['nullable', 'string', Rule::in(HealthProfileOptions::goals())],
            'health_conditions' => ['nullable', 'array'],
            'health_conditions.*' => ['string', Rule::in(HealthProfileOptions::healthConditions())],
            'eating_pattern' => ['nullable', 'string', Rule::in(HealthProfileOptions::eatingPatterns())],
            'life_stage' => ['nullable', 'string', Rule::in(HealthProfileOptions::lifeStages())],
            'meal_source_preference' => ['nullable', 'string', Rule::in(HealthProfileOptions::mealSourcePreferences())],
            'activity_context' => ['nullable', 'string', Rule::in(HealthProfileOptions::activityContexts())],
            'water_goal_ml' => ['nullable', 'integer', 'min:1000', 'max:5000'],
            'meal_reminders_enabled' => ['nullable', 'boolean'],
            'workout_time_preference' => ['nullable', 'string', 'in:Morning,Evening,Flexible'],
            'workout_days_per_week' => ['nullable', 'integer', 'min:1', 'max:7'],
            'profile_completed' => ['boolean'],
        ];
    }
}
