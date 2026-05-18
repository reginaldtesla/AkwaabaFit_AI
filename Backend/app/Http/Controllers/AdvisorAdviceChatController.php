<?php

namespace App\Http\Controllers;

use App\Models\Consultation;
use App\Models\ConsultationMessage;
use Illuminate\Http\Request;

class AdvisorAdviceChatController extends Controller
{
    public function index(Request $request)
    {
        $advisorId = $request->user()->id;

        $consultations = Consultation::query()
            ->with(['user:id,name'])
            ->where('advisor_user_id', $advisorId)
            ->orderByDesc('updated_at')
            ->limit(200)
            ->get();

        return view('advisor.advice.index', compact('consultations'));
    }

    public function show(Request $request, Consultation $consultation)
    {
        $advisorId = $request->user()->id;
        if ((int) $consultation->advisor_user_id !== (int) $advisorId) {
            abort(404);
        }

        $consultation->loadMissing('user:id,name');
        $messages = $consultation->messages()->orderBy('id')->get();

        return view('advisor.advice.show', compact('consultation', 'messages'));
    }

    public function send(Request $request, Consultation $consultation)
    {
        $advisorId = $request->user()->id;
        if ((int) $consultation->advisor_user_id !== (int) $advisorId) {
            abort(404);
        }

        $data = $request->validate([
            'message' => ['required', 'string', 'max:5000'],
        ]);

        ConsultationMessage::create([
            'consultation_id' => $consultation->id,
            'sender' => 'professional',
            'message' => $data['message'],
        ]);

        $consultation->touch();

        return redirect()->route('advisor.consultations.show', $consultation);
    }
}
