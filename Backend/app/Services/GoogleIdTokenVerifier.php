<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Validation\ValidationException;

/**
 * Verifies Google ID tokens from the mobile Google Sign-In SDK.
 */
class GoogleIdTokenVerifier
{
    /**
     * @return array{
     *   google_id: string,
     *   email: string,
     *   email_verified: bool,
     *   name: string,
     *   picture: string|null
     * }
     */
    public function verify(string $idToken): array
    {
        $idToken = trim($idToken);
        if ($idToken === '') {
            throw ValidationException::withMessages([
                'id_token' => ['Google sign-in token is missing.'],
            ]);
        }

        $allowedAudiences = $this->allowedClientIds();
        if ($allowedAudiences === []) {
            throw ValidationException::withMessages([
                'id_token' => ['Google sign-in is not configured on the server.'],
            ]);
        }

        try {
            $response = Http::timeout(15)
                ->acceptJson()
                ->get('https://oauth2.googleapis.com/tokeninfo', [
                    'id_token' => $idToken,
                ]);
        } catch (\Throwable) {
            throw ValidationException::withMessages([
                'id_token' => ['Could not verify Google sign-in. Try again.'],
            ]);
        }

        if (! $response->successful()) {
            throw ValidationException::withMessages([
                'id_token' => ['Google sign-in token is invalid or expired.'],
            ]);
        }

        /** @var array<string, mixed> $payload */
        $payload = $response->json() ?? [];
        $googleId = trim((string) ($payload['sub'] ?? ''));
        $email = mb_strtolower(trim((string) ($payload['email'] ?? '')));
        $audience = trim((string) ($payload['aud'] ?? ''));
        $emailVerified = filter_var($payload['email_verified'] ?? false, FILTER_VALIDATE_BOOLEAN)
            || $payload['email_verified'] === 'true';

        if ($googleId === '' || $email === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw ValidationException::withMessages([
                'id_token' => ['Google account email is required.'],
            ]);
        }

        if (! $emailVerified) {
            throw ValidationException::withMessages([
                'id_token' => ['Please verify your Google email, then try again.'],
            ]);
        }

        if ($audience === '' || ! in_array($audience, $allowedAudiences, true)) {
            throw ValidationException::withMessages([
                'id_token' => ['Google sign-in client is not allowed for this app.'],
            ]);
        }

        return [
            'google_id' => $googleId,
            'email' => $email,
            'email_verified' => true,
            'name' => trim((string) ($payload['name'] ?? '')) ?: strstr($email, '@', true) ?: 'AkwaabaFit Member',
            'picture' => filled($payload['picture'] ?? null) ? (string) $payload['picture'] : null,
        ];
    }

    /**
     * @return list<string>
     */
    private function allowedClientIds(): array
    {
        $ids = config('services.google.client_ids', []);
        if (! is_array($ids)) {
            return [];
        }

        return array_values(array_unique(array_filter(array_map(
            static fn ($id) => trim((string) $id),
            $ids,
        ))));
    }
}
