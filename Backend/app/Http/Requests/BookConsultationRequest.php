<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class BookConsultationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'dietician_name' => ['required', 'string', 'max:255'],
            'scheduled_time' => ['nullable', 'date', 'after:now'],
        ];
    }
}