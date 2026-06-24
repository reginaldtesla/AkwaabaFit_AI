<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Mobile app version checks (optional update banner)
    |--------------------------------------------------------------------------
    |
    | When the installed app version is lower than latest_version, the app
    | shows a dismissible banner linking to store_url.
    |
    */

    'android' => [
        'latest_version' => env('APP_ANDROID_LATEST_VERSION', '1.0.0'),
        'min_version' => env('APP_ANDROID_MIN_VERSION', '1.0.0'),
        'store_url' => env('APP_ANDROID_STORE_URL'),
        'message' => env('APP_ANDROID_UPDATE_MESSAGE', 'A new version of AkwaabaFit is available.'),
    ],

    'ios' => [
        'latest_version' => env('APP_IOS_LATEST_VERSION', '1.0.0'),
        'min_version' => env('APP_IOS_MIN_VERSION', '1.0.0'),
        'store_url' => env('APP_IOS_STORE_URL'),
        'message' => env('APP_IOS_UPDATE_MESSAGE', 'A new version of AkwaabaFit is available.'),
    ],

];
