<?php

use App\Http\Controllers\AdminAdviceChatController;
use App\Http\Controllers\AdminStaffAuthController;
use App\Http\Controllers\AdvisorAdviceChatController;
use App\Http\Controllers\AdvisorAuthController;
use App\Http\Controllers\DieteticsReviewUnlockController;
use App\Http\Controllers\DietitianApplicationAdminController;
use App\Http\Controllers\DietitianApplicationPortalController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Paystack callback URL (used after checkout). The app verifies payment separately.
Route::get('/paystack/return', function () {
    $reference = request()->query('reference') ?? request()->query('trxref');
    $scheme = (string) config('mobile_app.deep_link_scheme', 'akwaabafit');
    $deepLink = $reference
        ? $scheme.'://payment-return?reference='.urlencode((string) $reference)
        : null;

    return view('paystack.return', [
        'reference' => $reference,
        'deep_link' => $deepLink,
    ]);
});

// Public portal accessed from mobile via signed link.
// Use a relative signature so local/LAN hosts work in dev.
Route::middleware('signed:relative')->group(function () {
    Route::get('/dietetics/apply', [DietitianApplicationPortalController::class, 'show'])
        ->name('dietetics.apply');
    Route::post('/dietetics/apply', [DietitianApplicationPortalController::class, 'submit'])
        ->name('dietetics.apply.submit');
});

Route::get('/admin/login', [AdminStaffAuthController::class, 'showLogin'])->name('staff.admin.login');
Route::post('/admin/login', [AdminStaffAuthController::class, 'login'])->name('staff.admin.login.submit');
Route::post('/admin/logout', [AdminStaffAuthController::class, 'logout'])->middleware('auth')->name('staff.admin.logout');

// Review portal: unlock once per browser (session), or pass ?key= / X-Review-Key on each request.
Route::prefix('admin/dietetics')->group(function () {
    Route::get('/unlock', [DieteticsReviewUnlockController::class, 'show'])->name('dietetics.review.unlock');
    Route::post('/unlock', [DieteticsReviewUnlockController::class, 'unlock'])->name('dietetics.review.unlock.submit');
    Route::post('/lock', [DieteticsReviewUnlockController::class, 'lock'])->name('dietetics.review.lock');
});

// Developer/admin review portal (staff admin session and/or legacy shared key).
Route::middleware('staff.or_review')->prefix('admin/dietetics')->group(function () {
    Route::get('/applications', [DietitianApplicationAdminController::class, 'index'])->name('dietetics.review.applications');
    Route::get('/certificates/{application}', [DietitianApplicationAdminController::class, 'downloadCertificate'])
        ->name('dietetics.review.certificate');
    Route::get('/documents/{application}/{type}', [DietitianApplicationAdminController::class, 'downloadDocument'])
        ->whereIn('type', ['certificate', 'ghana_card', 'cv', 'profile_photo'])
        ->name('dietetics.review.document');
    Route::post('/applications/{application}/approve', [DietitianApplicationAdminController::class, 'approve']);
    Route::post('/applications/{application}/reject', [DietitianApplicationAdminController::class, 'reject']);
});

// Developer/admin nutrition advice chat inbox (staff admin and/or legacy shared key).
Route::middleware('staff.or_review')->prefix('admin/advice')->group(function () {
    Route::get('/', [AdminAdviceChatController::class, 'index']);
    Route::get('/{consultation}', [AdminAdviceChatController::class, 'show']);
    Route::post('/{consultation}/messages', [AdminAdviceChatController::class, 'send']);
});

// Advisor portal (session login + advisor-only access).
Route::get('/advisor/login', [AdvisorAuthController::class, 'showLogin'])->name('advisor.login');
Route::post('/advisor/login', [AdvisorAuthController::class, 'login'])->name('advisor.login.submit');
Route::post('/advisor/logout', [AdvisorAuthController::class, 'logout'])->name('advisor.logout');

Route::middleware(['auth', 'advisor'])->prefix('advisor')->group(function () {
    Route::get('/consultations', [AdvisorAdviceChatController::class, 'index'])->name('advisor.consultations.index');
    Route::get('/consultations/{consultation}', [AdvisorAdviceChatController::class, 'show'])->name('advisor.consultations.show');
    Route::post('/consultations/{consultation}/messages', [AdvisorAdviceChatController::class, 'send'])->name('advisor.consultations.send');
});
