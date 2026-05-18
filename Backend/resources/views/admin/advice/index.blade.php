<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Advice Inbox</title>
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#0b1220;color:#e2e8f0}
        .wrap{max-width:1100px;margin:0 auto;padding:18px}
        .card{background:#0f172a;border:1px solid #1f2a44;border-radius:14px;padding:16px}
        a{color:#7dd3fc}
        table{width:100%;border-collapse:collapse;font-size:13px}
        th,td{padding:10px;border-bottom:1px solid #1f2a44;vertical-align:top}
        th{color:#93c5fd;text-align:left;font-size:12px;letter-spacing:.08em;text-transform:uppercase}
        .pill{display:inline-block;padding:4px 8px;border-radius:999px;font-size:11px;font-weight:800}
        .paid{background:#052e1a;color:#86efac;border:1px solid #14532d}
        .pending{background:#2a1b0f;color:#fdba74;border:1px solid #7c2d12}
        .expired{background:#2b0b0b;color:#fecaca;border:1px solid #7f1d1d}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <h2 style="margin:0 0 10px">Advice Inbox</h2>
        <div style="color:#94a3b8;font-size:12px;margin-bottom:12px">
            Same access as applications: unlock at <code>/admin/dietetics/unlock</code> once per browser, or use <code>?key=</code>.
        </div>

        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>User</th>
                <th>Professional</th>
                <th>Status</th>
                <th>Session</th>
                <th></th>
            </tr>
            </thead>
            <tbody>
            @foreach ($items as $it)
                @php
                    $exp = $it['session_expires_at'] ? \Carbon\Carbon::parse($it['session_expires_at']) : null;
                    $isExpired = $exp ? now()->gte($exp) : false;
                @endphp
                <tr>
                    <td>#{{ $it['id'] }}</td>
                    <td>User {{ $it['user_id'] }}</td>
                    <td>{{ $it['dietician_name'] }}</td>
                    <td>
                        @if ($it['payment_status'] === 'paid' && !$isExpired)
                            <span class="pill paid">PAID</span>
                        @elseif ($it['payment_status'] === 'paid' && $isExpired)
                            <span class="pill expired">EXPIRED</span>
                        @else
                            <span class="pill pending">PENDING</span>
                        @endif
                    </td>
                    <td style="color:#94a3b8">
                        {{ $it['session_expires_at'] ?? '—' }}
                    </td>
                    <td>
                        <a href="/admin/advice/{{ $it['id'] }}">Open</a>
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>
    </div>
</div>
</body>
</html>

