<?php

namespace App\Http\Controllers;

use App\Models\DailyStepLog;
use App\Models\HourlyStepLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Schema;

class ActivityController extends Controller
{
    public function today(): JsonResponse
    {
        $user = auth()->user();
        $today = now()->toDateString();

        $stepsToday = (int) DailyStepLog::query()
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

        $calories = (int) round($stepsToday * 0.04);
        $distanceKm = round($stepsToday * 0.0008, 2); // ~0.8m average step length
        $activeMinutes = (int) round($stepsToday / 120);

        $streakDays = $this->calculateStepStreak($user->id);

        $hourly = collect();
        if (Schema::hasTable('hourly_step_logs')) {
            $hourly = HourlyStepLog::query()
                ->where('user_id', $user->id)
                ->whereDate('log_date', $today)
                ->get(['hour', 'step_count']);
        }

        // Aggregate into 8 buckets (3-hour blocks) for the UI chart.
        $buckets = array_fill(0, 8, 0);
        foreach ($hourly as $row) {
            $index = (int) floor(((int) $row->hour) / 3);
            if ($index < 0 || $index > 7) {
                continue;
            }
            $buckets[$index] += (int) $row->step_count;
        }

        $maxBucket = max($buckets) ?: 1;
        $hourlyData = array_map(
            fn (int $v) => round($v / $maxBucket, 3),
            $buckets
        );

        return response()->json([
            'stepsToday' => $stepsToday,
            'stepGoal' => $stepGoal,
            'streakDays' => $streakDays,
            'calories' => $calories,
            'distanceKm' => $distanceKm,
            'activeMinutes' => $activeMinutes,
            'hourlyData' => $hourlyData,
            'hasHourlyData' => $hourly->isNotEmpty(),
        ]);
    }

    private function calculateStepStreak(int $userId): int
    {
        $date = now()->toDateString();
        $streak = 0;

        while (true) {
            $hasSteps = DailyStepLog::query()
                ->where('user_id', $userId)
                ->whereDate('log_date', $date)
                ->where('step_count', '>', 0)
                ->exists();

            if (! $hasSteps) {
                break;
            }

            $streak++;
            $date = now()->subDays($streak)->toDateString();
        }

        return $streak;
    }
}

