<?php

namespace App\Services;

use App\Models\Consultation;
use App\Models\ConsultationMessage;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;

class ConsultationChatService
{
    public function markPeerMessagesRead(Consultation $consultation, string $viewerSenderRole): void
    {
        $peerSender = $viewerSenderRole === 'user' ? 'professional' : 'user';

        ConsultationMessage::query()
            ->where('consultation_id', $consultation->id)
            ->where('sender', $peerSender)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);
    }

    /**
     * @return array{messages: Collection<int, ConsultationMessage>, has_more: bool, oldest_id: int|null, newest_id: int|null}
     */
    public function sliceMessages(Consultation $consultation, ?int $beforeId, int $limit): array
    {
        $limit = min(max($limit, 1), 200);

        $query = ConsultationMessage::query()
            ->where('consultation_id', $consultation->id);

        if ($beforeId !== null) {
            $query->where('id', '<', $beforeId);
        }

        $rows = $query->orderByDesc('id')->limit($limit + 1)->get();
        $hasMore = $rows->count() > $limit;
        $messages = $rows->take($limit)->sortBy('id')->values();

        $oldestId = $messages->isEmpty() ? null : (int) $messages->min('id');
        $newestId = $messages->isEmpty() ? null : (int) $messages->max('id');

        return [
            'messages' => $messages,
            'has_more' => $hasMore,
            'oldest_id' => $oldestId,
            'newest_id' => $newestId,
        ];
    }

    public function resolveLimit(Request $request): int
    {
        $raw = $request->query('limit', 100);

        return is_numeric($raw) ? (int) $raw : 100;
    }

    public function resolveBeforeId(Request $request): ?int
    {
        $raw = $request->query('before_id');
        if ($raw === null || $raw === '') {
            return null;
        }

        return is_numeric($raw) ? (int) $raw : null;
    }

    public function touchTyping(int $consultationId, string $senderRole): void
    {
        if (! in_array($senderRole, ['user', 'professional'], true)) {
            return;
        }

        Cache::put("cm:{$consultationId}:typing:{$senderRole}", true, 4);
    }

    public function peerIsTyping(int $consultationId, string $viewerSenderRole): bool
    {
        $peer = $viewerSenderRole === 'user' ? 'professional' : 'user';

        return (bool) Cache::get("cm:{$consultationId}:typing:{$peer}");
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function formatMessages(Collection $messages): array
    {
        return $messages
            ->map(fn (ConsultationMessage $m) => [
                'id' => $m->id,
                'sender' => $m->sender,
                'body' => $m->body,
                'created_at' => $m->created_at?->toIso8601String(),
                'read_at' => $m->read_at?->toIso8601String(),
                'attachments' => $m->attachments ?? [],
            ])
            ->values()
            ->all();
    }
}
