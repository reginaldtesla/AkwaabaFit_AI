<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Unlock review portal</title>
    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; margin: 0; background: #0b1220; color: #e2e8f0; }
        .wrap { max-width: 480px; margin: 48px auto; padding: 0 16px; }
        .card { background: #0f172a; border: 1px solid #1f2a44; border-radius: 14px; padding: 20px; }
        h1 { margin: 0 0 8px; font-size: 20px; }
        p { margin: 0 0 16px; color: #94a3b8; font-size: 14px; line-height: 1.5; }
        label { display: block; font-size: 12px; color: #cbd5e1; margin-bottom: 6px; }
        input[type="password"], input[type="text"] { width: 100%; box-sizing: border-box; padding: 10px 12px; border-radius: 10px; border: 1px solid #334155; background: #0b1220; color: #e2e8f0; font-size: 14px; }
        .err { background: #450a0a; border: 1px solid #7f1d1d; color: #fecaca; padding: 10px 12px; border-radius: 10px; margin-bottom: 14px; font-size: 13px; }
        .ok { background: #052e1a; border: 1px solid #14532d; color: #bbf7d0; padding: 10px 12px; border-radius: 10px; margin-bottom: 14px; font-size: 13px; }
        button { margin-top: 14px; width: 100%; padding: 11px 12px; border-radius: 10px; border: 0; background: #22c55e; color: #052e16; font-weight: 800; cursor: pointer; font-size: 15px; }
        code { font-size: 12px; color: #a5b4fc; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <h1>Review portal unlock</h1>
        <p>
            Enter the same value as <code>DIETETICS_REVIEW_KEY</code> in your Backend <code>.env</code>,
            or <a href="{{ route('staff.admin.login') }}">sign in as staff admin</a> (user with <code>is_staff_admin</code> in the database).
            The key unlocks the admin pages in <strong>this browser only</strong> until you lock or clear cookies.
        </p>

        @if (session('status'))
            <div class="ok">{{ session('status') }}</div>
        @endif

        @if ($errors->any())
            <div class="err">{{ $errors->first() }}</div>
        @endif

        <form method="post" action="{{ route('dietetics.review.unlock.submit') }}">
            @csrf
            <label for="key">Review key</label>
            <input id="key" name="key" type="password" autocomplete="off" required placeholder="Paste DIETETICS_REVIEW_KEY">
            <button type="submit">Continue to applications</button>
        </form>
    </div>
</div>
</body>
</html>
