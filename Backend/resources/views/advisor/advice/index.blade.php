<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>My Advice Sessions - Advisor Portal</title>
    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; background: #0b1220; color: #e5e7eb; margin: 0; }
        .wrap { max-width: 980px; margin: 24px auto; padding: 0 16px; }
        .top { display:flex; align-items:center; justify-content:space-between; margin-bottom: 14px; }
        .card { background: #111827; border: 1px solid #1f2937; border-radius: 14px; padding: 14px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px 8px; border-bottom: 1px solid #1f2937; text-align: left; font-size: 14px; }
        th { color: #93c5fd; font-weight: 700; }
        .badge { display:inline-block; padding: 3px 8px; border-radius: 999px; font-size: 12px; border: 1px solid #334155; color: #cbd5e1; }
        .paid { border-color: #16a34a; color: #bbf7d0; }
        a { color: #93c5fd; text-decoration: none; }
        .btn { background: #1f2937; border: 1px solid #334155; color: #e5e7eb; padding: 8px 10px; border-radius: 10px; cursor:pointer; }
        .muted { color: #9ca3af; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="top">
        <div>
            <div style="font-size:18px; font-weight:800;">My Advice Sessions</div>
            <div class="muted" style="margin-top:4px;">Only sessions assigned to your account are visible.</div>
        </div>
        <form method="POST" action="{{ route('advisor.logout') }}">
            @csrf
            <button class="btn" type="submit">Logout</button>
        </form>
    </div>

    <div class="card">
        <table>
            <thead>
            <tr>
                <th>ID</th>
                <th>Client</th>
                <th>Status</th>
                <th>Created</th>
                <th></th>
            </tr>
            </thead>
            <tbody>
            @forelse($consultations as $c)
                <tr>
                    <td>#{{ $c->id }}</td>
                    <td>{{ $c->user?->name ?? ('User #' . $c->user_id) }}</td>
                    <td>
                        <span class="badge {{ $c->payment_status === 'paid' ? 'paid' : '' }}">
                            {{ $c->payment_status }}
                        </span>
                    </td>
                    <td class="muted">{{ $c->created_at }}</td>
                    <td><a href="{{ route('advisor.consultations.show', $c) }}">Open</a></td>
                </tr>
            @empty
                <tr>
                    <td colspan="5" class="muted">No sessions yet.</td>
                </tr>
            @endforelse
            </tbody>
        </table>
    </div>
</div>
</body>
</html>

