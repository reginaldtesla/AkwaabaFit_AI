<?php

namespace App\Providers;

use Illuminate\Support\Facades\Http;
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
        // Windows/local PHP often lacks a root CA bundle, causing Guzzle cURL error 60
        // ("unable to get local issuer certificate"). Ship mozilla certs at storage/cacert.pem.
        $bundle = storage_path('cacert.pem');
        if (is_readable($bundle)) {
            Http::globalOptions(['verify' => $bundle]);
        }
    }
}
