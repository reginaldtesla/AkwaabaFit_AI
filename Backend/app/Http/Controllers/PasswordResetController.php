<?php

namespace App\Http\Controllers;

use App\Http\Requests\ApiResetPasswordRequest;
use App\Http\Requests\ForgotPasswordRequest;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;

class PasswordResetController extends Controller
{
    /**
     * Sends the reset code by email only (same address must exist on an account).
     * Response does not reveal whether the address exists.
     */
    public function forgot(ForgotPasswordRequest $request): JsonResponse
    {
        $email = mb_strtolower(trim((string) $request->input('email')));

        $user = User::query()
            ->whereRaw('LOWER(email) = ?', [$email])
            ->first();

        if ($user === null) {
            return response()->json([
                'message' => 'If an account exists for that email, we sent reset instructions.',
            ]);
        }

        $status = Password::sendResetLink(['email' => $user->email]);

        if ($status === Password::RESET_THROTTLED) {
            return response()->json([
                'message' => 'Please wait a minute before requesting another reset.',
            ], 429);
        }

        return response()->json([
            'message' => 'If an account exists for that email, we sent reset instructions.',
        ]);
    }

    public function reset(ApiResetPasswordRequest $request): JsonResponse
    {
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password): void {
                $user->forceFill([
                    'password' => Hash::make($password),
                ])->setRememberToken(Str::random(60));

                $user->save();

                event(new PasswordReset($user));
            }
        );

        return match ($status) {
            Password::PASSWORD_RESET => response()->json([
                'message' => 'Password updated. You can sign in with your new password.',
            ]),
            Password::INVALID_TOKEN => response()->json([
                'message' => 'This reset code is invalid or has expired. Request a new one.',
            ], 422),
            Password::INVALID_USER => response()->json([
                'message' => 'We could not find an account with that email.',
            ], 422),
            default => response()->json([
                'message' => 'Unable to reset password. Try again.',
            ], 422),
        };
    }
}
