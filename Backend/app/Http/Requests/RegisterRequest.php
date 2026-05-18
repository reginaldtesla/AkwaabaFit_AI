<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Validator;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (! $this->has('phone')) {
            return;
        }

        $digits = preg_replace('/\D+/', '', (string) $this->input('phone'));

        $this->merge([
            'phone' => $digits !== '' ? $digits : null,
        ]);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'username' => ['required', 'string', 'max:255', 'unique:users,username', 'regex:/^[a-zA-Z0-9._-]+$/'],
            'phone' => ['nullable', 'string', 'max:32', 'unique:users,phone'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ];
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $phone = $this->input('phone');
            if ($phone !== null && $phone !== '' && strlen((string) $phone) < 8) {
                $validator->errors()->add('phone', 'Enter a valid phone number or leave it blank.');
            }
        });
    }
}
