<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class StoreDietitianApplicationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        foreach (['phone', 'alt_phone'] as $key) {
            if (! $this->has($key)) {
                continue;
            }
            $digits = preg_replace('/\D+/', '', (string) $this->input($key));
            $this->merge([$key => $digits !== '' ? $digits : null]);
        }

        if ($this->has('ghana_card_number')) {
            $this->merge([
                'ghana_card_number' => strtoupper(trim((string) $this->input('ghana_card_number'))),
            ]);
        }
    }

    public function rules(): array
    {
        return [
            'full_name' => ['required', 'string', 'max:255'],
            'date_of_birth' => ['required', 'date', 'before:today', 'after:1900-01-01'],
            'age' => ['required', 'integer', 'min:18', 'max:80'],
            'phone' => ['required', 'string', 'min:9', 'max:15'],
            'alt_phone' => ['required', 'string', 'min:9', 'max:15', 'different:phone'],
            'professional_email' => ['required', 'email', 'max:255'],
            'ghana_card_number' => ['required', 'string', 'max:32'],
            'residential_address' => ['required', 'string', 'max:500'],
            'city' => ['required', 'string', 'max:120'],
            'region' => ['required', 'string', 'max:120'],
            'highest_qualification' => ['required', 'string', 'max:255'],
            'institution' => ['required', 'string', 'max:255'],
            'years_experience' => ['required', 'integer', 'min:0', 'max:60'],
            'license_number' => ['required', 'string', 'min:3', 'max:120'],
            'bio' => ['required', 'string', 'min:80', 'max:3000'],
            'specialty' => ['required', 'string', 'max:255'],
            'category' => ['required', 'string', 'max:255'],
            'hourly_rate' => ['required', 'integer', 'min:1', 'max:100000'],
            'certificate' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:20480'],
            'ghana_card' => ['required', 'file', 'mimes:pdf,jpg,jpeg,png', 'max:10240'],
            'profile_photo' => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:5120'],
            'cv' => ['required', 'file', 'mimes:pdf', 'max:20480'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            if ($validator->errors()->isNotEmpty()) {
                return;
            }

            $dob = $this->date('date_of_birth');
            $age = (int) $this->input('age');
            if ($dob === null) {
                return;
            }

            $computed = $dob->age;
            if (abs($computed - $age) > 1) {
                $validator->errors()->add('age', 'Age does not match date of birth.');
            }
        });
    }
}
