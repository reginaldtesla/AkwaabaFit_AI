<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Sign in — AkwaabaFit Admin</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --green: #1a5d1a;
      --green-deep: #14532d;
      --cream: #faf8f4;
      --ink: #1c2b22;
      --ink-muted: #7a8f82;
      --line: rgba(26, 93, 26, 0.14);
      --danger: #b91c1c;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      font-family: "Plus Jakarta Sans", system-ui, sans-serif;
      background: radial-gradient(ellipse 70% 50% at 50% -10%, rgba(16, 185, 129, 0.12), transparent 55%), var(--cream);
      color: var(--ink);
      padding: 1.5rem;
    }
    .card {
      width: min(400px, 100%);
      background: #fff;
      border: 1px solid var(--line);
      border-radius: 16px;
      padding: 2rem;
      box-shadow: 0 18px 50px rgba(20, 50, 30, 0.08);
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 0.65rem;
      margin-bottom: 0.35rem;
      font-weight: 700;
      color: var(--green-deep);
    }
    .brand img { width: 36px; height: 36px; border-radius: 10px; }
    .subtitle { margin: 0 0 1.5rem; color: var(--ink-muted); font-size: 0.95rem; }
    label { display: block; font-size: 0.85rem; font-weight: 600; margin-bottom: 0.4rem; }
    input[type="password"] {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 0.75rem 0.9rem;
      font: inherit;
    }
    input:focus { outline: 2px solid rgba(26, 93, 26, 0.25); border-color: var(--green); }
    .pw-wrap { position: relative; margin-bottom: 1rem; }
    .toggle {
      position: absolute;
      right: 0.65rem;
      top: 2.35rem;
      border: 0;
      background: transparent;
      color: var(--green);
      font: inherit;
      font-size: 0.8rem;
      font-weight: 600;
      cursor: pointer;
    }
    button[type="submit"] {
      width: 100%;
      border: 0;
      border-radius: 10px;
      padding: 0.8rem 1rem;
      background: var(--green);
      color: #fff;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }
    button[type="submit"]:hover { background: var(--green-deep); }
    .error { color: var(--danger); font-size: 0.85rem; margin: 0 0 0.75rem; }
    .fine { margin: 1.25rem 0 0; text-align: center; font-size: 0.8rem; color: var(--ink-muted); }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">
      <img src="{{ asset('images/app_icon_logo.png') }}" alt="">
      <span>AkwaabaFit</span>
    </div>
    <p class="subtitle">Sign in to view app usage</p>

    @if ($errors->any())
      <p class="error">{{ $errors->first() }}</p>
    @endif

    <form method="post" action="{{ route('admin.login.submit') }}">
      @csrf
      <div class="pw-wrap">
        <label for="password">Password</label>
        <input id="password" name="password" type="password" required autocomplete="current-password">
        <button class="toggle" type="button" onclick="togglePw()">Show</button>
      </div>
      <button type="submit">Sign in</button>
    </form>

    <p class="fine">Authorized staff only</p>
  </div>
  <script>
    function togglePw() {
      const input = document.getElementById('password');
      const btn = document.querySelector('.toggle');
      const show = input.type === 'password';
      input.type = show ? 'text' : 'password';
      btn.textContent = show ? 'Hide' : 'Show';
    }
  </script>
</body>
</html>
