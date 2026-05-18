<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        RateLimiter::for('advice-chat-post', function (Request $request) {
            return Limit::perMinute(45)->by((string) ($request->user()?->id ?? $request->ip()));
        });

        RateLimiter::for('advice-chat-get', function (Request $request) {
            return Limit::perMinute(180)->by((string) ($request->user()?->id ?? $request->ip()));
        });

        RateLimiter::for('advice-typing', function (Request $request) {
            return Limit::perMinute(90)->by((string) ($request->user()?->id ?? $request->ip()));
        });

        RateLimiter::for('advice-chat-delta', function (Request $request) {
            return Limit::perMinute(240)->by((string) ($request->user()?->id ?? $request->ip()));
        });

        // Windows/local PHP often lacks a root CA bundle, causing Guzzle cURL error 60
        // ("unable to get local issuer certificate"). Ship mozilla certs at storage/cacert.pem.
        $bundle = storage_path('cacert.pem');
        if (is_readable($bundle)) {
            Http::globalOptions(['verify' => $bundle]);
        }
    }
}
