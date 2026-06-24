<?php

namespace App\Http\Controllers;

use App\Models\Consultation;
use App\Models\ConsultationMessage;
use Illuminate\Http\Request;

class AdminAdviceChatController extends Controller
{
    public function index(Request $request)
    {
        $items = Consultation::query()
            ->orderByDesc('updated_at')
            ->limit(100)
            ->get(['id', 'user_id', 'dietician_name', 'scheduled_time', 'session_expires_at', 'created_at'])
            ->map(fn (Consultation $c) => [
                'id' => $c->id,
                'user_id' => $c->user_id,
                'dietician_name' => $c->dietician_name,
                'scheduled_time' => optional($c->scheduled_time)->toIso8601String(),
                'session_expires_at' => optional($c->session_expires_at)->toIso8601String(),
                'created_at' => optional($c->created_at)->toIso8601String(),
            ])
            ->values();

        return view('admin.advice.index', [
            'items' => $items,
        ]);
    }

    public function show(Request $request, Consultation $consultation)
    {
        $msgs = ConsultationMessage::query()
            ->where('consultation_id', $consultation->id)
            ->orderBy('created_at')
            ->get();

        return view('admin.advice.show', [
            'consultation' => $consultation,
            'messages' => $msgs,
        ]);
    }

    public function send(Request $request, Consultation $consultation)
    {
        $data = $request->validate([
            'body' => ['required', 'string', 'max:2000'],
        ]);

        ConsultationMessage::create([
            'consultation_id' => $consultation->id,
            'sender' => 'professional',
            'body' => $data['body'],
        ]);

        return redirect()->back();
    }
}
