<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Dietetics Applications</title>
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#0b1220;color:#e2e8f0}
        .wrap{max-width:1100px;margin:0 auto;padding:18px}
        .card{background:#0f172a;border:1px solid #1f2a44;border-radius:14px;padding:16px}
        a{color:#7dd3fc}
        table{width:100%;border-collapse:collapse;font-size:13px}
        th,td{padding:10px;border-bottom:1px solid #1f2a44;vertical-align:top}
        th{color:#93c5fd;text-align:left;font-size:12px;letter-spacing:.08em;text-transform:uppercase}
        .pill{display:inline-block;padding:4px 8px;border-radius:999px;font-size:11px;font-weight:800}
        .pending{background:#2a1b0f;color:#fdba74;border:1px solid #7c2d12}
        .approved{background:#052e1a;color:#86efac;border:1px solid #14532d}
        .rejected{background:#2b0b0b;color:#fecaca;border:1px solid #7f1d1d}
        .btn{padding:7px 10px;border-radius:10px;border:1px solid #334155;background:#111827;color:#e2e8f0;font-weight:800;cursor:pointer}
        .btnApprove{border-color:#14532d}
        .btnReject{border-color:#7f1d1d}
        .row{display:flex;gap:8px;flex-wrap:wrap}
        input{padding:7px 10px;border-radius:10px;border:1px solid #334155;background:#0b1220;color:#e2e8f0;width:260px}
        .flash{margin:10px 0;padding:10px;border-radius:12px;background:#111827;border:1px solid #334155}
        .top{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <div class="top">
            <div>
                <h2 style="margin:0">Dietetics Applications</h2>
                <div style="color:#94a3b8;font-size:12px;margin-top:4px">
                    Unlocked with <code>DIETETICS_REVIEW_KEY</code> (see <a href="{{ route('dietetics.review.unlock') }}">/admin/dietetics/unlock</a>).
                </div>
            </div>
            <div class="row" style="align-items:center">
                <a href="{{ route('dietetics.review.applications', ['status' => 'pending']) }}">Pending</a>
                <a href="{{ route('dietetics.review.applications', ['status' => 'approved']) }}">Approved</a>
                <a href="{{ route('dietetics.review.applications', ['status' => 'rejected']) }}">Rejected</a>
                <a href="{{ route('dietetics.review.applications') }}">All</a>
                <form method="post" action="{{ route('dietetics.review.lock') }}" style="margin:0">
                    @csrf
                    <button class="btn" type="submit" style="margin:0">Lock portal</button>
                </form>
            </div>
        </div>

        @if (session('status'))
            <div class="flash">{{ session('status') }}</div>
        @endif

        <table>
            <thead>
            <tr>
                <th>User</th>
                <th>Details</th>
                <th>Status</th>
                <th>Certificate</th>
                <th>Review</th>
            </tr>
            </thead>
            <tbody>
            @foreach ($items as $a)
                <tr>
                    <td>
                        <div><strong>{{ $a->full_name }}</strong></div>
                        <div style="color:#94a3b8">{{ $a->user?->email }}</div>
                        <div style="color:#64748b">User ID: {{ $a->user_id }}</div>
                    </td>
                    <td>
                        <div>DOB: <strong>{{ optional($a->date_of_birth)->toDateString() ?? '—' }}</strong> • Age: <strong>{{ $a->age ?? '—' }}</strong></div>
                        <div>Phone: <strong>{{ $a->phone ?? '—' }}</strong></div>
                        <div>Ghana card: <strong>{{ $a->ghana_card_number ?? '—' }}</strong></div>
                        <div>Specialty: <strong>{{ $a->specialty ?? '—' }}</strong></div>
                        <div>Category: <strong>{{ $a->category ?? '—' }}</strong></div>
                        <div>Requested rate: <strong>₵{{ (int) $a->hourly_rate }}</strong>/hr</div>
                        @if ($a->status === 'approved')
                            <div>Listed rate: <strong>₵{{ (int) ($a->listed_hourly_rate ?? $a->hourly_rate) }}</strong>/hr</div>
                            <div>Rating: <strong>{{ $a->rating ?? '—' }}</strong></div>
                        @endif
                        <div style="color:#64748b">Submitted: {{ optional($a->created_at)->toDayDateTimeString() }}</div>
                        @if ($a->reviewed_at)
                            <div style="color:#64748b">Reviewed: {{ optional($a->reviewed_at)->toDayDateTimeString() }}</div>
                        @endif
                        @if ($a->image_url)
                            <div><a target="_blank" href="{{ $a->image_url }}">photo url</a></div>
                        @endif
                    </td>
                    <td>
                        @if ($a->status === 'approved')
                            <span class="pill approved">APPROVED</span>
                        @elseif ($a->status === 'rejected')
                            <span class="pill rejected">REJECTED</span>
                        @else
                            <span class="pill pending">PENDING</span>
                        @endif
                        @if ($a->review_notes)
                            <div style="margin-top:8px;color:#cbd5e1">{{ $a->review_notes }}</div>
                        @endif
                    </td>
                    <td>
                        @if ($a->certificate_path)
                            <div><a target="_blank" href="{{ route('dietetics.review.certificate', ['application' => $a->id]) }}">Certificate</a></div>
                        @endif
                        @if ($a->ghana_card_path)
                            <div><a target="_blank" href="{{ route('dietetics.review.document', ['application' => $a->id, 'type' => 'ghana_card']) }}">Ghana card</a></div>
                        @endif
                        @if ($a->cv_path)
                            <div><a target="_blank" href="{{ route('dietetics.review.document', ['application' => $a->id, 'type' => 'cv']) }}">CV</a></div>
                        @endif
                        @if ($a->profile_photo_path)
                            <div><a target="_blank" href="{{ route('dietetics.review.document', ['application' => $a->id, 'type' => 'profile_photo']) }}">Photo</a></div>
                        @endif
                        @if (!$a->certificate_path && !$a->ghana_card_path && !$a->cv_path && !$a->profile_photo_path)
                            —
                        @endif
                    </td>
                    <td>
                        @if ($a->status !== 'approved')
                        <div class="row" style="margin-bottom:8px;flex-direction:column;align-items:stretch;gap:6px">
                            <form method="post" action="/admin/dietetics/applications/{{ $a->id }}/approve" style="display:flex;flex-wrap:wrap;gap:6px;align-items:center">
                                @csrf
                                <input name="rating" type="number" step="0.1" min="1" max="5" value="{{ old('rating', $a->rating ?? '5.0') }}" placeholder="Rating (1–5)" required style="width:110px">
                                <input name="listed_hourly_rate" type="number" min="1" max="100000" value="{{ old('listed_hourly_rate', $a->listed_hourly_rate ?? $a->hourly_rate) }}" placeholder="₵/hr in app" required style="width:120px">
                                <input name="review_notes" placeholder="Notes (optional)" style="min-width:160px">
                                <button class="btn btnApprove" type="submit">Approve</button>
                            </form>
                        </div>
                        @endif
                        @if ($a->status !== 'approved')
                        <div class="row">
                            <form method="post" action="/admin/dietetics/applications/{{ $a->id }}/reject">
                                @csrf
                                <input name="review_notes" placeholder="Reason (recommended)">
                                <button class="btn btnReject" type="submit">Reject</button>
                            </form>
                        </div>
                        @endif
                    </td>
                </tr>
            @endforeach
            </tbody>
        </table>

        <div style="margin-top:12px">
            {{ $items->links() }}
        </div>
    </div>
</div>
</body>
</html>



