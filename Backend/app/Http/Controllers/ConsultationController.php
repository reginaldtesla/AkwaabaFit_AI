<?php

namespace App\Http\Controllers;

use App\Http\Requests\BookConsultationRequest;
use App\Models\Consultation;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Str;

class ConsultationController extends Controller
{
    public function book(BookConsultationRequest $request): JsonResponse
    {
        $consultation = Consultation::create([
            'user_id' => $request->user()->id,
            'dietician_name' => $request->dietician_name,
            'scheduled_time' => $request->scheduled_time,
            'payment_status' => 'pending',
            'paystack_reference' => 'AKW-' . Str::upper(Str::random(10)),
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Consultation booked. Awaiting payment.',
            'data' => $consultation,
        ], 201);
    }
}
