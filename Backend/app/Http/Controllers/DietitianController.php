<?php

namespace App\Http\Controllers;

use App\Models\DietitianApplication;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class DietitianController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $dietitians = DietitianApplication::query()
            ->where('status', 'approved')
            ->whereNotNull('user_id')
            ->orderByDesc('reviewed_at')
            ->get()
            ->map(fn (DietitianApplication $a) => $this->toPublicListing($a, $request))
            ->values()
            ->all();

        return response()->json([
            'status' => 'success',
            'dietitians' => $dietitians,
        ]);
    }

    private function toPublicListing(DietitianApplication $a, Request $request): array
    {
        $hourly = (int) ($a->listed_hourly_rate ?? $a->hourly_rate ?? 0);
        $rating = $a->rating !== null ? round((float) $a->rating, 1) : 5.0;

        return [
            'id' => 'app_'.$a->id,
            'advisorUserId' => (int) $a->user_id,
            'name' => $a->full_name,
            'specialty' => $a->specialty ?? 'Dietitian',
            'category' => $a->category ?? 'General',
            'rating' => $rating,
            'hourlyRate' => $hourly,
            'imageUrl' => $this->profileImageUrl($a, $request),
        ];
    }

    private function profileImageUrl(DietitianApplication $a, Request $request): string
    {
        if (filled($a->image_url)) {
            return $this->absoluteAssetUrl($a->image_url, $request);
        }

        if (filled($a->profile_photo_path)) {
            $relative = Storage::disk('public')->url($a->profile_photo_path);
            return $this->absoluteAssetUrl($relative, $request);
        }

        return $this->absoluteAssetUrl(
            'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?auto=format&fit=crop&w=600&q=80',
            $request,
        );
    }

    private function absoluteAssetUrl(string $url, Request $request): string
    {
        if (str_starts_with($url, 'http://') || str_starts_with($url, 'https://')) {
            if (str_contains($url, 'localhost') || str_contains($url, '127.0.0.1')) {
                $path = parse_url($url, PHP_URL_PATH) ?: '';

                return rtrim($request->getSchemeAndHttpHost(), '/').$path;
            }

            return $url;
        }

        $path = str_starts_with($url, '/') ? $url : '/'.ltrim($url, '/');

        return rtrim($request->getSchemeAndHttpHost(), '/').$path;
    }
}
