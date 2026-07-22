<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging HTTP v1 (optional).
 * Requires FIREBASE_CREDENTIALS pointing at a service-account JSON file.
 */
class FcmPushService
{
    public function isConfigured(): bool
    {
        $path = $this->credentialsPath();

        return $path !== '' && is_readable($path);
    }

    /**
     * @param  list<string>  $tokens
     * @return array{attempted: int, succeeded: int}
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): array
    {
        $tokens = array_values(array_unique(array_filter(array_map('strval', $tokens))));
        if ($tokens === [] || ! $this->isConfigured()) {
            return ['attempted' => 0, 'succeeded' => 0];
        }

        $accessToken = $this->accessToken();
        $projectId = $this->projectId();
        if ($accessToken === null || $projectId === null) {
            return ['attempted' => count($tokens), 'succeeded' => 0];
        }

        $succeeded = 0;
        foreach (array_chunk($tokens, 100) as $chunk) {
            foreach ($chunk as $token) {
                $response = Http::timeout(20)
                    ->withToken($accessToken)
                    ->post(
                        "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send",
                        [
                            'message' => [
                                'token' => $token,
                                'notification' => [
                                    'title' => $title,
                                    'body' => $body,
                                ],
                                'data' => array_map('strval', array_merge([
                                    'type' => 'admin_broadcast',
                                    'title' => $title,
                                    'body' => $body,
                                ], $data)),
                                'android' => [
                                    'priority' => 'HIGH',
                                    'notification' => [
                                        'channel_id' => 'akwaaba_admin_broadcast',
                                        'sound' => 'default',
                                    ],
                                ],
                            ],
                        ],
                    );

                if ($response->successful()) {
                    $succeeded++;
                } else {
                    Log::warning('FCM send failed', [
                        'status' => $response->status(),
                        'body' => $response->body(),
                    ]);
                }
            }
        }

        return ['attempted' => count($tokens), 'succeeded' => $succeeded];
    }

    private function credentialsPath(): string
    {
        return trim((string) config('services.firebase.credentials', ''));
    }

    private function projectId(): ?string
    {
        $configured = trim((string) config('services.firebase.project_id', ''));
        if ($configured !== '') {
            return $configured;
        }

        $creds = $this->credentials();

        return is_string($creds['project_id'] ?? null) ? $creds['project_id'] : null;
    }

    /**
     * @return array<string, mixed>
     */
    private function credentials(): array
    {
        $path = $this->credentialsPath();
        if ($path === '' || ! is_readable($path)) {
            return [];
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        return is_array($decoded) ? $decoded : [];
    }

    private function accessToken(): ?string
    {
        return Cache::remember('fcm_access_token', 3000, function () {
            $creds = $this->credentials();
            $clientEmail = $creds['client_email'] ?? null;
            $privateKey = $creds['private_key'] ?? null;
            if (! is_string($clientEmail) || ! is_string($privateKey) || $clientEmail === '' || $privateKey === '') {
                Log::warning('FCM credentials missing client_email/private_key');

                return null;
            }

            $now = time();
            $jwtHeader = $this->base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $jwtClaim = $this->base64UrlEncode(json_encode([
                'iss' => $clientEmail,
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            $unsigned = $jwtHeader.'.'.$jwtClaim;
            $signature = '';
            $ok = openssl_sign($unsigned, $signature, $privateKey, OPENSSL_ALGO_SHA256);
            if (! $ok) {
                Log::warning('FCM JWT sign failed');

                return null;
            }
            $assertion = $unsigned.'.'.$this->base64UrlEncode($signature);

            $response = Http::asForm()->timeout(20)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);

            if (! $response->successful()) {
                Log::warning('FCM oauth token failed', ['status' => $response->status(), 'body' => $response->body()]);

                return null;
            }

            $token = $response->json('access_token');

            return is_string($token) && $token !== '' ? $token : null;
        });
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
