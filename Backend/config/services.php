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
    | OpenWeatherMap (dashboard weather + air quality via DashboardController).
    */
    'openweather' => [
        'key' => env('OPENWEATHER_API_KEY'),
        'default_lat' => env('OPENWEATHER_DEFAULT_LAT', 5.6037),
        'default_lon' => env('OPENWEATHER_DEFAULT_LON', -0.1870),
        'default_label' => env('OPENWEATHER_DEFAULT_LABEL', 'Accra, GH'),
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
    | Paystack (consultations / advice sessions)
    */
    'paystack' => [
        'secret_key' => env('PAYSTACK_SECRET_KEY'),
        'public_key' => env('PAYSTACK_PUBLIC_KEY'),
        'currency' => env('PAYSTACK_CURRENCY', 'GHS'),
        'ask_now_amount' => (int) env('PAYSTACK_ASK_NOW_AMOUNT', 5000), // in pesewas
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
        'gemini_api_key' => env('GEMINI_API_KEY'),
        'gemini_model' => env('FOOD_SCAN_GEMINI_MODEL', 'gemini-2.5-flash'),
    ],

];
