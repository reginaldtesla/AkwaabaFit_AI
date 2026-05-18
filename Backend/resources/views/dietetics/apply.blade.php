<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Nutrition Professional Application</title>
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#f6f7fb;color:#0f172a}
        .wrap{max-width:820px;margin:0 auto;padding:24px}
        .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:18px}
        .title{font-size:20px;font-weight:800;margin:0 0 6px}
        .muted{color:#64748b;font-size:13px;margin:0}
        .pill{display:inline-block;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:700}
        .pending{background:#fff7ed;color:#9a3412;border:1px solid #fed7aa}
        .approved{background:#ecfdf5;color:#166534;border:1px solid #bbf7d0}
        .rejected{background:#fef2f2;color:#991b1b;border:1px solid #fecaca}
        .row{display:grid;grid-template-columns:1fr 1fr;gap:12px}
        label{display:block;font-size:12px;color:#334155;margin:10px 0 6px;font-weight:700}
        input{width:100%;padding:12px;border:1px solid #e2e8f0;border-radius:10px;font-size:14px}
        input[type=file]{padding:10px}
        .btn{display:inline-block;margin-top:14px;background:#0fbd74;color:#fff;border:none;padding:12px 14px;border-radius:10px;font-weight:800;width:100%;font-size:15px}
        .note{font-size:12px;color:#64748b;line-height:1.4;margin-top:10px}
        .statusBox{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:10px 0 0}
        .flash{margin:12px 0;padding:10px 12px;border-radius:10px;background:#f1f5f9;border:1px solid #e2e8f0;font-size:13px}
        .reviewNotes{margin-top:10px;padding:10px 12px;border-radius:10px;background:#fff;border:1px dashed #cbd5e1;color:#0f172a;font-size:13px}
        @media (max-width:720px){.row{grid-template-columns:1fr}}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <h1 class="title">Apply as a Nutrition Professional</h1>
        <p class="muted">Hello {{ $user->name }}. Submit your credentials so our team can verify you as a registered dietitian or nutritionist for in-app food advice.</p>

        @if (session('status'))
            <div class="flash">{{ session('status') }}</div>
        @endif

        @php
            $status = $application?->status;
        @endphp

        @if ($application)
            <div class="statusBox">
                <div>
                    <strong>Status</strong>
                    <div style="margin-top:6px">
                        @if ($status === 'approved')
                            <span class="pill approved">APPROVED</span>
                        @elseif ($status === 'rejected')
                            <span class="pill rejected">REJECTED</span>
                        @else
                            <span class="pill pending">IN REVIEW</span>
                        @endif
                    </div>
                </div>
                <div class="muted" style="text-align:right">
                    Submitted: {{ optional($application->created_at)->toDayDateTimeString() }}
                </div>
            </div>

            @if (!empty($application->review_notes))
                <div class="reviewNotes">
                    <strong>Review notes</strong><br>
                    {{ $application->review_notes }}
                </div>
            @endif
        @endif

        @if ($application && $status === 'pending')
            <p class="note">Your application is currently in review. We’ll update this page when a decision is made.</p>
        @else
            <form method="post" enctype="multipart/form-data" action="{{ url()->current() . '?' . http_build_query(request()->query()) }}">
                @csrf

                <label>Full name</label>
                <input name="full_name" value="{{ old('full_name', $application->full_name ?? $user->name) }}" required>

                <div class="row">
                    <div>
                        <label>Specialty (optional)</label>
                        <input name="specialty" value="{{ old('specialty', $application->specialty ?? '') }}" placeholder="e.g. Diabetes & heart health">
                    </div>
                    <div>
                        <label>Category (optional)</label>
                        <input name="category" value="{{ old('category', $application->category ?? '') }}" placeholder="e.g. Diabetes, Athletic, General">
                    </div>
                </div>

                <div class="row">
                    <div>
                        <label>Hourly rate (optional)</label>
                        <input name="hourly_rate" type="number" min="0" max="100000" value="{{ old('hourly_rate', $application->hourly_rate ?? 0) }}">
                    </div>
                    <div>
                        <label>Profile photo URL (optional)</label>
                        <input name="image_url" value="{{ old('image_url', $application->image_url ?? '') }}" placeholder="https://...">
                    </div>
                </div>

                <label>Certificate (PDF/JPG/PNG, max 20MB)</label>
                <input name="certificate" type="file" accept=".pdf,.jpg,.jpeg,.png" required>
                @error('certificate')<div class="note" style="color:#b91c1c">{{ $message }}</div>@enderror

                @if ($errors->any())
                    <div class="note" style="color:#b91c1c;margin-top:10px">
                        Please fix the highlighted fields and submit again.
                    </div>
                @endif

                <button class="btn" type="submit">Submit application</button>

                <p class="note">
                    What happens next: our team will verify your certificate and details.
                    If approved, you’ll appear automatically in the Nutrition Advice professionals list in the app.
                </p>
            </form>
        @endif
    </div>
</div>
</body>
</html>

