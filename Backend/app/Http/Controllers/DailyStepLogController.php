<?php

namespace App\Http\Controllers;

use App\Http\Requests\SyncStepsRequest;
use App\Models\DailyStepLog;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class DailyStepLogController extends Controller
{
    /**
     * Sync the user's step count for today.
     */
    public function sync(SyncStepsRequest $request): JsonResponse
    {
        $log = DailyStepLog::updateOrCreate(
            [
                'user_id' => $request->user()->id,
                'log_date' => now()->toDateString(),
            ],
            [
                'step_count' => $request->step_count,
            ]
        );

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
    public function dailyLeaderboard(): JsonResponse
    {
        $leaderboard = Cache::remember('daily_leaderboard', 300, function () {
            return User::query()
                ->join('daily_step_logs', 'users.id', '=', 'daily_step_logs.user_id')
                ->select('users.id', 'users.name', DB::raw('SUM(daily_step_logs.step_count) as total_steps'))
                ->whereDate('daily_step_logs.log_date', now()->toDateString())
                ->where('users.is_public_on_leaderboard', true)
                ->groupBy('users.id', 'users.name')
                ->orderByDesc('total_steps')
                ->limit(50)
                ->get();
        });

        return response()->json([
            'status' => 'success',
            'data' => $leaderboard,
        ]);
    }
}
