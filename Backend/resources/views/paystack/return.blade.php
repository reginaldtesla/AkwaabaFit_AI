<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Payment complete</title>
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#f6f7fb;color:#0f172a}
        .wrap{max-width:640px;margin:0 auto;padding:24px}
        .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:18px}
        .title{font-size:20px;font-weight:900;margin:0 0 6px}
        .muted{color:#64748b;font-size:13px;margin:0;line-height:1.4}
        .pill{display:inline-block;margin-top:10px;padding:6px 10px;border-radius:999px;font-size:12px;font-weight:800;background:#ecfdf5;color:#166534;border:1px solid #bbf7d0}
        .ref{margin-top:12px;padding:10px 12px;border-radius:10px;background:#f1f5f9;border:1px solid #e2e8f0;font-size:13px}
        .btn{display:inline-block;margin-top:14px;background:#0fbd74;color:#fff;border:none;padding:12px 14px;border-radius:10px;font-weight:900;width:100%;font-size:15px}
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <h1 class="title">Payment completed</h1>
        <p class="muted">You can now return to the AkwaabaFit app. The app will verify your payment and start your advice session.</p>
        <span class="pill">OK</span>

        @if (!empty($reference))
            <div class="ref"><strong>Reference:</strong> {{ $reference }}</div>
        @endif

        <button class="btn" onclick="window.close()">Close</button>
        <p class="muted" style="margin-top:10px">If this page doesn’t close automatically, just switch back to the app.</p>
    </div>
</div>
</body>
</html>

