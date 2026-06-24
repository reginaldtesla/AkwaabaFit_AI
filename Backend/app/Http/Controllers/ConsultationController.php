<?php

namespace App\Http\Controllers;

use App\Http\Requests\BookConsultationRequest;
use App\Models\Consultation;
use App\Services\ConsultationSessionService;
use Illuminate\Http\JsonResponse;

class ConsultationController extends Controller
{
    public function book(
        BookConsultationRequest $request,
        ConsultationSessionService $sessions,
    ): JsonResponse {
        $consultation = Consultation::create([
            'user_id' => $request->user()->id,
            'dietician_name' => $request->dietician_name,
            'scheduled_time' => $request->scheduled_time,
            'paid_at' => now(),
            'session_expires_at' => null,
        ]);

        $consultation->update([
            'session_expires_at' => $sessions->sessionExpiresAt($consultation),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Consultation booked.',
            'data' => $consultation->fresh(),
        ], 201);
    }
}
