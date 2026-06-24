<?php

namespace App\Http\Controllers;

use App\Events\ConsultationMessageCreated;
use App\Jobs\SendConsultationAdvicePush;
use App\Models\Consultation;
use App\Models\ConsultationActivityLog;
use App\Models\ConsultationMessage;
use App\Services\ConsultationChatService;
use App\Services\ConsultationMessageModerator;
use App\Services\ConsultationSessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConsultationMessageController extends Controller
{
    public function __construct(
        private readonly ConsultationChatService $chat,
        private readonly ConsultationMessageModerator $moderator,
        private readonly ConsultationSessionService $sessions,
    ) {}

    private function isSessionActive(Consultation $consultation): bool
    {
        return $this->sessions->isLive($consultation);
    }

    private function sessionJson(Consultation $consultation): array
    {
        return $this->sessions->toArray($consultation);
    }

    public function index(Request $request, Consultation $consultation): JsonResponse
    {
        if ($consultation->user_id !== $request->user()->id) {
            return response()->json(['status' => 'error', 'message' => 'Forbidden'], 403);
        }

        $this->chat->markPeerMessagesRead($consultation, 'user');

        $slice = $this->chat->sliceMessages(
            $consultation,
            $this->chat->resolveBeforeId($request),
            $this->chat->resolveLimit($request),
        );

        return response()->json([
            'status' => 'success',
            'messages' => $this->chat->formatMessages($slice['messages']),
            'pagination' => [
                'has_more' => $slice['has_more'],
                'oldest_id' => $slice['oldest_id'],
                'newest_id' => $slice['newest_id'],
            ],
            'peer_typing' => $this->chat->peerIsTyping($consultation->id, 'user'),
            'session' => $this->sessionJson($consultation),
        ]);
    }

    public function delta(Request $request, Consultation $consultation): JsonResponse
    {
        if ($consultation->user_id !== $request->user()->id) {
            return response()->json(['status' => 'error', 'message' => 'Forbidden'], 403);
        }

        $afterId = max(0, (int) $request->query('after_id', 0));

        // after_id=0 is reserved for "no baseline yet" — use a full messages fetch first.
        $rows = $afterId < 1
            ? collect()
            : ConsultationMessage::query()
                ->where('consultation_id', $consultation->id)
                ->where('id', '>', $afterId)
                ->orderBy('id')
                ->limit(100)
                ->get();

        return response()->json([
            'status' => 'success',
            'messages' => $this->chat->formatMessages($rows),
            'peer_typing' => $this->chat->peerIsTyping($consultation->id, 'user'),
            'session' => $this->sessionJson($consultation),
        ]);
    }

    public function typing(Request $request, Consultation $consultation): JsonResponse
    {
        if ($consultation->user_id !== $request->user()->id) {
            return response()->json(['status' => 'error', 'message' => 'Forbidden'], 403);
        }

        if (! $this->isSessionActive($consultation)) {
            return response()->json(['status' => 'error', 'message' => 'Session inactive'], 402);
        }

        $this->chat->touchTyping($consultation->id, 'user');

        return response()->json(['status' => 'success']);
    }

    public function store(Request $request, Consultation $consultation): JsonResponse
    {
        if ($consultation->user_id !== $request->user()->id) {
            return response()->json(['status' => 'error', 'message' => 'Forbidden'], 403);
        }

        if (! $this->isSessionActive($consultation)) {
            if ($this->sessions->phase($consultation) === 'waiting') {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Session has not started yet. Please wait until your scheduled time.',
                    'session' => $this->sessionJson($consultation),
                ], 402);
            }

            return response()->json([
                'status' => 'error',
                'message' => 'Session expired.',
                'session' => $this->sessionJson($consultation),
            ], 402);
        }

        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
            'attachments' => ['sometimes', 'array'],
            'attachments.*' => ['string', 'url', 'max:500'],
        ]);

        $this->moderator->assertBodyAllowed($data['body']);
        $attachments = $this->moderator->normalizeAttachmentUrls($data['attachments'] ?? null);

        $m = ConsultationMessage::create([
            'consultation_id' => $consultation->id,
            'sender' => 'user',
            'body' => $data['body'],
            'attachments' => $attachments === [] ? null : $attachments,
        ]);

        ConsultationActivityLog::create([
            'consultation_id' => $consultation->id,
            'actor_user_id' => $request->user()->id,
            'action' => 'message_sent',
            'meta' => [
                'sender' => 'user',
                'bytes' => strlen($m->body),
                'attachment_count' => count($attachments),
            ],
        ]);

        broadcast(new ConsultationMessageCreated($m));

        if ($consultation->advisor_user_id) {
            SendConsultationAdvicePush::dispatch(
                (int) $consultation->advisor_user_id,
                'New message',
                'User: '.mb_substr($m->body, 0, 120),
                (int) $consultation->id,
            );
        }

        return response()->json([
            'status' => 'success',
            'message' => [
                'id' => $m->id,
                'sender' => $m->sender,
                'body' => $m->body,
                'created_at' => $m->created_at?->toIso8601String(),
                'read_at' => $m->read_at?->toIso8601String(),
                'attachments' => $m->attachments ?? [],
            ],
        ], 201);
    }
}
