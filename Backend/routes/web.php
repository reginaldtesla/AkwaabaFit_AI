<?php

use Illuminate\Support\Facades\Route;

Route::view('/', 'landing')->name('landing');

require __DIR__.'/admin.php';
