<?php

namespace App\Http\Controllers;

use App\Services\SafetyHealthTipsService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SafetyController extends Controller
{
    public function healthTips(Request $request, SafetyHealthTipsService $tips): JsonResponse
    {
        $validated = $request->validate([
            'temp_celsius' => ['sometimes', 'nullable', 'numeric'],
            'weather_main' => ['sometimes', 'nullable', 'string', 'max:64'],
            'air_quality_aqi' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:5'],
            'refresh' => ['sometimes', 'boolean'],
        ]);

        $payload = $tips->tips(
            tempCelsius: isset($validated['temp_celsius']) ? (float) $validated['temp_celsius'] : null,
            weatherMain: $validated['weather_main'] ?? null,
            airQualityAqi: isset($validated['air_quality_aqi']) ? (int) $validated['air_quality_aqi'] : null,
            forceRefresh: $request->boolean('refresh'),
            user: $request->user(),
        );

        return response()->json([
            'status' => 'success',
            'source' => $payload['source'],
            'tips' => $payload['tips'],
            'mealRecommendations' => $payload['mealRecommendations'],
        ]);
    }
}
