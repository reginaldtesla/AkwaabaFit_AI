<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AppVersionController extends Controller
{
    /**
     * Public version check for optional in-app update banner.
     */
    public function show(Request $request): JsonResponse
    {
        $platform = strtolower(trim((string) $request->query('platform', '')));
        if (! in_array($platform, ['android', 'ios'], true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'platform must be android or ios',
            ], 422);
        }

        $cfg = config("mobile_app.{$platform}", []);
        $latest = (string) ($cfg['latest_version'] ?? '1.0.0');
        $min = (string) ($cfg['min_version'] ?? $latest);
        $storeUrl = trim((string) ($cfg['store_url'] ?? ''));
        $current = $this->normalizeVersion((string) $request->query('version', '0.0.0'));

        $updateAvailable = $storeUrl !== ''
            && version_compare($current, $latest, '<');

        $forceUpdate = $storeUrl !== ''
            && version_compare($current, $min, '<');

        return response()->json([
            'status' => 'success',
            'platform' => $platform,
            'current_version' => $current,
            'latest_version' => $latest,
            'min_version' => $min,
            'update_available' => $updateAvailable,
            'force_update' => $forceUpdate,
            'store_url' => $storeUrl !== '' ? $storeUrl : null,
            'message' => (string) ($cfg['message'] ?? 'A new version is available.'),
        ]);
    }

    private function normalizeVersion(string $raw): string
    {
        $raw = trim($raw);
        if ($raw === '') {
            return '0.0.0';
        }

        // Flutter package_info: "1.0.0" or build metadata; strip +build.
        $base = explode('+', $raw)[0];
        $base = explode('-', $base)[0];

        if (preg_match('/^\d+(\.\d+){0,2}$/', $base) === 1) {
            $parts = explode('.', $base);
            while (count($parts) < 3) {
                $parts[] = '0';
            }

            return implode('.', array_slice($parts, 0, 3));
        }

        return '0.0.0';
    }
}
