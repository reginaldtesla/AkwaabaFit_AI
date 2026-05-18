<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{ trim($consultation->user?->name ?? '') !== '' ? $consultation->user->name : 'Session #' . $consultation->id }} - Advisor Portal</title>
    <meta http-equiv="refresh" content="8">
    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; background: #0b1220; color: #e5e7eb; margin: 0; }
        .wrap { max-width: 980px; margin: 24px auto; padding: 0 16px; }
        .top { display:flex; align-items:center; justify-content:space-between; margin-bottom: 14px; }
        a { color: #93c5fd; text-decoration: none; }
        .btn { background: #1f2937; border: 1px solid #334155; color: #e5e7eb; padding: 8px 10px; border-radius: 10px; cursor:pointer; }
        .card { background: #111827; border: 1px solid #1f2937; border-radius: 14px; padding: 14px; }
        .msg { padding: 10px 12px; border-radius: 12px; margin: 10px 0; max-width: 70%; }
        .user { background: #0b1220; border: 1px solid #334155; margin-right: auto; }
        .pro { background: rgba(34,197,94,.12); border: 1px solid rgba(34,197,94,.35); margin-left: auto; }
        .meta { font-size: 12px; color: #9ca3af; margin-top: 6px; }
        textarea { width: 100%; min-height: 90px; padding: 10px 12px; border-radius: 12px; border: 1px solid #334155; background: #0b1220; color: #e5e7eb; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="top">
        <div>
            <div style="font-size:18px; font-weight:800;">{{ trim($consultation->user?->name ?? '') !== '' ? $consultation->user->name : ('Session #' . $consultation->id) }}</div>
            <div style="color:#9ca3af; margin-top:4px;">Session #{{ $consultation->id }} • Status: {{ $consultation->payment_status }}</div>
        </div>
        <div style="display:flex; gap:10px; align-items:center;">
            <a class="btn" href="{{ route('advisor.consultations.index') }}">Back</a>
            <form method="POST" action="{{ route('advisor.logout') }}">
                @csrf
                <button class="btn" type="submit">Logout</button>
            </form>
        </div>
    </div>

    <div class="card">
        @foreach($messages as $m)
            <div class="msg {{ $m->sender === 'professional' ? 'pro' : 'user' }}">
                <div>{{ $m->message }}</div>
                <div class="meta">{{ $m->sender }} • {{ $m->created_at }}</div>
            </div>
        @endforeach
    </div>

    <div class="card" style="margin-top:14px;">
        <form method="POST" action="{{ route('advisor.consultations.send', $consultation) }}">
            @csrf
            <textarea name="message" placeholder="Type your reply..." required></textarea>
            <button class="btn" type="submit" style="margin-top:10px;">Send</button>
        </form>
        <div class="meta">Auto-refreshes every 8s.</div>
    </div>
</div>
</body>
</html>

