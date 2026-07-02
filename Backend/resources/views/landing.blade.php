<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>AkwaabaFit — Wellness built for Ghana</title>
  <meta name="description" content="AkwaabaFit helps Ghanaians track steps, scan local meals with AI, and stay safe outdoors — nutrition and movement in one app made for everyday life here.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=DM+Serif+Display:ital@0;1&family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --green-deep: #14532d;
      --green: #1a5d1a;
      --green-bright: #10b981;
      --gold: #e8a317;
      --gold-soft: #fff7e0;
      --cream: #faf8f4;
      --paper: #ffffff;
      --ink: #1c2b22;
      --ink-soft: #4a5f52;
      --ink-muted: #7a8f82;
      --line: rgba(26, 93, 26, 0.12);
      --shadow: 0 18px 50px rgba(20, 50, 30, 0.08);
      --radius: 18px;
      --radius-sm: 12px;
      --max: 1120px;
    }

    *, *::before, *::after { box-sizing: border-box; }
    html { scroll-behavior: smooth; }

    body {
      margin: 0;
      font-family: "Plus Jakarta Sans", system-ui, sans-serif;
      color: var(--ink);
      background: var(--cream);
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
    }

    img { max-width: 100%; display: block; }
    a { color: inherit; }

    .page-bg {
      position: fixed;
      inset: 0;
      z-index: -1;
      background:
        radial-gradient(ellipse 80% 50% at 10% -10%, rgba(16, 185, 129, 0.14), transparent 55%),
        radial-gradient(ellipse 60% 40% at 95% 5%, rgba(232, 163, 23, 0.12), transparent 50%),
        radial-gradient(ellipse 50% 30% at 50% 100%, rgba(26, 93, 26, 0.06), transparent 60%),
        var(--cream);
    }

    .wrap {
      width: min(var(--max), calc(100% - 2.5rem));
      margin-inline: auto;
    }

    /* ——— Nav ——— */
    .nav {
      position: sticky;
      top: 0;
      z-index: 50;
      padding: 0.85rem 0;
      backdrop-filter: blur(12px);
      background: rgba(250, 248, 244, 0.88);
      border-bottom: 1px solid var(--line);
    }

    .nav-inner {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 1rem;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 0.75rem;
      text-decoration: none;
      font-weight: 800;
      font-size: 1.05rem;
      letter-spacing: -0.02em;
    }

    .brand img {
      width: 42px;
      height: 42px;
      border-radius: 11px;
      box-shadow: 0 4px 14px rgba(26, 93, 26, 0.18);
    }

    .nav-links {
      display: flex;
      align-items: center;
      gap: 1.25rem;
      font-size: 0.9rem;
      font-weight: 600;
      color: var(--ink-soft);
    }

    .nav-links a {
      text-decoration: none;
      transition: color 0.15s;
    }

    .nav-links a:hover { color: var(--green); }

    .btn {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 0.4rem;
      padding: 0.72rem 1.25rem;
      border-radius: 999px;
      font-weight: 700;
      font-size: 0.92rem;
      text-decoration: none;
      border: none;
      cursor: pointer;
      transition: transform 0.15s, box-shadow 0.15s, background 0.15s;
    }

    .btn:active { transform: scale(0.98); }

    .btn-primary {
      background: var(--green);
      color: #fff;
      box-shadow: 0 8px 22px rgba(26, 93, 26, 0.28);
    }

    .btn-primary:hover {
      background: var(--green-deep);
      box-shadow: 0 10px 28px rgba(26, 93, 26, 0.32);
    }

    .btn-ghost {
      background: var(--paper);
      color: var(--green);
      border: 1.5px solid var(--line);
    }

    .btn-ghost:hover { border-color: var(--green); }

    /* ——— Hero ——— */
    .hero {
      padding: 3.5rem 0 4rem;
    }

    .hero-grid {
      display: grid;
      grid-template-columns: 1.05fr 0.95fr;
      gap: 2.5rem;
      align-items: center;
    }

    .eyebrow {
      display: inline-flex;
      align-items: center;
      gap: 0.5rem;
      padding: 0.35rem 0.85rem;
      background: var(--gold-soft);
      border: 1px solid rgba(232, 163, 23, 0.25);
      border-radius: 999px;
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.04em;
      text-transform: uppercase;
      color: #8a5a00;
      margin-bottom: 1.25rem;
    }

    .hero h1 {
      font-family: "DM Serif Display", Georgia, serif;
      font-size: clamp(2.4rem, 5vw, 3.6rem);
      line-height: 1.08;
      font-weight: 400;
      margin: 0 0 1.1rem;
      letter-spacing: -0.02em;
    }

    .hero h1 em {
      font-style: italic;
      color: var(--green);
    }

    .hero-lead {
      font-size: 1.12rem;
      color: var(--ink-soft);
      max-width: 34rem;
      margin: 0 0 1.75rem;
    }

    .hero-ctas {
      display: flex;
      flex-wrap: wrap;
      gap: 0.75rem;
      margin-bottom: 2rem;
    }

    .hero-note {
      font-size: 0.85rem;
      color: var(--ink-muted);
      max-width: 28rem;
    }

    .hero-visual {
      position: relative;
      padding: 1.5rem;
    }

    .phone-card {
      background: linear-gradient(160deg, #f0fdf4 0%, #fff 45%, #fffbeb 100%);
      border: 1px solid var(--line);
      border-radius: 28px;
      padding: 1.75rem;
      box-shadow: var(--shadow);
      transform: rotate(1.2deg);
    }

    .phone-card img {
      width: 120px;
      height: 120px;
      margin: 0 auto 1.25rem;
      border-radius: 26px;
      box-shadow: 0 14px 35px rgba(26, 93, 26, 0.15);
    }

    .phone-stats {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0.65rem;
    }

    .stat-pill {
      background: rgba(255, 255, 255, 0.85);
      border: 1px solid var(--line);
      border-radius: var(--radius-sm);
      padding: 0.75rem 0.85rem;
    }

    .stat-pill strong {
      display: block;
      font-size: 1.1rem;
      color: var(--green);
      line-height: 1.2;
    }

    .stat-pill span {
      font-size: 0.75rem;
      color: var(--ink-muted);
      font-weight: 600;
    }

    .float-tag {
      position: absolute;
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 0.55rem 0.85rem;
      font-size: 0.8rem;
      font-weight: 600;
      box-shadow: 0 8px 24px rgba(20, 50, 30, 0.07);
    }

    .float-tag.one { top: 0; right: 0; transform: rotate(-2deg); }
    .float-tag.two { bottom: 1rem; left: -0.5rem; transform: rotate(1.5deg); color: var(--green); }

    /* ——— Sections ——— */
    section { padding: 4rem 0; }

    .section-label {
      font-size: 0.75rem;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: var(--green);
      margin-bottom: 0.6rem;
    }

    .section-title {
      font-family: "DM Serif Display", Georgia, serif;
      font-size: clamp(1.75rem, 3.5vw, 2.35rem);
      font-weight: 400;
      margin: 0 0 0.75rem;
      line-height: 1.15;
    }

    .section-intro {
      color: var(--ink-soft);
      max-width: 38rem;
      margin: 0 0 2rem;
      font-size: 1.02rem;
    }

    /* ——— Importance ——— */
    .importance {
      background: var(--paper);
      border-block: 1px solid var(--line);
      padding: 4rem 0;
    }

    .importance-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1.25rem;
    }

    .importance-card {
      padding: 1.5rem;
      border-radius: var(--radius);
      border: 1px solid var(--line);
      background: var(--cream);
    }

    .importance-card h3 {
      margin: 0 0 0.5rem;
      font-size: 1.05rem;
      font-weight: 800;
    }

    .importance-card p {
      margin: 0;
      font-size: 0.92rem;
      color: var(--ink-soft);
    }

    .importance-num {
      font-family: "DM Serif Display", Georgia, serif;
      font-size: 2rem;
      color: rgba(26, 93, 26, 0.2);
      line-height: 1;
      margin-bottom: 0.75rem;
    }

    /* ——— Features ——— */
    .features-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1rem;
    }

    .feature {
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: var(--radius);
      padding: 1.35rem;
      transition: box-shadow 0.2s, transform 0.2s;
    }

    .feature:hover {
      box-shadow: var(--shadow);
      transform: translateY(-2px);
    }

    .feature-icon {
      width: 42px;
      height: 42px;
      border-radius: 12px;
      display: grid;
      place-items: center;
      font-size: 1.2rem;
      margin-bottom: 0.85rem;
      background: #ecfdf5;
    }

    .feature h3 {
      margin: 0 0 0.4rem;
      font-size: 1rem;
      font-weight: 800;
    }

    .feature p {
      margin: 0;
      font-size: 0.88rem;
      color: var(--ink-soft);
      line-height: 1.55;
    }

    /* ——— Vision / Mission ——— */
    .vm-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1.25rem;
    }

    .vm-card {
      padding: 2rem;
      border-radius: var(--radius);
      border: 1px solid var(--line);
    }

    .vm-card.vision {
      background: linear-gradient(135deg, #14532d 0%, #1a5d1a 55%, #166534 100%);
      color: #f0fdf4;
    }

    .vm-card.mission {
      background: var(--gold-soft);
      border-color: rgba(232, 163, 23, 0.3);
    }

    .vm-card h3 {
      margin: 0 0 0.75rem;
      font-family: "DM Serif Display", Georgia, serif;
      font-size: 1.65rem;
      font-weight: 400;
    }

    .vm-card p {
      margin: 0;
      font-size: 1rem;
      line-height: 1.65;
    }

    .vm-card.mission p { color: #5c4a1a; }

    .pull-quote {
      margin: 2.5rem 0 0;
      padding: 1.5rem 1.75rem;
      border-left: 4px solid var(--gold);
      background: var(--paper);
      border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
      font-family: "DM Serif Display", Georgia, serif;
      font-size: 1.25rem;
      font-style: italic;
      color: var(--ink-soft);
      line-height: 1.5;
    }

    /* ——— Values & traits ——— */
    .values-traits {
      background: var(--paper);
      border-block: 1px solid var(--line);
    }

    .vt-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 2.5rem;
    }

    .value-list {
      list-style: none;
      padding: 0;
      margin: 0;
      display: flex;
      flex-direction: column;
      gap: 0.85rem;
    }

    .value-list li {
      display: flex;
      gap: 0.85rem;
      align-items: flex-start;
      font-size: 0.95rem;
      color: var(--ink-soft);
    }

    .value-list strong {
      display: block;
      color: var(--ink);
      font-weight: 800;
      margin-bottom: 0.15rem;
    }

    .value-dot {
      flex-shrink: 0;
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: var(--green-bright);
      margin-top: 0.45rem;
    }

    .traits {
      display: flex;
      flex-wrap: wrap;
      gap: 0.55rem;
      margin-top: 0.5rem;
    }

    .trait {
      padding: 0.5rem 0.95rem;
      border-radius: 999px;
      font-size: 0.85rem;
      font-weight: 700;
      background: var(--cream);
      border: 1px solid var(--line);
      color: var(--green-deep);
    }

    .trait:nth-child(3n+2) { background: #ecfdf5; }
    .trait:nth-child(3n) { background: var(--gold-soft); border-color: rgba(232,163,23,0.25); }

    /* ——— How it works ——— */
    .steps {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1.25rem;
      counter-reset: step;
    }

    .step {
      position: relative;
      padding: 1.5rem 1.5rem 1.5rem 1.25rem;
      background: var(--paper);
      border: 1px solid var(--line);
      border-radius: var(--radius);
    }

    .step::before {
      counter-increment: step;
      content: counter(step, decimal-leading-zero);
      display: block;
      font-family: "DM Serif Display", Georgia, serif;
      font-size: 1.75rem;
      color: rgba(26, 93, 26, 0.25);
      margin-bottom: 0.5rem;
    }

    .step h3 {
      margin: 0 0 0.4rem;
      font-size: 1rem;
      font-weight: 800;
    }

    .step p {
      margin: 0;
      font-size: 0.88rem;
      color: var(--ink-soft);
    }

    /* ——— CTA ——— */
    .cta-block {
      background: linear-gradient(135deg, #14532d, #1a5d1a);
      color: #ecfdf5;
      border-radius: 24px;
      padding: 2.5rem;
      display: grid;
      grid-template-columns: 1.2fr 0.8fr;
      gap: 2rem;
      align-items: center;
      box-shadow: var(--shadow);
    }

    .cta-block h2 {
      font-family: "DM Serif Display", Georgia, serif;
      font-size: 2rem;
      font-weight: 400;
      margin: 0 0 0.6rem;
    }

    .cta-block p {
      margin: 0;
      opacity: 0.9;
      font-size: 0.95rem;
    }

    .cta-form {
      display: flex;
      flex-direction: column;
      gap: 0.6rem;
    }

    .cta-form input {
      width: 100%;
      padding: 0.75rem 1rem;
      border-radius: 10px;
      border: 1px solid rgba(255,255,255,0.2);
      background: rgba(255,255,255,0.1);
      color: #fff;
      font: inherit;
    }

    .cta-form input::placeholder { color: rgba(255,255,255,0.55); }

    .cta-form .btn-primary {
      background: var(--gold);
      color: #3d2e00;
      box-shadow: none;
      width: 100%;
    }

    .cta-form .btn-primary:hover { background: #f5b82a; }

    .cta-fine {
      font-size: 0.78rem;
      opacity: 0.7;
      margin-top: 0.35rem;
    }

    /* ——— Footer ——— */
    footer {
      padding: 2.5rem 0 3rem;
      color: var(--ink-muted);
      font-size: 0.88rem;
    }

    .footer-grid {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      gap: 2rem;
      flex-wrap: wrap;
      padding-top: 1.5rem;
      border-top: 1px solid var(--line);
    }

    .footer-links {
      display: flex;
      gap: 1.25rem;
      flex-wrap: wrap;
    }

    .footer-links a {
      color: var(--ink-soft);
      text-decoration: none;
      font-weight: 600;
    }

    .footer-links a:hover { color: var(--green); }

    /* ——— Responsive ——— */
    @media (max-width: 900px) {
      .nav-links a:not(.btn) { display: none; }

      .hero-grid,
      .importance-grid,
      .features-grid,
      .vm-grid,
      .vt-grid,
      .steps,
      .cta-block {
        grid-template-columns: 1fr;
      }

      .hero { padding-top: 2rem; }
      .phone-card { transform: none; }
      .float-tag.two { left: 0; }
    }
  </style>
</head>
<body>
  <div class="page-bg" aria-hidden="true"></div>

  <header class="nav">
    <div class="wrap nav-inner">
      <a class="brand" href="#">
        <img src="{{ asset('images/app_icon_logo.png') }}" alt="">
        AkwaabaFit
      </a>
      <nav class="nav-links">
        <a href="#why">Why it matters</a>
        <a href="#features">Features</a>
        <a href="#vision">Vision</a>
        <a href="#download" class="btn btn-primary">Get the app</a>
      </nav>
    </div>
  </header>

  <main>
    <!-- Hero -->
    <section class="hero">
      <div class="wrap hero-grid">
        <div>
          <!-- <div class="eyebrow">Made in Ghana, for Ghana</div> -->
          <h1>Welcome to wellness that <em>actually</em> fits your plate.</h1>
          <p class="hero-lead">
            AkwaabaFit is a mobile health app for everyday life here — track your steps, scan jollof and banku with AI, and get practical coaching that respects local food, weather, and busy schedules.
          </p>
          <div class="hero-ctas">
            <a class="btn btn-primary" href="#download">Download APK</a>
            <a class="btn btn-ghost" href="#features">See what it does</a>
          </div>
          <p class="hero-note">
            <strong>Akwaaba</strong> means “welcome” in Akan. The name is intentional: health tech should feel inviting, not intimidating. Runs on physical Android &amp; iPhone — built for real phones, real chop bars, real commutes.
          </p>
        </div>

        <div class="hero-visual">
          <div class="float-tag one">☀️ Accra weather + air tips</div>
          <div class="phone-card">
            <img src="{{ asset('images/app_icon_logo.png') }}" alt="AkwaabaFit app icon">
            <div class="phone-stats">
              <div class="stat-pill"><strong>8,420</strong><span>steps today</span></div>
              <div class="stat-pill"><strong>Waakye</strong><span>scanned &amp; logged</span></div>
              <div class="stat-pill"><strong>1,840</strong><span>kcal budget left</span></div>
              <div class="stat-pill"><strong>#4</strong><span>on leaderboard</span></div>
            </div>
          </div>
          <div class="float-tag two">Offline-first sync</div>
        </div>
      </div>
    </section>

    <!-- Why it matters -->
    <section class="importance" id="why">
      <div class="wrap">
        <p class="section-label">Why this app matters</p>
        <h2 class="section-title">Most fitness apps weren’t built for our kitchens.</h2>
        <p class="section-intro">
          Global calorie databases barely know waakye, kelewele, or banku. Gym-first apps assume equipment many people don’t use daily. AkwaabaFit closes that gap — not with generic Western meal plans, but with tools shaped around how Ghanaians actually eat, move, and live outdoors.
        </p>

        <div class="importance-grid">
          <article class="importance-card">
            <div class="importance-num">01</div>
            <h3>Food that looks like home</h3>
            <p>Scan Ghanaian dishes with a model trained on local meals, plus smart fallback when the photo is tricky. Logging shouldn’t start with “search for quinoa.”</p>
          </article>
          <article class="importance-card">
            <div class="importance-num">02</div>
            <h3>Movement without a gym membership</h3>
            <p>Your phone already counts steps. Stride turns walking into progress — goals, streaks, distance, and a Today / This month leaderboard.</p>
          </article>
          <article class="importance-card">
            <div class="importance-num">03</div>
            <h3>Health that respects the climate</h3>
            <p>Heat, humidity, and air quality change what’s safe outdoors. The app reads local weather and nudges you toward smarter choices — not fear, just context.</p>
          </article>
        </div>
      </div>
    </section>

    <!-- Features -->
    <section id="features">
      <div class="wrap">
        <p class="section-label">What the app does</p>
        <h2 class="section-title">One app. Home, meals, steps, safety.</h2>
        <p class="section-intro">
          Five main tabs keep things simple. You don’t need to be a fitness influencer — just someone trying to feel a bit better this week.
        </p>

        <div class="features-grid">
          <article class="feature">
            <div class="feature-icon">🏠</div>
            <h3>Home</h3>
            <p>Your daily snapshot: calories in vs burned, step progress, weather, water, and short dietitian-style advice tuned to your goals.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">📸</div>
            <h3>Meal scanner</h3>
            <p>Photograph your plate. Hybrid AI (Ghana-focused model + Gemini) identifies the dish and logs calories and macros to your history.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">🚶</div>
            <h3>Stride</h3>
            <p>Step tracking with background sync, hourly charts, calories burned estimate, and a leaderboard (today or this month). Works even if you never log a meal.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">📅</div>
            <h3>History</h3>
            <p>Browse meals by day with protein, carbs, and fat. Offline cache keeps your log when the network drops — sync when you’re back online.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">🛡️</div>
            <h3>Safety</h3>
            <p>Weather and air-quality hub with practical tips for walking and outdoor activity — built for real Ghana conditions.</p>
          </article>
          <article class="feature">
            <div class="feature-icon">👤</div>
            <h3>Profile</h3>
            <p>Set goals, weight, activity level, step targets, and calorie budgets. Your health profile powers everything the coach tells you.</p>
          </article>
        </div>
      </div>
    </section>

    <!-- Vision & Mission -->
    <section id="vision">
      <div class="wrap">
        <p class="section-label">Where we’re headed</p>
        <h2 class="section-title">Vision &amp; mission</h2>

        <div class="vm-grid">
          <article class="vm-card vision">
            <h3>Our vision</h3>
            <p>
              A Ghana where everyday wellness technology feels familiar — built around our foods, our routines, and our climate — not copied from abroad. We want people to open a health app and think, <em>“This was made for someone like me.”</em>
            </p>
          </article>
          <article class="vm-card mission">
            <h3>Our mission</h3>
            <p>
              To help Ghanaians stay active, understand what they eat, and make safer daily health choices through one mobile app that works even when the network is patchy. Practical guidance over perfection. Progress over guilt.
            </p>
          </article>
        </div>

        <blockquote class="pull-quote">
          “Health is not a luxury import. It should meet people where they already are — at the chop bar, on the trotro walk home, and in the choices they make every ordinary day.”
        </blockquote>
      </div>
    </section>

    <!-- Values & character -->
    <section class="values-traits">
      <div class="wrap">
        <div class="vt-grid">
          <div>
            <p class="section-label">Core values</p>
            <h2 class="section-title">What we stand for</h2>
            <ul class="value-list">
              <li>
                <span class="value-dot"></span>
                <div>
                  <strong>Culture first</strong>
                  Ghanaian dishes, local routines, and language that sounds like a thoughtful friend — not a lecture from overseas.
                </div>
              </li>
              <li>
                <span class="value-dot"></span>
                <div>
                  <strong>Practical over perfect</strong>
                  Reference nutrition and honest estimates — not lab-grade promises or shame-based dieting.
                </div>
              </li>
              <li>
                <span class="value-dot"></span>
                <div>
                  <strong>Accessibility</strong>
                  Offline-first where it counts. Free weather data. Designed for real phones on real networks.
                </div>
              </li>
              <li>
                <span class="value-dot"></span>
                <div>
                  <strong>Holistic wellness</strong>
                  Food, movement, hydration, and environment together — because health isn’t just calories on a chart.
                </div>
              </li>
              <li>
                <span class="value-dot"></span>
                <div>
                  <strong>Integrity</strong>
                  We don’t replace doctors. We don’t diagnose. We help people build awareness and better habits.
                </div>
              </li>
            </ul>
          </div>

          <div>
            <p class="section-label">Character traits</p>
            <h2 class="section-title">How the project shows up</h2>
            <p class="section-intro" style="margin-bottom: 1rem;">
              If AkwaabaFit were a person at your table, these are the qualities you’d notice:
            </p>
            <div class="traits">
              <span class="trait">Welcoming</span>
              <span class="trait">Grounded</span>
              <span class="trait">Patient</span>
              <span class="trait">Encouraging</span>
              <span class="trait">Locally rooted</span>
              <span class="trait">Resilient</span>
              <span class="trait">Honest</span>
              <span class="trait">Community-minded</span>
              <span class="trait">Curious</span>
              <span class="trait">Humble about limits</span>
            </div>
            <p style="margin-top: 1.5rem; font-size: 0.92rem; color: var(--ink-soft); line-height: 1.6;">
              Built by Reginald, Bernard, and Klenam as a final-year project — and shaped by feedback from people who actually live here. The tone is warm, not corporate. The tech is serious, but the voice stays human.
            </p>
          </div>
        </div>
      </div>
    </section>

    <!-- How it works -->
    <section>
      <div class="wrap">
        <p class="section-label">Getting started</p>
        <h2 class="section-title">How it works</h2>
        <div class="steps">
          <article class="step">
            <h3>Set up your profile</h3>
            <p>Tell us your goals, body metrics, and activity level. The app calculates calorie and macro targets that match your life — not a one-size template.</p>
          </article>
          <article class="step">
            <h3>Move &amp; eat normally</h3>
            <p>Walk with Stride running in the background. When you eat, scan the meal or log it manually. No need to do both every day — steps alone still count.</p>
          </article>
          <article class="step">
            <h3>Check in on Home</h3>
            <p>See progress, weather-aware tips, and coaching that ties your food and activity together. Small nudges, not nagging.</p>
          </article>
        </div>
      </div>
    </section>

    <!-- Download CTA -->
    <section id="download">
      <div class="wrap">
        <div class="cta-block">
          <div>
            <h2>Try AkwaabaFit</h2>
            <p>
              Download the Android beta APK or join the waitlist for updates. API lives at
              <strong>{{ parse_url(config('app.url'), PHP_URL_HOST) ?: 'api.tesnet.xyz' }}</strong> — Flutter app for physical devices only.
            </p>
            @if (config('landing.apk_url'))
            <p style="margin-top: 1rem;">
              <a class="btn btn-ghost" style="background: rgba(255,255,255,0.12); color: #fff; border-color: rgba(255,255,255,0.2);" href="{{ config('landing.apk_url') }}">Download APK</a>
            </p>
            @endif
          </div>
          @if (config('landing.beta_form_action'))
          <form class="cta-form" action="{{ config('landing.beta_form_action') }}" method="post">
            <input type="text" name="name" placeholder="Your name" required>
            <input type="email" name="email" placeholder="Email for beta updates" required>
            <button type="submit" class="btn btn-primary">Join the beta list</button>
            <p class="cta-fine">We’ll only email when new builds are ready. No spam.</p>
          </form>
          @else
          <div class="cta-form">
            <p class="cta-fine" style="opacity: 0.95;">Beta signup opens soon. For now, install the APK when it’s available or email us below.</p>
            <a class="btn btn-primary" href="mailto:{{ config('landing.support_email') }}">Email the team</a>
          </div>
          @endif
        </div>
      </div>
    </section>
  </main>

  <footer>
    <div class="wrap footer-grid">
      <div>
        <strong style="color: var(--ink);">AkwaabaFit</strong><br>
        Culturally adapted fitness &amp; nutrition for Ghanaians.<br>
        © 2026 · Reginald, Bernard &amp; Klenam
      </div>
      <div class="footer-links">
        <a href="mailto:{{ config('landing.support_email') }}">{{ config('landing.support_email') }}</a>
        <!-- <a href="{{ url('/api') }}" target="_blank" rel="noopener">API</a> -->
        <a href="#vision">Vision</a>
        <a href="#features">Features</a>
      </div>
    </div>
  </footer>
</body>
</html>
