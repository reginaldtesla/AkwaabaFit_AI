<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    | Open-Meteo (free, no API key) — dashboard + Stride weather.
    | Mobile may pass ?lat=&lon= from GPS; otherwise defaults to Accra.
    */
    'weather' => [
        'default_lat' => (float) env('WEATHER_DEFAULT_LAT', 5.6037),
        'default_lon' => (float) env('WEATHER_DEFAULT_LON', -0.1870),
        'default_label' => env('WEATHER_DEFAULT_LABEL', 'Accra, GH'),
        'cache_minutes' => (int) env('WEATHER_CACHE_MINUTES', 15),
    ],

    /*
    | Dietetics review portal (developer/admin approval).
    | Provide a shared secret key to access /admin/dietetics pages.
    */
    'dietetics_review' => [
        'key' => env('DIETETICS_REVIEW_KEY'),
        'allow_shared_key' => filter_var(env('DIETETICS_ALLOW_SHARED_KEY', true), FILTER_VALIDATE_BOOL),
    ],

    /*
    | Firebase Cloud Messaging (push notifications)
    */
    'fcm' => [
        'project_id' => env('FCM_PROJECT_ID'),
        'service_account_json' => env('FCM_SERVICE_ACCOUNT_JSON'),
    ],

    /*
    | Hybrid food scan: Ghana ConvNeXt (HF) + Gemini Flash fallback.
    */
    'food_scan' => [
        'timeout' => (int) env('FOOD_SCAN_TIMEOUT', 90),
        'huggingface_token' => env('HUGGINGFACE_API_TOKEN'),
        'huggingface_model' => env(
            'FOOD_SCAN_HF_MODEL',
            'Kennethdot/convnext_finetuned_ghanaian_food'
        ),
        'hf_confidence_threshold' => (float) env('FOOD_SCAN_HF_THRESHOLD', 0.65),
        /** Detections below this are treated as "not food" (reduces false positives). */
        'min_detection_confidence' => (float) env('FOOD_SCAN_MIN_CONFIDENCE', 0.30),
        'gemini_api_key' => env('GEMINI_API_KEY'),
        'gemini_model' => env('FOOD_SCAN_GEMINI_MODEL', 'gemini-2.5-flash'),
    ],

    /*
    | Virtual dietitian (Gemini + rule fallback). Reuses GEMINI_API_KEY from food_scan.
    */
    'dietitian' => [
        'gemini_timeout' => (int) env('DIETITIAN_GEMINI_TIMEOUT', 45),
    ],

];
