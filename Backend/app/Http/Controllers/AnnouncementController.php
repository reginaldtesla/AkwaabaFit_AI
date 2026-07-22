<?php

namespace App\Http\Controllers;

use App\Models\AdminAnnouncement;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AnnouncementController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'after_id' => ['nullable', 'integer', 'min:0'],
        ]);

        $afterId = (int) ($data['after_id'] ?? 0);

        $rows = AdminAnnouncement::query()
            ->whereNotNull('sent_at')
            ->when($afterId > 0, fn ($q) => $q->where('id', '>', $afterId))
            ->orderBy('id')
            ->limit(50)
            ->get(['id', 'title', 'body', 'sent_at']);

        return response()->json([
            'status' => 'success',
            'announcements' => $rows->map(fn (AdminAnnouncement $row) => [
                'id' => $row->id,
                'title' => $row->title,
                'body' => $row->body,
                'sent_at' => optional($row->sent_at)?->toIso8601String(),
            ])->values(),
        ]);
    }
}
