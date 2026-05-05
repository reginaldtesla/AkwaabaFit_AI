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
            'name' => ['required', 'string', 'max:255'],
            'is_public_on_leaderboard' => ['required', 'boolean'],
            'age' => ['nullable', 'integer', 'min:1', 'max:120'],
            'gender' => ['nullable', 'string', 'in:Male,Female,Other,Prefer not to say'],
            'height' => ['nullable', 'integer', 'min:50', 'max:250'],
            'weight' => ['nullable', 'integer', 'min:20', 'max:300'],
            'activity_level' => ['nullable', 'string', 'in:Sedentary,Lightly active,Moderately active,Very active,Extremely active'],
            'goal' => ['nullable', 'string', 'in:Weight loss,Muscle gain,Maintain weight,Improve fitness,Health monitoring'],
            'profile_completed' => ['boolean'],
        ];
    }
}