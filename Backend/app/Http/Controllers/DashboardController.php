<?php

namespace App\Http\Controllers;

use App\Models\DailyStepLog;
use Illuminate\Http\JsonResponse;

class DashboardController extends Controller
{
    public function show(): JsonResponse
    {
        $user = auth()->user();

        $today = now()->toDateString();

        $gender = strtolower((string) ($user->gender ?? ''));
        $avatarUrl = match ($gender) {
            'male' => 'https://i.pravatar.cc/150?img=12',
            'female' => 'https://i.pravatar.cc/150?img=47',
            default => 'https://i.pravatar.cc/150?img=5',
        };

        $todaySteps = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $today)
            ->value('step_count') ?? 0;

        $activityLevel = (string) ($user->activity_level ?? '');

        $stepGoal = match ($activityLevel) {
            'Sedentary' => 6000,
            'Lightly active' => 8000,
            'Moderately active' => 10000,
            'Very active' => 12000,
            'Extremely active' => 14000,
            default => 10000,
        };

        $weightKg = is_numeric($user->weight) ? (float) $user->weight : null;
        $hydrationGoal = $weightKg ? max(2.0, round($weightKg * 0.035, 1)) : 2.5;
        $hydrationLiters = round(min($hydrationGoal, ($todaySteps / $stepGoal) * 0.5), 1);

        // Very rough estimates until meals/workouts are implemented.
        $burnedKcal = (int) round($todaySteps * 0.04);
        $consumedKcal = 0;
        $netKcal = $consumedKcal - $burnedKcal;

        // Until the OpenWeatherMap + air-quality engine is wired, return a placeholder alert.
        $alertTitle = 'No Alerts';
        $alertMessage = 'All clear. Stay hydrated and keep moving today.';

        return response()->json([
            'userName' => $user->name,
            'avatarUrl' => $avatarUrl,
            'netKcal' => $netKcal,
            'consumedKcal' => $consumedKcal,
            'burnedKcal' => $burnedKcal,
            'tempCelsius' => 0.0,
            'location' => 'Accra, GH',
            'alertTitle' => $alertTitle,
            'alertMessage' => $alertMessage,
            'hydrationLiters' => $hydrationLiters,
            'hydrationGoal' => $hydrationGoal,
            'currentSteps' => $todaySteps,
            'stepGoal' => $stepGoal,
            'calories' => max(0, $netKcal),
            'activeMinutes' => (int) round($todaySteps / 120),
        ]);
    }
}

