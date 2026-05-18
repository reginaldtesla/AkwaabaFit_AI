<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Advisor Login - AkwaabaFit AI</title>
    <style>
        body { font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial; background: #0b1220; color: #e5e7eb; margin: 0; }
        .wrap { max-width: 440px; margin: 72px auto; padding: 0 16px; }
        .card { background: #111827; border: 1px solid #1f2937; border-radius: 14px; padding: 20px; }
        h1 { margin: 0 0 8px; font-size: 20px; }
        p { margin: 0 0 16px; color: #9ca3af; }
        label { display: block; font-size: 12px; margin: 12px 0 6px; color: #cbd5e1; }
        input { width: 100%; padding: 10px 12px; border-radius: 10px; border: 1px solid #334155; background: #0b1220; color: #e5e7eb; }
        .row { display: flex; align-items: center; gap: 10px; margin-top: 12px; }
        .btn { width: 100%; margin-top: 14px; background: #22c55e; color: #052e16; border: 0; padding: 10px 12px; border-radius: 10px; font-weight: 700; cursor: pointer; }
        .err { background: #7f1d1d; border: 1px solid #991b1b; padding: 10px 12px; border-radius: 10px; margin-top: 12px; color: #fee2e2; font-size: 13px; }
        .small { font-size: 12px; color: #94a3b8; margin-top: 10px; }
        a { color: #93c5fd; text-decoration: none; }
    </style>
</head>
<body>
<div class="wrap">
    <div class="card">
        <h1>Advisor Portal</h1>
        <p>Sign in to reply to your Nutrition Advice sessions.</p>

        @if ($errors->any())
            <div class="err">
                {{ $errors->first() }}
            </div>
        @endif

        <form method="POST" action="{{ route('advisor.login.submit') }}">
            @csrf
            <label>Email</label>
            <input type="email" name="email" value="{{ old('email') }}" required autocomplete="email" />

            <label>Password</label>
            <input type="password" name="password" required autocomplete="current-password" />

            <div class="row">
                <input id="remember" type="checkbox" name="remember" value="1" style="width: auto;">
                <label for="remember" style="margin: 0;">Remember me</label>
            </div>

            <button class="btn" type="submit">Sign in</button>
        </form>

        <div class="small">
            Need access? Ask the developer to approve your application (it enables your advisor role).
        </div>
    </div>
</div>
</body>
</html>

