<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BroadcastingClientConfigController extends Controller
{
    /**
     * Minimal client settings for Laravel Echo / Pusher-compatible apps (e.g. Reverb).
     * Authenticated users only; channel auth still enforces consultation membership.
     *
     * Uses the incoming HTTP host for auth URL (and LAN Reverb host when config still points at localhost).
     */
    public function show(Request $request): JsonResponse
    {
        $default = config('broadcasting.default');
        $reverb = config('broadcasting.connections.reverb', []);
        $opts = is_array($reverb['options'] ?? null) ? $reverb['options'] : [];

        $wsHost = $opts['host'] ?? null;
        $requestHost = $request->getHost();
        if (is_string($wsHost) && in_array($wsHost, ['127.0.0.1', 'localhost'], true)
            && ! in_array($requestHost, ['127.0.0.1', 'localhost'], true)) {
            $wsHost = $requestHost;
        }

        $authBase = $request->getSchemeAndHttpHost();

        return response()->json([
            'status' => 'success',
            'broadcast' => [
                'driver' => $default,
                'key' => $reverb['key'] ?? null,
                'ws_host' => $wsHost,
                'ws_port' => (int) ($opts['port'] ?? 443),
                'use_tls' => (bool) ($opts['useTLS'] ?? false),
                'auth_endpoint' => $authBase.'/broadcasting/auth',
            ],
        ]);
    }
}
