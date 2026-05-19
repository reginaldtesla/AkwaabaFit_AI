<?php

namespace App\Http\Controllers;

use App\Models\Consultation;
use App\Models\User;
use App\Services\ConsultationSessionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class ConsultationPaymentController extends Controller
{
    public function initiate(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'dietician_name' => ['required', 'string', 'max:255'],
            'advisor_user_id' => ['required', 'integer', 'min:1'],
            'scheduled_time' => ['nullable', 'date'],
            'type' => ['required', 'string', 'in:ask_now,schedule'],
            'consultation_id' => ['nullable', 'integer', 'min:1'],
        ]);

        $advisor = User::query()
            ->where('id', (int) $data['advisor_user_id'])
            ->where('is_nutrition_advisor', true)
            ->first();
        if (! $advisor) {
            return response()->json(['status' => 'error', 'message' => 'Advisor not found.'], 404);
        }

        $currency = (string) config('services.paystack.currency', 'GHS');
        $amount = (int) config('services.paystack.ask_now_amount', 5000); // pesewas

        // For schedule we can reuse ask_now_amount for now, or later compute from hourlyRate.
        // Keeping it server-controlled prevents client tampering.

        $reference = 'AKW-'.Str::upper(Str::random(10));

        $consultationId = $data['consultation_id'] ?? null;
        if ($consultationId) {
            $consultation = Consultation::query()
                ->where('id', $consultationId)
                ->where('user_id', $user->id)
                ->first();
            if (! $consultation) {
                return response()->json(['status' => 'error', 'message' => 'Consultation not found.'], 404);
            }
            // Extend/renew the same thread: keep history, renew payment reference and scheduled time.
            $consultation->update([
                'dietician_name' => $advisor->name,
                'scheduled_time' => $data['scheduled_time'] ?? $consultation->scheduled_time,
                'payment_status' => 'pending',
                'paystack_reference' => $reference,
                'amount' => $amount,
                'currency' => $currency,
                'advisor_user_id' => $advisor->id,
            ]);
        } else {
            $consultation = Consultation::create([
                'user_id' => $user->id,
                'dietician_name' => $advisor->name,
                'scheduled_time' => $data['scheduled_time'] ?? null,
                'payment_status' => 'pending',
                'paystack_reference' => $reference,
                'amount' => $amount,
                'currency' => $currency,
                'advisor_user_id' => $advisor->id,
            ]);
        }

        $secret = (string) config('services.paystack.secret_key', '');
        if ($secret === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Paystack is not configured.',
            ], 503);
        }

        $payload = [
            'email' => $user->email,
            'amount' => $amount,
            'currency' => $currency,
            'reference' => $reference,
            'callback_url' => rtrim($request->getSchemeAndHttpHost(), '/').'/paystack/return?reference='.urlencode($reference),
            'metadata' => [
                'consultation_id' => $consultation->id,
                'type' => $data['type'],
            ],
        ];

        $resp = Http::withToken($secret)->post('https://api.paystack.co/transaction/initialize', $payload);
        if (! $resp->ok()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to initialize payment.',
                'details' => $resp->json(),
            ], 502);
        }

        $json = $resp->json();
        $authUrl = $json['data']['authorization_url'] ?? null;
        if (! is_string($authUrl) || $authUrl === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Paystack did not return a checkout URL.',
            ], 502);
        }

        return response()->json([
            'status' => 'success',
            'consultation_id' => $consultation->id,
            'reference' => $reference,
            'authorization_url' => $authUrl,
            'amount' => $amount,
            'currency' => $currency,
        ]);
    }

    public function verify(Request $request): JsonResponse
    {
        $data = $request->validate([
            'reference' => ['required', 'string', 'max:255'],
        ]);

        $secret = (string) config('services.paystack.secret_key', '');
        if ($secret === '') {
            return response()->json([
                'status' => 'error',
                'message' => 'Paystack is not configured.',
            ], 503);
        }

        $resp = Http::withToken($secret)->get(
            'https://api.paystack.co/transaction/verify/'.urlencode($data['reference'])
        );
        if (! $resp->ok()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to verify payment.',
                'details' => $resp->json(),
            ], 502);
        }

        $json = $resp->json();
        $status = $json['data']['status'] ?? null;

        /** @var Consultation|null $consultation */
        $consultation = Consultation::query()
            ->where('paystack_reference', $data['reference'])
            ->first();

        if ($consultation && $status === 'success') {
            $sessions = app(ConsultationSessionService::class);
            $consultation->update([
                'payment_status' => 'paid',
                'paid_at' => now(),
                'session_expires_at' => $sessions->paidSessionExpiresAt($consultation),
            ]);
        }

        return response()->json([
            'status' => 'success',
            'payment' => [
                'reference' => $data['reference'],
                'paystack_status' => $status,
                'consultation_payment_status' => $consultation?->payment_status,
                'session_expires_at' => optional($consultation?->session_expires_at)->toIso8601String(),
            ],
        ]);
    }
}
