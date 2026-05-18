<?php

namespace App\Http\Controllers;

use App\Http\Requests\SyncStepsRequest;
use App\Models\DailyStepLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class DailyStepLogController extends Controller
{
    private function cacheKeyForDate(string $date): string
    {
        return 'daily_leaderboard:'.$date;
    }

    private function todayCacheKey(): string
    {
        return 'daily_leaderboard:'.now()->toDateString();
    }

    /**
     * Sync the user's step count for today.
     */
    public function sync(SyncStepsRequest $request): JsonResponse
    {
        $logDate = now()->toDateString();
        if ($request->filled('log_date')) {
            try {
                $logDate = Carbon::parse((string) $request->log_date)->toDateString();
            } catch (\Throwable) {
                $logDate = now()->toDateString();
            }
        }

        $log = DailyStepLog::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'log_date' => $logDate,
            ],
            [
                'step_count' => $request->step_count,
            ]
        );

        // Next viewer refreshes the cached snapshot (max once per TTL).
        Cache::forget($this->cacheKeyForDate($logDate));

        return response()->json([
            'status' => 'success',
            'message' => 'Steps synced successfully',
            'data' => $log,
        ]);
    }

    /**
     * Get the daily leaderboard.
     * Results are cached for 5 minutes (300 seconds).
     */
    public function dailyLeaderboard(Request $request): JsonResponse
    {
        $date = (string) $request->query('date', now()->toDateString());
        try {
            $date = Carbon::parse($date)->toDateString();
        } catch (\Throwable) {
            $date = now()->toDateString();
        }

        $leaderboard = Cache::remember($this->cacheKeyForDate($date), 300, function () use ($date) {
            // One row per user per date (unique constraint), so no SUM() needed.
            return User::query()
                ->join('daily_step_logs', 'users.id', '=', 'daily_step_logs.user_id')
                ->where('users.is_public_on_leaderboard', true)
                ->whereDate('daily_step_logs.log_date', $date)
                ->orderByDesc('daily_step_logs.step_count')
                ->orderBy('users.id')
                ->limit(50)
                ->get([
                    'users.id',
                    'users.name',
                    'users.avatar_url',
                    DB::raw("'Accra' as location"),
                    DB::raw('daily_step_logs.step_count as total_steps'),
                ]);
        });

        return response()->json([
            'status' => 'success',
            'date' => $date,
            'data' => $leaderboard,
        ]);
    }

    /**
     * Lightweight "my rank" endpoint so the user always knows where they stand.
     * Does NOT require scanning/sorting the full dataset.
     */
    public function dailyMe(): JsonResponse
    {
        $user = auth()->user();
        $today = now()->toDateString();

        $optedIn = (bool) ($user->is_public_on_leaderboard ?? false);

        $stepsToday = (int) DailyStepLog::query()
            ->where('user_id', $user->id)
            ->whereDate('log_date', $today)
            ->value('step_count') ?? 0;

        if (! $optedIn) {
            return response()->json([
                'status' => 'success',
                'optedIn' => false,
                'user' => [
                    'id' => (string) $user->id,
                    'name' => (string) ($user->name ?? ''),
                    'avatar_url' => $user->avatar_url,
                    'location' => 'Accra',
                ],
                'stepsToday' => $stepsToday,
                'rank' => null,
                'totalUsers' => null,
            ]);
        }

        $base = DailyStepLog::query()
            ->join('users', 'users.id', '=', 'daily_step_logs.user_id')
            ->whereDate('daily_step_logs.log_date', $today)
            ->where('users.is_public_on_leaderboard', true);

        $totalUsers = (int) (clone $base)
            ->distinct('daily_step_logs.user_id')
            ->count('daily_step_logs.user_id');

        // Rank = count of users strictly above me + 1 (ties share the same rank).
        $above = (int) (clone $base)
            ->where('daily_step_logs.step_count', '>', $stepsToday)
            ->count();

        return response()->json([
            'status' => 'success',
            'optedIn' => true,
            'user' => [
                'id' => (string) $user->id,
                'name' => (string) ($user->name ?? ''),
                'avatar_url' => $user->avatar_url,
                'location' => 'Accra',
            ],
            'stepsToday' => $stepsToday,
            'rank' => $above + 1,
            'totalUsers' => $totalUsers,
        ]);
    }
}
