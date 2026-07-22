<?php

namespace App\Http\Controllers;

use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Models\User;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = User::create([
            'name' => $request->name,
            'username' => $request->username,
            'phone' => $request->phone,
            'email' => $request->email,
            'password' => Hash::make($request->password),
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::findByLoginIdentifier($request->login);

        if (
            ! $user
            || blank($user->password)
            || ! Hash::check($request->password, $user->password)
        ) {
            throw ValidationException::withMessages([
                'login' => ['The provided credentials are incorrect.'],
            ]);
        }

        $token = $user->createToken($request->device_name)->plainTextToken;

        return response()->json([
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function google(Request $request, GoogleIdTokenVerifier $verifier): JsonResponse
    {
        $validated = $request->validate([
            'id_token' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:120'],
        ]);

        $google = $verifier->verify($validated['id_token']);
        $user = User::query()->where('google_id', $google['google_id'])->first();

        if ($user === null) {
            $user = User::query()
                ->whereRaw('LOWER(email) = ?', [$google['email']])
                ->first();
        }

        if ($user === null) {
            $user = User::create([
                'name' => $google['name'],
                'email' => $google['email'],
                'username' => $this->uniqueUsernameFromEmail($google['email']),
                'google_id' => $google['google_id'],
                'avatar_url' => $google['picture'],
                'password' => Str::password(48),
                'email_verified_at' => now(),
            ]);
        } else {
            $updates = ['google_id' => $google['google_id']];
            if (blank($user->avatar_url) && filled($google['picture'])) {
                $updates['avatar_url'] = $google['picture'];
            }
            if ($user->email_verified_at === null) {
                $updates['email_verified_at'] = now();
            }
            $user->forceFill($updates)->save();
        }

        $deviceName = trim((string) ($validated['device_name'] ?? ''));
        if ($deviceName === '') {
            $deviceName = 'AkwaabaFit Google';
        }

        $token = $user->createToken($deviceName)->plainTextToken;

        return response()->json([
            'user' => $user->fresh(),
            'token' => $token,
        ]);
    }

    public function logout(): JsonResponse
    {
        auth()->user()->tokens()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    private function uniqueUsernameFromEmail(string $email): string
    {
        $base = Str::lower((string) strstr($email, '@', true));
        $base = preg_replace('/[^a-z0-9_]/', '', $base) ?: 'user';
        $base = Str::limit($base, 20, '');

        $candidate = $base;
        $suffix = 0;
        while (
            User::query()
                ->whereRaw('LOWER(username) = ?', [mb_strtolower($candidate)])
                ->exists()
        ) {
            $suffix++;
            $candidate = Str::limit($base, 16, '').$suffix;
        }

        return $candidate;
    }
}
