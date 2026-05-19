<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Returning to AkwaabaFit</title>
    <style>
        body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;margin:0;background:#f6f7fb;color:#0f172a}
        .wrap{max-width:640px;margin:0 auto;padding:24px}
        .card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:18px;text-align:center}
        .title{font-size:20px;font-weight:900;margin:0 0 6px}
        .muted{color:#64748b;font-size:13px;margin:0;line-height:1.4}
        .spinner{width:36px;height:36px;border:3px solid #e2e8f0;border-top-color:#0fbd74;border-radius:50%;margin:16px auto;animation:spin .8s linear infinite}
        @keyframes spin{to{transform:rotate(360deg)}}
        .ref{margin-top:12px;padding:10px 12px;border-radius:10px;background:#f1f5f9;border:1px solid #e2e8f0;font-size:13px;text-align:left}
    </style>
    @if (!empty($deep_link))
    <meta http-equiv="refresh" content="0;url={{ $deep_link }}">
    @endif
</head>
<body>
<div class="wrap">
    <div class="card">
        <h1 class="title">Payment complete</h1>
        <p class="muted">Opening AkwaabaFit…</p>
        <div class="spinner"></div>
        @if (!empty($reference))
            <div class="ref"><strong>Reference:</strong> {{ $reference }}</div>
        @endif
        <p class="muted" style="margin-top:14px">If the app does not open, switch back to AkwaabaFit manually.</p>
    </div>
</div>
@if (!empty($deep_link))
<script>
    (function () {
        var target = @json($deep_link);
        try { window.location.replace(target); } catch (e) {}
        setTimeout(function () {
            try { window.location.href = target; } catch (e) {}
        }, 250);
    })();
</script>
@endif
</body>
</html>