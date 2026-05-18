<?php

namespace App\Services;

use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class ConsultationMessageModerator
{
    public function assertBodyAllowed(string $body): void
    {
        if (str_contains($body, "\0")) {
            throw ValidationException::withMessages([
                'body' => ['Invalid characters in message.'],
            ]);
        }

        foreach (config('consultation_messages.blocked_substrings', []) as $fragment) {
            $fragment = (string) $fragment;
            if ($fragment !== '' && stripos($body, $fragment) !== false) {
                throw ValidationException::withMessages([
                    'body' => ['This message cannot be sent (moderation).'],
                ]);
            }
        }
    }

    /**
     * @param  array<int, string>|null  $urls
     * @return array<int, string>
     */
    public function normalizeAttachmentUrls(?array $urls): array
    {
        if ($urls === null || $urls === []) {
            return [];
        }

        $max = (int) config('consultation_messages.max_attachments', 3);
        $urls = array_slice(array_values($urls), 0, max(0, $max));

        $validator = Validator::make(
            ['attachments' => $urls],
            [
                'attachments' => ['array', 'max:'.$max],
                'attachments.*' => ['string', 'url', 'max:500'],
            ],
        );

        if ($validator->fails()) {
            throw ValidationException::withMessages($validator->errors()->toArray());
        }

        return $validator->validated()['attachments'];
    }
}
