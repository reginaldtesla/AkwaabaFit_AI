<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Staff admin panel (GET /admin)
    |--------------------------------------------------------------------------
    |
    | Single shared password — same pattern as TesNet Pay admin. Leave empty to
    | disable the panel (routes return 404).
    |
    */

    'password' => env('ADMIN_PASSWORD'),

    'session_key' => 'akwaaba_admin_authenticated',

];
