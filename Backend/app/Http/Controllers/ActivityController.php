<?php

namespace App\Http\Controllers;

use App\Models\DailyStepLog;
use App\Models\HourlyStepLog;
use App\Services\OpenMeteoService;
use App\Support\LeaderboardCache;
use App\Support\WeatherCoordinates;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Schema;

class ActivityController extends Controller
{
    public function today(Request $request): JsonResponse
    {
        $user = auth()->user();
        $today = now()->toDateString();

        $stepsToday = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $today)
            ->value('step_count') ?? 0;

        $yesterdayDate = now()->subDay()->toDateString();
        $yesterdayRow = DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $yesterdayDate)
            ->first();
        $stepsYesterday = $yesterdayRow !== null ? (int) $yesterdayRow->step_count : null;

        $activityLevel = (string) ($user->activity_level ?? '');
        $stepGoal = match ($activityLevel) {
            'Sedentary' => 6000,
            'Lightly active' => 8000,
            'Moderately active' => 10000,
            'Very active' => 12000,
            'Extremely active' => 14000,
            default => 10000,
        };
        if (is_numeric($user->step_goal) && (int) $user->step_goal > 0) {
            $stepGoal = (int) $user->step_goal;
        }

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

        // Mobile sends cumulative "steps today" per ping; each DB row keeps the max for that clock hour.
        // Convert to approximate steps *during* each 3-hour bucket: peak inside bucket minus peak before it.
        $buckets = $this->hourlyBucketsFromCumulativeLogs($hourly);

        $maxBucket = max($buckets) ?: 1;
        $hourlyData = array_map(
            fn (int $v) => round($v / $maxBucket, 3),
            $buckets
        );

        [$weatherLat, $weatherLon] = WeatherCoordinates::optionalFromRequest($request);
        $weather = app(OpenMeteoService::class)->snapshot($weatherLat, $weatherLon);

        return response()->json([
            'stepsToday' => $stepsToday,
            'stepsYesterday' => $stepsYesterday,
            'stepGoal' => $stepGoal,
            'streakDays' => $streakDays,
            'calories' => $calories,
            'distanceKm' => $distanceKm,
            'activeMinutes' => $activeMinutes,
            'hourlyData' => $hourlyData,
            'hourlyBucketSteps' => array_values($buckets),
            'hasHourlyData' => $hourly->isNotEmpty(),
            'weather' => [
                'tempCelsius' => $weather['tempCelsius'],
                'location' => $weather['location'],
                'main' => $weather['weatherMain'],
                'description' => $weather['weatherDescription'],
                'airQualityAqi' => $weather['airQualityAqi'],
            ],
            'strideTip' => $this->strideTipForWeather(
                $weather['tempCelsius'],
                $weather['weatherMain'],
                $weather['airQualityAqi'],
                $stepsToday,
                $stepGoal,
            ),
        ]);
    }

    /**
     * Upserts the user's current hour step count for chart accuracy.
     * Mobile can call this whenever it has a new step reading.
     */
    public function logHourly(Request $request): JsonResponse
    {
        $user = auth()->user();

        if (! Schema::hasTable('hourly_step_logs')) {
            return response()->json(['status' => 'skipped'], 200);
        }

        $data = $request->validate([
            'step_count' => ['required', 'integer', 'min:0', 'max:200000'],
            'log_date' => ['nullable', 'date'],
            'hour' => ['nullable', 'integer', 'min:0', 'max:23'],
        ]);

        $logDate = isset($data['log_date']) ? Carbon::parse($data['log_date'])->toDateString() : now()->toDateString();
        $hour = isset($data['hour']) ? (int) $data['hour'] : (int) now()->format('G');

        // We store the max observed steps for the hour to avoid decreasing curves.
        $existing = HourlyStepLog::query()
            ->where('user_id', $user->id)
            ->where('log_date', $logDate)
            ->where('hour', $hour)
            ->first();

        $next = (int) $data['step_count'];
        if ($existing) {
            $existing->step_count = max((int) $existing->step_count, $next);
            $existing->save();
        } else {
            HourlyStepLog::create([
                'user_id' => $user->id,
                'log_date' => $logDate,
                'hour' => $hour,
                'step_count' => $next,
            ]);
        }

        $this->upsertDailyStepLog($user->id, $logDate, $next);

        return response()->json(['status' => 'success'], 201);
    }

    private function upsertDailyStepLog(int $userId, string $logDate, int $stepCount): void
    {
        $existing = DailyStepLog::query()
            ->where('user_id', $userId)
            ->whereDate('log_date', $logDate)
            ->first();

        if ($existing) {
            $existing->step_count = max((int) $existing->step_count, $stepCount);
            $existing->save();
        } else {
            DailyStepLog::create([
                'user_id' => $userId,
                'log_date' => $logDate,
                'step_count' => $stepCount,
            ]);
        }

        LeaderboardCache::forgetCurrent();
    }

    /**
     * @param  iterable<int, object{hour: mixed, step_count: mixed}>  $hourlyRows
     * @return array<int, int>
     */
    private function hourlyBucketsFromCumulativeLogs(iterable $hourlyRows): array
    {
        $byHour = [];
        foreach ($hourlyRows as $row) {
            $h = (int) $row->hour;
            $v = (int) $row->step_count;
            $byHour[$h] = max($byHour[$h] ?? 0, $v);
        }

        $buckets = array_fill(0, 8, 0);
        for ($bucket = 0; $bucket < 8; $bucket++) {
            $startHour = $bucket * 3;

            $maxBefore = 0;
            for ($h = 0; $h < $startHour; $h++) {
                if (isset($byHour[$h])) {
                    $maxBefore = max($maxBefore, $byHour[$h]);
                }
            }

            $peakInBucket = $maxBefore;
            for ($h = $startHour; $h <= $startHour + 2; $h++) {
                if (isset($byHour[$h])) {
                    $peakInBucket = max($peakInBucket, $byHour[$h]);
                }
            }

            $buckets[$bucket] = max(0, $peakInBucket - $maxBefore);
        }

        return $buckets;
    }

    private function strideTipForWeather(
        float $tempCelsius,
        ?string $weatherMain,
        ?int $airQualityAqi,
        int $stepsToday,
        int $stepGoal,
    ): string {
        $main = strtolower(trim((string) ($weatherMain ?? '')));
        $goal = max(1, $stepGoal);
        $pct = (int) round(($stepsToday / $goal) * 100);

        if ($main === 'thunderstorm') {
            return 'Storm advisory — stay indoors. Indoor steps still count toward your goal.';
        }
        if (in_array($main, ['rain', 'drizzle'], true)) {
            return 'Rain today — skip the outdoor walk if you prefer. Pace at home or use stairs; steps still count.';
        }
        if ($airQualityAqi !== null && $airQualityAqi >= 4) {
            return 'Poor air quality — keep workouts indoors and at an easy pace.';
        }
        if ($tempCelsius >= 32.0) {
            return "High heat ({$tempCelsius}°C) — shorter outings, shade breaks, and lower intensity.";
        }
        if ($pct < 45) {
            return "You are at {$pct}% of your step goal — a 12-minute indoor or outdoor walk can help.";
        }

        return 'Conditions look workable — move at a pace that feels comfortable today.';
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
