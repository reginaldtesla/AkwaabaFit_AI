<?php

namespace App\Jobs;

use App\Models\DeviceToken;
use App\Services\FcmService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendConsultationAdvicePush implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    public int $timeout = 45;

    public function __construct(
        public int $recipientUserId,
        public string $title,
        public string $body,
        public int $consultationId,
    ) {}

    public function handle(FcmService $fcm): void
    {
        $tokens = DeviceToken::query()
            ->where('user_id', $this->recipientUserId)
            ->pluck('token')
            ->all();

        foreach ($tokens as $token) {
            $fcm->sendToToken($token, [
                'title' => $this->title,
                'body' => $this->body,
            ], [
                'type' => 'advice_message',
                'consultation_id' => (string) $this->consultationId,
            ]);
        }
    }
}
