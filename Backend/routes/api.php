<?php

use App\Http\Controllers\AccountabilityController;
use App\Http\Controllers\ActivityController;
use App\Http\Controllers\AppVersionController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\DailyStepLogController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\HealthOptionsController;
use App\Http\Controllers\HydrationController;
use App\Http\Controllers\NutritionController;
use App\Http\Controllers\PasswordResetController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\SafetyController;
use App\Http\Middleware\RecordUserLastSeen;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public Routes
Route::get('/app/version', [AppVersionController::class, 'show']);
Route::get('/health/options', [HealthOptionsController::class, 'index']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/auth/google', [AuthController::class, 'google']);
Route::post('/forgot-password', [PasswordResetController::class, 'forgot']);
Route::post('/reset-password', [PasswordResetController::class, 'reset']);

// Protected Routes
Route::middleware(['auth:sanctum', RecordUserLastSeen::class])->group(function () {
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

    // Nutrition Routes
    Route::post('/nutrition/log', [NutritionController::class, 'log']);
    Route::post('/nutrition/advice/meal', [NutritionController::class, 'mealAdvice']);
    Route::post('/nutrition/advice/ask', [NutritionController::class, 'askAdvice']);
    Route::post('/nutrition/scan', [NutritionController::class, 'scan']);
    Route::get('/nutrition/history', [NutritionController::class, 'history']);
    Route::get('/nutrition/foods/search', [NutritionController::class, 'searchFoods']);
    Route::get('/nutrition/recent', [NutritionController::class, 'recentMeals']);
    Route::get('/nutrition/food', [NutritionController::class, 'food']);
    Route::get('/nutrition/foods', [NutritionController::class, 'foods']);

    Route::get('/hydration/today', [HydrationController::class, 'today']);
    Route::post('/hydration/log', [HydrationController::class, 'log']);

    Route::get('/safety/health-tips', [SafetyController::class, 'healthTips']);

    Route::get('/accountability', [AccountabilityController::class, 'show']);
    Route::post('/accountability/link', [AccountabilityController::class, 'link']);
    Route::delete('/accountability/partner', [AccountabilityController::class, 'unlink']);
});
