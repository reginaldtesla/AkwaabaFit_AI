<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AkwaabaFit Admin — Usage</title>
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
    }
    .brand { display: flex; align-items: center; gap: 0.6rem; font-weight: 700; color: var(--green-deep); }
    .brand img { width: 32px; height: 32px; border-radius: 8px; }
    .meta { font-size: 0.85rem; color: var(--ink-muted); }
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
    .wrap { width: min(1100px, calc(100% - 2rem)); margin: 1.5rem auto 2.5rem; }
    h1 { margin: 0 0 0.35rem; font-size: 1.5rem; }
    .lead { margin: 0 0 1.5rem; color: var(--ink-muted); }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 0.85rem;
      margin-bottom: 1.75rem;
    }
    .stat {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 1rem;
    }
    .stat strong { display: block; font-size: 1.6rem; color: var(--green-deep); line-height: 1.1; }
    .stat span { font-size: 0.82rem; color: var(--ink-muted); }
    .panel {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      overflow: hidden;
    }
    .panel h2 {
      margin: 0;
      padding: 1rem 1.1rem;
      font-size: 1rem;
      border-bottom: 1px solid var(--line);
    }
    .table-wrap { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    th, td { padding: 0.7rem 1rem; text-align: left; border-bottom: 1px solid var(--line); }
    th { font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; color: var(--ink-muted); background: #fbfaf7; }
    tr:last-child td { border-bottom: 0; }
    .pill {
      display: inline-block;
      padding: 0.15rem 0.5rem;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    .pill-yes { background: #dcfce7; color: #166534; }
    .pill-no { background: #f1f5f9; color: #64748b; }
    .live { color: #15803d; font-weight: 600; }
    .muted { color: var(--ink-muted); }
    @media (max-width: 640px) {
      th:nth-child(4), td:nth-child(4) { display: none; }
    }
  </style>
</head>
<body>
  <header class="top">
    <div class="brand">
      <img src="{{ asset('images/app_icon_logo.png') }}" alt="">
      <span>AkwaabaFit Admin</span>
    </div>
    <div class="meta">Updated {{ $generatedAt->timezone(config('app.timezone'))->format('M j, Y g:i A') }}</div>
    <form method="post" action="{{ route('admin.logout') }}">
      @csrf
      <button class="logout" type="submit">Sign out</button>
    </form>
  </header>

  <main class="wrap">
    <h1>App usage</h1>
    <p class="lead">See who registered, who opened the app recently, and who logged activity today.</p>

    <div class="grid">
      <div class="stat"><strong>{{ number_format($stats['total_users']) }}</strong><span>Total users</span></div>
      <div class="stat"><strong>{{ number_format($stats['profiles_completed']) }}</strong><span>Profiles complete</span></div>
      <div class="stat"><strong>{{ number_format($stats['active_15m']) }}</strong><span>Active last 15 min</span></div>
      <div class="stat"><strong>{{ number_format($stats['active_1h']) }}</strong><span>Active last hour</span></div>
      <div class="stat"><strong>{{ number_format($stats['active_today']) }}</strong><span>Opened app today</span></div>
      <div class="stat"><strong>{{ number_format($stats['registered_7d']) }}</strong><span>New signups (7 days)</span></div>
      <div class="stat"><strong>{{ number_format($stats['steps_today']) }}</strong><span>Logged steps today</span></div>
      <div class="stat"><strong>{{ number_format($stats['meals_today']) }}</strong><span>Logged meals today</span></div>
      <div class="stat"><strong>{{ number_format($stats['water_today']) }}</strong><span>Logged water today</span></div>
    </div>

    <section class="panel">
      <h2>Recent users (by last seen)</h2>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Profile</th>
              <th>Steps today</th>
              <th>Last seen</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            @forelse ($users as $user)
              <tr>
                <td>{{ $user->name }}</td>
                <td>{{ $user->email }}</td>
                <td>
                  <span class="pill {{ $user->profile_completed ? 'pill-yes' : 'pill-no' }}">
                    {{ $user->profile_completed ? 'Complete' : 'Incomplete' }}
                  </span>
                </td>
                <td>{{ number_format($user->steps_today) }}</td>
                <td>
                  @if ($user->last_seen_at)
                    @if ($user->last_seen_at->greaterThan(now()->subMinutes(15)))
                      <span class="live">Now</span>
                    @else
                      {{ $user->last_seen_at->diffForHumans() }}
                    @endif
                  @else
                    <span class="muted">Never</span>
                  @endif
                </td>
                <td class="muted">{{ $user->created_at->format('M j, Y') }}</td>
              </tr>
            @empty
              <tr>
                <td colspan="6" class="muted">No users yet.</td>
              </tr>
            @endforelse
          </tbody>
        </table>
      </div>
    </section>
  </main>
</body>
</html>
