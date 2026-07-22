<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AkwaabaFit Admin — Broadcast</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --green: #1a5d1a;
      --green-deep: #14532d;
      --cream: #faf8f4;
      --paper: #fff;
      --ink: #1c2b22;
      --ink-soft: #4a5f52;
      --ink-muted: #7a8f82;
      --line: rgba(26, 93, 26, 0.12);
      --radius: 14px;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: "Plus Jakarta Sans", system-ui, sans-serif;
      background: var(--cream);
      color: var(--ink);
      line-height: 1.5;
    }
    .top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
      padding: 1rem 1.5rem;
      background: var(--paper);
      border-bottom: 1px solid var(--line);
      position: sticky;
      top: 0;
      z-index: 10;
      flex-wrap: wrap;
    }
    .brand { display: flex; align-items: center; gap: 0.6rem; font-weight: 700; color: var(--green-deep); text-decoration: none; }
    .brand img { width: 32px; height: 32px; border-radius: 8px; }
    .nav { display: flex; gap: 0.75rem; align-items: center; flex-wrap: wrap; }
    .nav a {
      color: var(--ink-soft);
      text-decoration: none;
      font-weight: 600;
      font-size: 0.9rem;
    }
    .nav a.active { color: var(--green-deep); }
    .logout {
      border: 1px solid var(--line);
      background: var(--paper);
      border-radius: 10px;
      padding: 0.45rem 0.85rem;
      font: inherit;
      font-weight: 600;
      cursor: pointer;
      color: var(--ink-soft);
    }
    .wrap { width: min(720px, calc(100% - 2rem)); margin: 1.5rem auto 2.5rem; }
    h1 { margin: 0 0 0.35rem; font-size: 1.5rem; }
    .lead { margin: 0 0 1.25rem; color: var(--ink-muted); }
    .panel {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 1.1rem;
      margin-bottom: 1.25rem;
    }
    label { display: block; font-weight: 600; font-size: 0.9rem; margin-bottom: 0.35rem; }
    input, textarea {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 10px;
      padding: 0.7rem 0.85rem;
      font: inherit;
      margin-bottom: 0.9rem;
      background: #fff;
    }
    textarea { min-height: 110px; resize: vertical; }
    .btn {
      border: 0;
      background: var(--green);
      color: #fff;
      border-radius: 10px;
      padding: 0.7rem 1.1rem;
      font: inherit;
      font-weight: 700;
      cursor: pointer;
    }
    .flash {
      background: #dcfce7;
      color: #166534;
      border-radius: 10px;
      padding: 0.75rem 1rem;
      margin-bottom: 1rem;
      font-weight: 600;
    }
    .note {
      font-size: 0.88rem;
      color: var(--ink-muted);
      margin: 0 0 1rem;
    }
    .pill {
      display: inline-block;
      padding: 0.15rem 0.5rem;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    .pill-yes { background: #dcfce7; color: #166534; }
    .pill-no { background: #fef3c7; color: #92400e; }
    .list { list-style: none; padding: 0; margin: 0; }
    .list li {
      padding: 0.75rem 0;
      border-bottom: 1px solid var(--line);
    }
    .list li:last-child { border-bottom: 0; }
    .list strong { display: block; }
    .muted { color: var(--ink-muted); font-size: 0.85rem; }
    .error { color: #b91c1c; font-size: 0.85rem; margin: -0.5rem 0 0.75rem; }
  </style>
</head>
<body>
  <header class="top">
    <a class="brand" href="{{ route('admin.dashboard') }}">
      <img src="{{ asset('images/app_icon_logo.png') }}" alt="">
      <span>AkwaabaFit Admin</span>
    </a>
    <nav class="nav">
      <a href="{{ route('admin.dashboard') }}">Usage</a>
      <a class="active" href="{{ route('admin.broadcast') }}">Broadcast</a>
      <form method="post" action="{{ route('admin.logout') }}">
        @csrf
        <button class="logout" type="submit">Sign out</button>
      </form>
    </nav>
  </header>

  <main class="wrap">
    <h1>Send to everyone</h1>
    <p class="lead">Message appears in the app notification bell. With Firebase configured, it also shows on phones as a system notification.</p>

    @if (session('status'))
      <div class="flash">{{ session('status') }}</div>
    @endif

    <p class="note">
      FCM push:
      @if ($fcmConfigured)
        <span class="pill pill-yes">Configured</span>
      @else
        <span class="pill pill-no">Not configured</span>
        — set <code>FIREBASE_CREDENTIALS</code> to your service-account JSON path.
      @endif
      · Registered devices: <strong>{{ number_format($deviceTokenCount) }}</strong>
    </p>

    <section class="panel">
      <form method="post" action="{{ route('admin.broadcast.store') }}">
        @csrf
        <label for="title">Title</label>
        <input id="title" name="title" maxlength="120" value="{{ old('title') }}" required placeholder="e.g. Weekend step challenge">
        @error('title') <div class="error">{{ $message }}</div> @enderror

        <label for="body">Message</label>
        <textarea id="body" name="body" maxlength="500" required placeholder="Keep it short and clear for the phone notification tray.">{{ old('body') }}</textarea>
        @error('body') <div class="error">{{ $message }}</div> @enderror

        <button class="btn" type="submit">Send announcement</button>
      </form>
    </section>

    <section class="panel">
      <h2 style="margin:0 0 0.75rem;font-size:1rem;">Recent announcements</h2>
      <ul class="list">
        @forelse ($recent as $item)
          <li>
            <strong>{{ $item->title }}</strong>
            <div>{{ $item->body }}</div>
            <div class="muted">
              {{ optional($item->sent_at)->timezone(config('app.timezone'))->format('M j, Y g:i A') }}
              · push {{ $item->push_succeeded }}/{{ $item->push_attempted }}
            </div>
          </li>
        @empty
          <li class="muted">No announcements yet.</li>
        @endforelse
      </ul>
    </section>
  </main>
</body>
</html>
