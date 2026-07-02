<?php

return [

  /*
  |--------------------------------------------------------------------------
  | Public marketing site (GET /)
  |--------------------------------------------------------------------------
  */

  'apk_url' => env('LANDING_APK_URL'),

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
