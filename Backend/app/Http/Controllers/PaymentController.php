<?php

namespace App\Http\Controllers;

use App\Models\Consultation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    public function handleWebhook(Request $request)
    {
        $paystackSignature = $request->header('x-paystack-signature');
        $secret = config('services.paystack.secret_key');

        if (!$paystackSignature || $paystackSignature !== hash_hmac('sha512', $request->getContent(), $secret)) {
            return response()->json(['message' => 'Invalid signature'], 401);
        }

        $event = $request->input('event');
        $data = $request->input('data');

        if ($event === 'charge.success') {
            $consultation = Consultation::where('paystack_reference', $data['reference'])->first();
            if ($consultation) {
                $consultation->update(['payment_status' => 'paid']);
                Log::info("Payment successful for reference: " . $data['reference']);
            }
        }

        return response()->json(['status' => 'success'], 200);
    }
}