<?php

namespace App\Http\Controllers;

use App\Models\WaterLog;
use App\Support\HealthProfileOptions;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class HydrationController extends Controller
{
    public function today(Request $request): JsonResponse
    {
        $user = $request->user();
        $start = now()->startOfDay();
        $end = now()->endOfDay();

        $totalMl = (int) WaterLog::query()
            ->where('user_id', $user->id)
            ->whereBetween('logged_at', [$start, $end])
            ->sum('amount_ml');

        $goalMl = (int) ($user->water_goal_ml
            ?: HealthProfileOptions::defaultWaterGoalMl(is_numeric($user->weight) ? (int) $user->weight : null));

        return response()->json([
            'status' => 'success',
            'totalMl' => $totalMl,
            'goalMl' => $goalMl,
            'glasses' => (int) floor($totalMl / 250),
            'goalGlasses' => (int) max(1, round($goalMl / 250)),
        ]);
    }

    public function log(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount_ml' => ['required', 'integer', 'min:50', 'max:2000'],
            'logged_at' => ['nullable', 'date'],
        ]);

        $user = $request->user();
        $entry = WaterLog::create([
            'user_id' => $user->id,
            'amount_ml' => (int) $data['amount_ml'],
            'logged_at' => isset($data['logged_at'])
                ? Carbon::parse($data['logged_at'])
                : now(),
        ]);

        return response()->json([
            'status' => 'success',
            'entry' => $entry,
        ], 201);
    }
}
