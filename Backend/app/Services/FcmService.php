<?php

namespace App\Services;

use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\HttpHandler\HttpHandlerFactory;
use GuzzleHttp\Client;
use Illuminate\Support\Facades\Cache;

class FcmService
{
    public function sendToToken(string $deviceToken, array $notification, array $data = []): bool
    {
        $projectId = config('services.fcm.project_id');
        $serviceAccountPath = config('services.fcm.service_account_json');

        if (! $projectId || ! $serviceAccountPath || ! is_file($serviceAccountPath)) {
            return false;
        }

        $accessToken = $this->accessToken($serviceAccountPath);
        if (! $accessToken) {
            return false;
        }

        $client = new Client($this->guzzleOptions());

        $payload = [
            'message' => [
                'token' => $deviceToken,
                'notification' => [
                    'title' => (string) ($notification['title'] ?? ''),
                    'body' => (string) ($notification['body'] ?? ''),
                ],
                'data' => collect($data)->map(fn ($v) => (string) $v)->all(),
                'android' => [
                    'priority' => 'HIGH',
                ],
            ],
        ];

        $resp = $client->post(
            "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send",
            [
                'headers' => [
                    'Authorization' => "Bearer {$accessToken}",
                    'Content-Type' => 'application/json',
                ],
                'json' => $payload,
            ]
        );

        return $resp->getStatusCode() >= 200 && $resp->getStatusCode() < 300;
    }

    private function accessToken(string $serviceAccountPath): ?string
    {
        return Cache::remember('fcm_access_token', 50 * 60, function () use ($serviceAccountPath) {
            $scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
            $creds = new ServiceAccountCredentials($scopes, $serviceAccountPath);
            $httpHandler = HttpHandlerFactory::build(new Client($this->guzzleOptions()));
            $token = $creds->fetchAuthToken($httpHandler);

            return $token['access_token'] ?? null;
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function guzzleOptions(): array
    {
        $opts = ['timeout' => 8];
        $bundle = storage_path('cacert.pem');
        if (is_readable($bundle)) {
            $opts['verify'] = $bundle;
        }

        return $opts;
    }
}
