<?php

use App\Http\Controllers\AiController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ConsultationController;
use App\Http\Controllers\DailyStepLogController;
use App\Http\Controllers\ProfileController;
use App\Http\Controllers\PaymentController;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

// Public Routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Webhooks
Route::post('/webhook/paystack', [PaymentController::class, 'handleWebhook']);

// Protected Routes
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::post('/logout', [AuthController::class, 'logout']);

    // Profile Routes
    Route::patch('/profile', [ProfileController::class, 'update']);

    // Fitness Routes
    Route::post('/steps/sync', [DailyStepLogController::class, 'sync']);
    Route::get('/leaderboard/daily', [DailyStepLogController::class, 'dailyLeaderboard']);

    // Consultation Routes
    Route::post('/consultations/book', [ConsultationController::class, 'book']);

    // AI Routes
    Route::post('/ai/mock-scan', [AiController::class, 'mockScan']);
});
