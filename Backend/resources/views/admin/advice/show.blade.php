<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Advice Chat</title>
    <meta http-equiv="refresh" content="5">
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#0b1220;color:#e2e8f0}
        .wrap{max-width:900px;margin:0 auto;padding:18px}
        .card{background:#0f172a;border:1px solid #1f2a44;border-radius:14px;padding:16px}
        .muted{color:#94a3b8;font-size:12px}
        .msg{margin:10px 0;padding:10px 12px;border-radius:12px;border:1px solid #1f2a44;background:#0b1220}
        .msgMe{background:#052e1a;border-color:#14532d}
        .row{display:flex;gap:10px}
        textarea{flex:1;min-height:44px;max-height:120px;padding:10px;border-radius:12px;border:1px solid #334155;background:#0b1220;color:#e2e8f0}
        button{padding:10px 12px;border-radius:12px;border:1px solid #14532d;background:#0fbd74;color:#fff;font-weight:900;cursor:pointer}
        a{color:#7dd3fc}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <div style="display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap">
            <div>
                <h2 style="margin:0">Consultation #{{ $consultation->id }}</h2>
                <div class="muted">
                    User {{ $consultation->user_id }} • {{ $consultation->dietician_name }} •
                    payment={{ $consultation->payment_status }} • expires={{ optional($consultation->session_expires_at)->toIso8601String() ?? '—' }}
                </div>
            </div>
            <div><a href="/admin/advice">Back to inbox</a></div>
        </div>

        <div style="margin-top:14px">
            @foreach ($messages as $m)
                @php $isPro = $m->sender === 'professional'; @endphp
                <div class="msg {{ $isPro ? 'msgMe' : '' }}">
                    <div class="muted">
                        <strong>{{ $m->sender }}</strong> • {{ optional($m->created_at)->toDayDateTimeString() }}
                    </div>
                    <div style="margin-top:6px;white-space:pre-wrap">{{ $m->body }}</div>
                </div>
            @endforeach
        </div>

        <form method="post" action="/admin/advice/{{ $consultation->id }}/messages" style="margin-top:14px">
            @csrf
            <div class="row">
                <textarea name="body" placeholder="Reply as professional..."></textarea>
                <button type="submit">Send</button>
            </div>
            <div class="muted" style="margin-top:8px">Auto refreshes every 5 seconds for near real-time replies.</div>
        </form>
    </div>
</div>
</body>
</html>

