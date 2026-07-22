<?php

namespace App\Jobs;

use App\Models\AdminAnnouncement;
use App\Models\DeviceToken;
use App\Services\FcmPushService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

class SendAdminAnnouncementJob implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $announcementId) {}

    public function handle(FcmPushService $fcm): void
    {
        $announcement = AdminAnnouncement::query()->find($this->announcementId);
        if ($announcement === null) {
            return;
        }

        $tokens = DeviceToken::query()->pluck('token')->all();
        $result = $fcm->sendToTokens(
            $tokens,
            $announcement->title,
            $announcement->body,
            ['announcement_id' => (string) $announcement->id],
        );

        $announcement->update([
            'push_attempted' => $result['attempted'],
            'push_succeeded' => $result['succeeded'],
            'sent_at' => $announcement->sent_at ?? now(),
        ]);
    }
}
