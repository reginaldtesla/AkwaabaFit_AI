<?php

use App\Http\Controllers\ApkDownloadController;
use Illuminate\Support\Facades\Route;

Route::view('/', 'landing')->name('landing');

Route::get('/download/akwaabafit.apk', ApkDownloadController::class)
    ->name('apk.download');

require __DIR__.'/admin.php';
