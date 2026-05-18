<?php

return [

    /*
    | Case-insensitive substrings that block sending a message (empty = disabled).
    */
    'blocked_substrings' => array_values(array_filter(array_map(
        'trim',
        explode(',', (string) env('CONSULTATION_MESSAGE_BLOCKLIST', ''))
    ))),

    'max_attachments' => (int) env('CONSULTATION_MAX_ATTACHMENTS', 3),

];
