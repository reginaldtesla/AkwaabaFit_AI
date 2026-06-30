<?php

use App\Http\Controllers\AccountabilityController;
use App\Http\Controllers\ActivityController;
use App\Http\Controllers\AdvisorConsultationApiController;
use App\Http\Controllers\AppVersionController;
use App\Http\Controllers\BroadcastingClientConfigController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ConsultationController;
use App\Http\Controllers\ConsultationMessageController;
use App\Http\Controllers\DailyStepLogController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\DeviceTokenController;
use App\Http\Controllers\DietitianApplicationApiController;
use App\Http\Controllers\DietitianController;
use App\Http\Controllers\HealthOptionsController;
use App\Http\Controllers\HydrationController;
use App\Http\Controllers\NutritionController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
use App\Models\Consultation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\URL;

// Public Routes
Route::get('/app/version', [AppVersionController::class, 'show']);
Route::get('/health/options', [HealthOptionsController::class, 'index']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/forgot-password', [PasswordResetController::class, 'forgot']);
Route::post('/reset-password', [PasswordResetController::class, 'reset']);

// Protected Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::post('/logout', [AuthController::class, 'logout']);

    // Profile Routes
    Route::get('/profile', [ProfileController::class, 'show']);
    Route::patch('/profile', [ProfileController::class, 'update']);
    Route::post('/profile/avatar', [ProfileController::class, 'uploadAvatar']);

    // Dashboard Routes
    Route::get('/dashboard', [DashboardController::class, 'show']);

    // Fitness Routes
    Route::post('/steps/sync', [DailyStepLogController::class, 'sync']);
    Route::get('/leaderboard/daily', [DailyStepLogController::class, 'dailyLeaderboard']);
    Route::get('/leaderboard/daily/me', [DailyStepLogController::class, 'dailyMe']);
    Route::get('/activity/today', [ActivityController::class, 'today']);
    Route::post('/activity/hourly/log', [ActivityController::class, 'logHourly']);

    // Consultation Routes
    Route::post('/consultations/book', [ConsultationController::class, 'book']);
    Route::get('/consultations/my', function (Request $request) {
        $user = $request->user();
        $items = Consultation::query()
            ->where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->limit(50)
            ->get(['id', 'dietician_name', 'advisor_user_id', 'scheduled_time', 'session_expires_at'])
            ->map(fn ($c) => [
                'id' => $c->id,
                'dietician_name' => $c->dietician_name,
                'advisor_user_id' => $c->advisor_user_id,
                'scheduled_time' => optional($c->scheduled_time)->toIso8601String(),
                'session_expires_at' => optional($c->session_expires_at)->toIso8601String(),
            ])
            ->values();

        return response()->json(['status' => 'success', 'consultations' => $items]);
    });
    Route::get('/broadcasting/client-config', [BroadcastingClientConfigController::class, 'show']);

    Route::middleware('throttle:advice-chat-get')->group(function () {
        Route::get('/consultations/{consultation}/messages', [ConsultationMessageController::class, 'index']);
    });
    Route::middleware('throttle:advice-chat-delta')->group(function () {
        Route::get('/consultations/{consultation}/messages/delta', [ConsultationMessageController::class, 'delta']);
    });
    Route::middleware('throttle:advice-chat-post')->group(function () {
        Route::post('/consultations/{consultation}/messages', [ConsultationMessageController::class, 'store']);
    });
    Route::middleware('throttle:advice-typing')->group(function () {
        Route::post('/consultations/{consultation}/typing', [ConsultationMessageController::class, 'typing']);
    });

    // Device tokens (push notifications)
    Route::post('/devices/token', [DeviceTokenController::class, 'register']);
    Route::delete('/devices/token', [DeviceTokenController::class, 'unregister']);

    // Dietitians
    Route::get('/dietitians', [DietitianController::class, 'index']);
    Route::get('/dietetics/application', [DietitianApplicationApiController::class, 'show']);
    Route::post('/dietetics/application', [DietitianApplicationApiController::class, 'store']);

    // Advisor in-app chat endpoints
    Route::middleware('advisor')->prefix('advisor')->group(function () {
        Route::get('/consultations', [AdvisorConsultationApiController::class, 'myConsultations']);
        Route::middleware('throttle:advice-chat-get')->group(function () {
            Route::get('/consultations/{consultation}/messages', [AdvisorConsultationApiController::class, 'messages']);
        });
        Route::middleware('throttle:advice-chat-delta')->group(function () {
            Route::get('/consultations/{consultation}/messages/delta', [AdvisorConsultationApiController::class, 'delta']);
        });
        Route::middleware('throttle:advice-chat-post')->group(function () {
            Route::post('/consultations/{consultation}/messages', [AdvisorConsultationApiController::class, 'send']);
        });
        Route::middleware('throttle:advice-typing')->group(function () {
            Route::post('/consultations/{consultation}/typing', [AdvisorConsultationApiController::class, 'typing']);
        });
    });

    // Dietetics doctor application portal link (signed, short-lived)
    Route::post('/dietetics/apply/link', function (Request $request) {
        $user = $request->user();
        // Generate a signed *path* and then attach the caller's host.
        // This avoids broken links when APP_URL is set to localhost in dev.
        $path = URL::temporarySignedRoute(
            'dietetics.apply',
            now()->addMinutes(30),
            ['user' => $user->id],
            absolute: false,
        );
        $url = rtrim($request->getSchemeAndHttpHost(), '/').$path;

        return response()->json([
            'status' => 'success',
            'url' => $url,
        ]);
    });

    // Nutrition Routes
    Route::post('/nutrition/log', [NutritionController::class, 'log']);
    Route::post('/nutrition/advice/meal', [NutritionController::class, 'mealAdvice']);
    Route::post('/nutrition/scan', [NutritionController::class, 'scan']);
    Route::get('/nutrition/history', [NutritionController::class, 'history']);
    Route::get('/nutrition/foods/search', [NutritionController::class, 'searchFoods']);
    Route::get('/nutrition/recent', [NutritionController::class, 'recentMeals']);
    Route::get('/nutrition/food', [NutritionController::class, 'food']);
    Route::get('/nutrition/foods', [NutritionController::class, 'foods']);

    Route::get('/hydration/today', [HydrationController::class, 'today']);
    Route::post('/hydration/log', [HydrationController::class, 'log']);

    Route::get('/accountability', [AccountabilityController::class, 'show']);
    Route::post('/accountability/link', [AccountabilityController::class, 'link']);
    Route::delete('/accountability/partner', [AccountabilityController::class, 'unlink']);
});
