<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Jobs\SendAdminAnnouncementJob;
use App\Models\AdminAnnouncement;
use App\Models\DeviceToken;
use App\Services\FcmPushService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class BroadcastController extends Controller
{
    public function create(FcmPushService $fcm): View
    {
        $recent = collect();
        $deviceTokenCount = 0;
        $schemaReady = true;

        try {
            $recent = AdminAnnouncement::query()->latest('id')->limit(12)->get();
            $deviceTokenCount = DeviceToken::query()->count();
        } catch (\Throwable $e) {
            $schemaReady = false;
            report($e);
        }

        return view('admin.broadcast', [
            'fcmConfigured' => $fcm->isConfigured(),
            'recent' => $recent,
            'deviceTokenCount' => $deviceTokenCount,
            'schemaReady' => $schemaReady,
            'generatedAt' => now(),
        ]);
    }

    public function store(Request $request, FcmPushService $fcm): RedirectResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'min:3', 'max:120'],
            'body' => ['required', 'string', 'min:5', 'max:500'],
        ]);

        $announcement = AdminAnnouncement::create([
            'title' => trim($data['title']),
            'body' => trim($data['body']),
            'sent_at' => now(),
        ]);

        // Sync path works immediately for apps that poll.
        // Push runs when FCM credentials + device tokens exist.
        SendAdminAnnouncementJob::dispatchSync($announcement->id);

        $message = 'Announcement saved. Users will see it in the app notification inbox when they sync.';
        if ($fcm->isConfigured()) {
            $announcement->refresh();
            $message = "Announcement sent. Push attempted: {$announcement->push_attempted}, delivered: {$announcement->push_succeeded}.";
        } else {
            $message .= ' Configure FIREBASE_CREDENTIALS to also push to phone trays while the app is closed.';
        }

        return redirect()
            ->route('admin.broadcast')
            ->with('status', $message);
    }
}
