<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Public marketing site (GET /)
    |--------------------------------------------------------------------------
    */

    // Optional external URL (Drive, CDN). When empty, uses /download/akwaabafit.apk if the file exists.
    'apk_url' => env('LANDING_APK_URL'),

    // File name under storage/app/public/downloads/
    'apk_filename' => env('LANDING_APK_FILENAME', 'akwaabafit.apk'),

    // Optional absolute path override (useful in production deploys)
    'apk_storage_path' => env('LANDING_APK_PATH'),

    // Filename sent to the browser's download dialog
    'apk_download_name' => env('LANDING_APK_DOWNLOAD_NAME', 'AkwaabaFit.apk'),

    'beta_form_action' => env('LANDING_BETA_FORM_ACTION'),

    'support_email' => env('LANDING_SUPPORT_EMAIL', 'tesnet5532@gmail.com'),

    'support_email_subject' => env(
        'LANDING_SUPPORT_EMAIL_SUBJECT',
        'AkwaabaFit — Beta / support request'
    ),

    'support_email_body' => <<<'TEXT'
Hi AkwaabaFit team,

I found AkwaabaFit on your website and would like to get in touch.

My name:
My phone (optional):
What I need (APK, support, feedback, etc.):


Thank you!
TEXT,

];
