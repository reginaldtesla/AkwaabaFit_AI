# AkwaabaFit AI — Complete Project Report Source Document

**Purpose of this document:** Give this entire file to Google Gemini (or any AI) and ask it to write your **final year project report**, **chapter by chapter**, in academic style. It contains everything implemented in the project. Ask Gemini to cite limitations honestly, use Ghana context, and structure the report as: Abstract, Introduction, Literature Review, Methodology, System Design, Implementation, Testing, Results/Discussion, Conclusion, Future Work, References, Appendices.

**Project team:** Reginald, Bernard, Klenam (final year group project).

**Project title:** AkwaabaFit AI — A Culturally Adapted AI-Powered Fitness and Nutrition Mobile Application for Ghanaians.

---

## 1. Executive summary

AkwaabaFit AI is a cross-platform mobile health application paired with a REST API backend. It targets Ghanaians who want to track physical activity, log meals featuring local dishes, and access paid tele-dietetics (nutrition advice) from verified professionals. The mobile app is built with **Flutter**; the server uses **Laravel 12** with **Laravel Sanctum** authentication. Food recognition uses a custom **YOLOv8** object-detection model exported to **ONNX** and run **on-device** (offline-capable inference). Payments use **Paystack** in Ghana Cedis (GHS). Push notifications use **Firebase Cloud Messaging**. The system supports **offline-first** meal and profile sync via **SQLite** on the phone. An **admin web portal** approves dietitian applications and sets public listing data (rating, hourly rate, photo). The project is suitable for demonstration, academic defense, and beta testing; public App Store deployment would require additional production hardening.

---

## 2. Problem statement and motivation

Many fitness and nutrition apps are designed around Western foods, gym-centric workflows, and generic calorie databases. Ghanaian users eat dishes such as jollof rice, banku, waakye, fufu, kelewele, and kenkey—foods that are underrepresented in global nutrition APIs. Additionally, access to licensed dietitians can be limited or inconvenient. AkwaabaFit AI addresses:

- **Cultural relevance:** Food scanner trained on Ghanaian and common local dishes.
- **Accessibility:** Mobile-first, works with intermittent connectivity (offline cache + sync).
- **Professional guidance:** Tele-dietetics with booking, payment, and in-app chat.
- **Holistic wellness:** Steps, calories, macros, weather-aware dashboard, and meal history in one app.

The name “Akwaaba” means “welcome” in Akan—positioning the app as welcoming wellness technology for Ghana.

---

## 3. Project objectives

### Primary objectives (achieved)

1. Develop a secure user authentication and health profiling system.
2. Implement daily activity tracking (steps, goals, leaderboard).
3. Build an AI-powered food scanner that identifies local dishes from photos on the device.
4. Provide nutrition logging and history with calories and macronutrients (protein, carbs, fat).
5. Enable users to browse dietitians, pay for consultations, and chat during live sessions.
6. Allow dietitians to apply with verified documents; admins approve and publish listings.
7. Deliver a Laravel REST API and admin tools to support all mobile features.

### Secondary objectives (partially achieved or deferred)

- Real-time WebSocket chat (Reverb configured; mobile uses reliable HTTP polling + FCM).
- Portion-size estimation from images (deferred; macros are per reference serving).
- Public app store release (APK distribution possible; store pipeline not completed).
- Expanded food classes beyond 22 (architecture supports expansion via retraining).

---

## 4. Scope: what the system does and does not do

### In scope

- User registration, login, password reset, health profile onboarding.
- Dashboard: calories consumed vs burned, macro targets, steps, weather (OpenWeather), motivational insights.
- Stride tab: pedometer-based steps, background sync, hourly activity logging, daily leaderboard.
- Food scanner: camera/gallery → YOLOv8 ONNX detection → nutrition lookup → auto-log meal.
- Nutrition history by day with safety status labels and P/C/F display.
- Nutrition Advice tab: dietitian list, Paystack payment, ask-now or scheduled sessions, chat with session time rules.
- Dietitian in-app application (Ghana Card, certificate, photo, CV—all required).
- Profile management: avatar, goals, calorie/macro targets.
- Admin: review applications, approve with rating and hourly rate, download documents, advice oversight.
- Optional in-app update banner when server reports newer app version on Play/App Store.

### Out of scope (current version)

- Emergency medical diagnosis or clinical treatment.
- Wearable device integration (Apple Watch, etc.).
- Social community feed or group challenges.
- Full AI-generated workout video library.
- Laboratory-accurate macro measurement from photos (no gram estimation from image).
- 100% food coverage (only 22 trained classes).

---

## 5. Technology stack

| Layer | Technology | Role |
|-------|------------|------|
| Mobile UI | Flutter (Dart), Riverpod | Cross-platform iOS/Android app |
| Mobile ML | ONNX Runtime, YOLOv8 exported model | On-device food detection |
| Mobile storage | SQLite (sqflite), Flutter Secure Storage, SharedPreferences | Offline cache, tokens, dismiss flags |
| Mobile networking | Dio | REST API client |
| Mobile notifications | flutter_local_notifications, Firebase Messaging | Reminders and push |
| Mobile sensors | pedometer, camera, image_picker | Steps and food photos |
| Backend | Laravel 12, PHP 8.2+ | API, admin Blade views, webhooks |
| Auth | Laravel Sanctum (Bearer tokens) | Mobile API authentication |
| Database | MySQL | Users, meals, consultations, messages, dietitians |
| Payments | Paystack API + webhook (HMAC signature) | GHS consultation payments |
| Push (server) | Firebase Cloud Messaging (service account) | Advice notifications |
| Weather | OpenWeatherMap API | Dashboard weather |
| Realtime (optional) | Laravel Reverb (Pusher-compatible) | Config present; mobile polls messages |
| AI training | Python, Ultralytics YOLOv8 | Train/export food model |
| Testing (backend) | Pest/PHPUnit | 44 automated feature tests |
| CI | GitHub Actions | PHP 8.3–8.5 test workflow |

---

## 6. System architecture

### High-level architecture

The system follows a **client–server** architecture with **edge AI**:

1. **Flutter mobile app** — Presentation, local ONNX inference, SQLite offline store, sync outbox when online.
2. **Laravel API** — Business logic, authentication, payments, persistence, FCM dispatch, admin workflows.
3. **MySQL database** — Relational data for users, meals, steps, consultations, messages, food nutrition catalog, dietitian applications.
4. **Admin/advisor web** — Server-rendered pages on same Laravel app for staff and advisors.
5. **Third parties** — Paystack, Firebase, OpenWeather.

Data flow for food scan:

1. User captures image → ONNX model outputs class label + confidence.
2. App resolves nutrition via hybrid lookup: bundled JSON → SQLite cache → server API refresh.
3. Meal saved locally immediately; synced to server when authenticated and online.

Data flow for consultation:

1. User selects dietitian → Paystack initialize → user pays → webhook or verify updates payment status.
2. Consultation record stores scheduled time and session expiry (paid window + 2 hours).
3. Chat messages allowed only when session phase is **live** (after scheduled time for scheduled bookings).
4. Mobile polls message delta endpoint; FCM for push alerts.

### Mobile navigation structure

Bottom tabs: **Home** | **History** (nutrition) | **Stride** (activity) | **Advice** (tele-dietetics) | **Profile**.

Key screens: splash/auth, health profile onboarding, dashboard, AI scanner, nutrition history, activity tracking, daily leaderboard, tele-dietetics list, nutrition advice inbox, nutrition advice chat, dietitian application, profile settings, notifications modal.

---

## 7. Detailed feature documentation — Mobile app

### 7.1 Authentication and onboarding

- Register with email/password (API).
- Login/logout with Sanctum token stored in secure storage.
- Forgot password and reset password flows.
- Splash screen checks token and profile completion.
- Health profile screen collects height, weight, goals, dietary preferences—required before full app use.
- Offline: cached profile completion flag if API unreachable.

### 7.2 Home dashboard

- Fetches aggregated data from `GET /api/dashboard`.
- Shows user name, avatar, calorie goal progress (consumed vs target), net calories, burned calories.
- Macro display (protein, carbs, fat) with logic to estimate macros from calorie targets when meal rows lack gram fields.
- Steps today integrated from pedometer + server.
- OpenWeather integration for temperature and location label (default Accra if no GPS).
- AI-generated or rule-based insight text encouraging user behavior.
- Quick actions: open food scanner, navigate to advice, etc.
- Pull-to-refresh and connectivity-aware sync.

### 7.3 Stride (fitness / activity)

- Uses device pedometer for live step count.
- Background step service for continued counting.
- Syncs steps to server (`POST /api/steps/sync`).
- Activity screen shows today’s steps, goal, streak, calories estimate, distance, hourly bar chart.
- Hourly step upsert endpoint for chart accuracy.
- Daily leaderboard (`GET /api/leaderboard/daily`).
- Foreground notification preferences for step/calorie milestones.

### 7.4 Food scanner (AI)

- **Model:** YOLOv8n (nano) trained on merged Ghanaian food datasets, exported to ONNX opset 12 for mobile compatibility.
- **Input size:** 416×416 pixels.
- **Classes (22):** banku, beans, bread, burger, chicken, egg-pepper, fufu, hausa-koko, jollof, kelewele, kenkey, kokonte, koose, meat, nkate-cake, pasta, pizza, plantain, rice, salad, waakye, yam.
- **Confidence threshold:** 0.35 (detections below this are discarded).
- **UI:** Camera viewfinder or gallery pick; shows food name, confidence %, calories, iron, folate, safety status, P/C/F row, alternate detections.
- **Behavior:** On success, automatically logs meal to nutrition history and can navigate there; supports server nutrition refresh after initial result.
- **Failure cases:** No detection → user message about lighting/positioning; model load error → reinstall guidance.
- **Important limitation:** Macros are **reference values per serving** from nutrition database, **not** computed from portion size in the image.

### 7.5 Hybrid nutrition lookup

Priority order:

1. SQLite cache (from prior server sync).
2. Bundled `food_nutrition_defaults.json` in app assets.
3. Generic fallback (approx 350 kcal, 15g protein, 40g carbs, 12g fat) if class unknown.
4. When online: `GET /api/nutrition/food?class_name=...` refreshes and caches; full catalog via `GET /api/nutrition/foods`.

### 7.6 Nutrition history

- Meals grouped by day.
- Shows meal name, time, category, calories, safety badge (safe/moderate/etc.), macro row when available.
- Merges local SQLite meals with server history when online.
- Pull-to-refresh.

### 7.7 Nutrition advice (tele-dietetics)

- Lists approved dietitians with photo, name, specialty, rating, hourly rate in GHS.
- Pull-to-refresh on list.
- **Ask now** or **schedule** consultation.
- Paystack payment flow (initialize, redirect/verify, webhook on server).
- **My sessions** floating action → inbox of consultations.
- **Scheduled session rules:** Before scheduled time, session is `waiting`—chat returns HTTP 402. After start time until `session_expires_at` (scheduled start + 2 hours paid window), session is `live`—chat enabled. Then `ended`.
- Local notifications: 2 hours before, 30 minutes before, at start; instant notification when session becomes live if app open.
- Chat uses polling (`messages` and `messages/delta` endpoints) with rate limiting.
- Typing indicator endpoint (throttled).

### 7.8 Dietitian application (in-app)

- Full application form: personal details, Ghana Card, professional certificate upload, profile photo (camera/gallery), CV upload—all required.
- Submitted to API with multipart files; stored on server disk in transaction with rollback on failure.
- User can check application status (pending/approved/rejected).
- Entry from Profile and Advice tab (“Apply”).
- After admin approval, dietitian appears in public list with admin-set **rating** and **listed_hourly_rate** and **image URL**.

### 7.9 Profile

- View/edit profile fields, upload avatar.
- Set daily calorie goal and step goal (synced to server and local prefs).
- Sync pending offline data manually.
- Link to dietitian application.
- Removed UI elements: “Premium Member • ID” line, per user request.
- App display name: **AkwaabaFit** (not AkwaabaFIT_AI).

### 7.10 Offline-first design

- SQLite database stores: profile cache, meal cache, outbox queue for API writes, nutrition food catalog cache, step-related data.
- On connectivity restore: sync profile, meals, invalidate dashboard/history providers.
- App usable for scanning and local meal log without network; sync when back online.

### 7.11 Push notifications

- FCM device token registered with backend on login/connectivity.
- Used for advice messages and system notifications.
- Local notifications for consultation reminders and session start.

### 7.12 App update banner

- Public `GET /api/app/version?platform=android|ios&version=x.y.z`.
- Server env vars: latest version, min version, store URL per platform.
- If user version < latest, shows dismissible top banner with link to store (forced if below min version).

### 7.13 Branding

- Custom app icon (green wellness/plate motif) via flutter_launcher_icons.
- Primary greens: ~#1A5D1A, #0FBD74; gold accent for dietetics UI.

---

## 8. Detailed feature documentation — Backend API

### 8.1 Public endpoints

- `POST /api/register`, `POST /api/login`
- `POST /api/forgot-password`, `POST /api/reset-password`
- `POST /api/webhook/paystack` (signature verified)
- `GET /api/app/version` (platform + current version)

### 8.2 Protected endpoints (Bearer Sanctum)

- Profile: GET/PATCH profile, POST avatar
- Dashboard: GET dashboard
- Fitness: POST steps/sync, GET leaderboard, GET activity/today, POST activity/hourly/log
- Nutrition: POST nutrition/log, GET nutrition/history, GET nutrition/food, GET nutrition/foods
- Consultations: POST book, POST initiate, GET verify, GET my consultations
- Messages: GET/POST messages, GET delta, POST typing (rate limited)
- Dietitians: GET dietitians, GET/POST dietetics/application
- Devices: POST/DELETE FCM token
- Broadcasting client config for Reverb
- Advisor prefix routes for nutrition advisors using app as advisors

### 8.3 Consultation session service (core business logic)

- Computes phase: `waiting`, `live`, `ended`.
- Scheduled consultations: live only when `now >= scheduled_time` and before `session_expires_at`.
- Payment extends or creates consultation with Paystack reference.
- Messages rejected with 402 and explanatory message when not live.

### 8.4 Database entities (conceptual)

- users (health fields, goals, avatar, staff/advisor flags)
- meal_logs
- daily_step_logs, hourly_step_logs
- consultations, consultation_messages, consultation_activity_logs
- dietitian_applications (extended fields: documents, submitted_at, rating, listed_hourly_rate)
- food_nutrition_items (seeded from JSON)
- device_tokens

Migrations applied in sequence; seeder for food nutrition catalog.

### 8.5 File storage

- User avatars, dietitian application files (Ghana Card, certificate, CV, photo) on Laravel `public` disk with `storage:link`.
- Admin can download documents for review.

---

## 9. Admin and web portals

| Route | Purpose |
|-------|---------|
| /admin/login | Staff authentication |
| /admin/dietetics/unlock | Shared secret key unlock for review (env `DIETETICS_REVIEW_KEY`) |
| /admin/dietetics/applications | List pending/approved/rejected; approve with rating + hourly rate; reject; download files |
| /admin/advice | Staff consultation/chat oversight |
| /advisor/login | Advisor web login |
| /advisor/consultations | Advisor web chat |
| /paystack/return | Return URL after payment |

Approval of dietitian updates listing shown in mobile app (not hardcoded 5.0 stars or zero price).

---

## 10. AI / machine learning pipeline

### 10.1 Dataset and training

- Multiple Ghanaian food datasets merged (`merge_datasets.py`, `merge_all_datasets.py`) into `merged_v2`.
- Training script: `train.py` using Ultralytics YOLOv8n.
- Training parameters: image size 416, batch size configurable, up to 200 epochs, chunked training support for low-VRAM laptops, CPU fallback option.
- Validation metrics printed: **mAP50**, **mAP50-95**.
- Export: `python train.py finalize` → ONNX opset 12 for Flutter onnxruntime.

### 10.2 Reported training performance (from development)

During training (before training artifacts were removed from repo to save disk space), validation results were approximately:

- **mAP50:** ~0.75–0.78 (75–78% mean average precision at IoU 0.5)
- **mAP50-95:** ~0.48
- **Precision:** ~0.73
- **Recall:** ~0.72

These measure **detection of food class in images**, not macro nutrient accuracy.

### 10.3 Mobile inference

- Model file bundled: `food_v1.onnx` + `food_labels.json`.
- Post-processing: NMS, confidence filter, label mapping.
- No cloud inference required for classification (privacy and offline benefit).

### 10.4 Limitations of AI component

- Only 22 classes; unknown foods may map to wrong class or generic nutrition fallback.
- Per-scan confidence is not the same as global mAP.
- Lighting, angle, and mixed plates affect results.
- Nutrition values are lookup table, not regressed from pixels.

---

## 11. Security considerations

- Passwords hashed (Laravel defaults).
- API authentication via Sanctum tokens; logout invalidates client token usage pattern.
- Paystack webhook HMAC validation.
- Admin dietetics unlock key optional (should be disabled in production: `DIETETICS_ALLOW_SHARED_KEY=false`).
- HTTPS recommended for production; cleartext allowed in dev Android manifest.
- File upload validation on dietitian application.
- Rate limiting on chat endpoints (advice-chat-get, post, delta, typing).
- Environment secrets in `.env` (not committed): Paystack, FCM, OpenWeather, DB, APP_KEY.

**Gaps for production:** Rate limit login/register; privacy policy; formal security audit; object storage for multi-server deployments.

---

## 12. Testing and quality assurance

- **Backend:** 44 Pest feature tests passing—auth, profile, dashboard, steps, nutrition, consultations, scheduled sessions, messaging, dietitian applications, Paystack webhook, app version API, food nutrition lookup.
- **Mobile:** Unit test for API config; manual testing on physical device with ngrok/LAN API.
- **CI:** GitHub Actions runs `php artisan test` on PHP 8.3–8.5.

---

## 13. Development methodology and tools

- Agile/iterative development in Cursor IDE with AI assistance.
- Version control: Git.
- Local dev: XAMPP/Apache or `php artisan serve`, Flutter hot reload, ngrok for phone testing.
- API base URL injected at build time: `--dart-define=API_BASE_URL=...`
- Team of three; division of backend, mobile, and ML possible for report.

---

## 14. Implementation challenges and solutions

| Challenge | Solution |
|-----------|----------|
| GPU OOM during YOLO training | Reduced image size to 416, batch 2, chunked epochs, CPU fallback, memory flush callbacks |
| ONNX opset compatibility on mobile | Export with opset 12 |
| Offline meal logging | SQLite outbox + sync on reconnect |
| Scheduled chat starting at payment time | ConsultationSessionService with waiting/live/ended phases |
| ngrok browser warning | `ngrok-skip-browser-warning` header in app |
| localhost URLs in API responses | Client-side URL rewrite to configured API host |
| Dashboard macros zero when calories exist | Server and client estimate macros from calorie targets |
| Large repo size (datasets/runs) | Removed from working copy; documented in AI README for retrain |

---

## 15. Deployment and distribution status

- **Development:** Complete and demo-ready.
- **Beta:** Possible via APK (`flutter build apk --release`) with public API URL; friends install manually.
- **Production store:** Requires release signing, privacy policy, stable HTTPS host, live Paystack, production FCM.
- **iOS:** Requires Mac + Apple Developer + TestFlight for wide distribution.

---

## 16. Future work (for report conclusion)

1. Portion multiplier or manual meal edit after scan.
2. Expand food classes and retrain model; dietitian-validated nutrition table.
3. Native Reverb/WebSocket client for chat.
4. Play Store and App Store release with proper application ID and signing.
5. Redis/cache, S3 storage, horizontal scaling.
6. Login rate limiting and formal privacy/terms pages.
7. Barcode scanning for packaged foods.
8. Wearable integration and community features (if product vision expands).

---

## 17. Figures, diagrams, and screenshot placement (for Gemini)

**Instruction to Gemini:** Throughout the report, insert each figure below at the point indicated. Use this exact format in the document body:

```
[FIGURE X.X — PLACEHOLDER: Insert image here]
Caption: Figure X.X — [caption text from table below]
Source: AkwaabaFit AI project (authors, 2026)
```

Center the placeholder line in the Word document; the student will replace it with a screenshot or diagram. Refer to every figure in the paragraph **before** the placeholder (e.g. “As shown in Figure 5.4, the food scanner displays…”).

### 17.1 Chapter 1 — Introduction

| Figure | Place after section discussing… | What to insert (screenshot/diagram) | Suggested caption |
|--------|----------------------------------|-------------------------------------|-------------------|
| **Figure 1.1** | Problem statement / Ghana context | Collage or single photo: Ghanaian dishes (jollof, banku, waakye) **or** app splash/login screen | Figure 1.1 — Context for culturally adapted nutrition: local Ghanaian meals and the AkwaabaFit mobile entry screen |
| **Figure 1.2** | Project objectives | Simple diagram: three pillars — **Fitness**, **Nutrition (AI scan)**, **Tele-dietetics** | Figure 1.2 — High-level objectives of the AkwaabaFit AI system |

**[FIGURE 1.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 1.2 — PLACEHOLDER: Insert image here]**

---

### 17.2 Chapter 2 — Literature review

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 2.1** | Mobile health / similar apps | Table or mind-map graphic (draw in PowerPoint) comparing generic fitness apps vs culturally adapted apps | Figure 2.1 — Comparison of generic fitness applications and culturally localised health apps |
| **Figure 2.2** | Food recognition / YOLO | Stock diagram of object detection pipeline (image → model → class label) **or** YOLO architecture sketch | Figure 2.2 — Typical object-detection workflow used in food recognition systems |

**[FIGURE 2.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 2.2 — PLACEHOLDER: Insert image here]**

---

### 17.3 Chapter 3 — Methodology

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 3.1** | Development methodology | Agile iteration diagram (plan → develop → test → demo) | Figure 3.1 — Agile development approach used in the project |
| **Figure 3.2** | Tools and technologies | Table screenshot or infographic: Flutter, Laravel, MySQL, YOLOv8, Paystack, FCM | Figure 3.2 — Core technologies and tools employed |
| **Figure 3.3** | Use cases | **Use case diagram** (actor: User, Dietitian, Admin; use cases: scan meal, book advice, approve application, etc.) | Figure 3.3 — Use case diagram for AkwaabaFit AI |

**[FIGURE 3.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 3.2 — PLACEHOLDER: Insert image here]**

**[FIGURE 3.3 — PLACEHOLDER: Insert image here]**

---

### 17.4 Chapter 4 — System analysis and design

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 4.1** | Overall architecture | **System architecture diagram** (Mobile ↔ API ↔ MySQL; ONNX on device; Paystack; FCM) — use README mermaid or redraw in draw.io | Figure 4.1 — System architecture of AkwaabaFit AI |
| **Figure 4.2** | Database design | **ER diagram** (users, meal_logs, consultations, messages, dietitian_applications, food_nutrition_items) | Figure 4.2 — Entity-relationship diagram of the database |
| **Figure 4.3** | Mobile navigation | Screen-flow diagram: Splash → Auth → Tabs (Home, History, Stride, Advice, Profile) | Figure 4.3 — Mobile application screen flow |
| **Figure 4.4** | API design | Screenshot of API route list **or** sequence diagram: Login → Token → GET dashboard | Figure 4.4 — REST API authentication and data flow |
| **Figure 4.5** | Consultation session design | State diagram: consultation phases **waiting → live → ended** | Figure 4.5 — Consultation session state machine for scheduled nutrition advice |

**[FIGURE 4.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 4.2 — PLACEHOLDER: Insert image here]**

**[FIGURE 4.3 — PLACEHOLDER: Insert image here]**

**[FIGURE 4.4 — PLACEHOLDER: Insert image here]**

**[FIGURE 4.5 — PLACEHOLDER: Insert image here]**

---

### 17.5 Chapter 5 — Implementation (main screenshot chapter)

Place mobile screenshots in the order users experience the app.

| Figure | Place after section discussing… | What to insert (from phone emulator/device) | Suggested caption |
|--------|--------------------------------|---------------------------------------------|-------------------|
| **Figure 5.1** | Authentication | Login screen **and/or** registration screen | Figure 5.1 — User login and registration interface |
| **Figure 5.2** | Health profile | Health profile onboarding form (height, weight, goals) | Figure 5.2 — Health profile setup screen |
| **Figure 5.3** | Dashboard | Home dashboard showing calories, steps, weather, insight | Figure 5.3 — Home dashboard with daily wellness summary |
| **Figure 5.4** | Food scanner (camera) | Scanner viewfinder with camera active | Figure 5.4 — AI food scanner camera interface |
| **Figure 5.5** | Food scanner (result) | Scan result card: food name, confidence %, calories, P/C/F | Figure 5.5 — Food detection result with nutrition estimates |
| **Figure 5.6** | Nutrition history | History tab with meals grouped by day | Figure 5.6 — Nutrition history listing logged meals |
| **Figure 5.7** | Stride / activity | Stride tab: steps today, goal, hourly chart | Figure 5.7 — Activity tracking and step count display |
| **Figure 5.8** | Leaderboard | Daily leaderboard screen | Figure 5.8 — Daily steps leaderboard |
| **Figure 5.9** | Nutrition advice list | Advice tab: list of dietitians with photo, rating, rate | Figure 5.9 — Listed nutrition professionals for consultation booking |
| **Figure 5.10** | Paystack payment | Paystack checkout in browser **or** payment success return | Figure 5.10 — Paystack payment flow for nutrition advice session |
| **Figure 5.11** | Scheduled session waiting | Chat screen showing “session starts in…” / blocked before start | Figure 5.11 — Scheduled consultation waiting state before live chat |
| **Figure 5.12** | Live advice chat | Active chat with dietitian during live session | Figure 5.12 — Live nutrition advice chat interface |
| **Figure 5.13** | Dietitian application | In-app dietitian application form with document uploads | Figure 5.13 — Dietitian registration and document submission form |
| **Figure 5.14** | Profile | Profile screen with avatar and goals (no premium/ID line) | Figure 5.14 — User profile and goal settings |
| **Figure 5.15** | App branding | Home screen showing **AkwaabaFit** icon and name on device | Figure 5.15 — AkwaabaFit application icon and launcher name |
| **Figure 5.16** | Backend admin | Browser: admin dietetics applications review page | Figure 5.16 — Administrator review of dietitian applications |
| **Figure 5.17** | Approve dietitian | Admin approve form with rating and hourly rate fields | Figure 5.17 — Admin approval with listing rating and hourly rate |
| **Figure 5.18** | ML pipeline | Screenshot of training script terminal **or** diagram: dataset → YOLOv8 → ONNX → mobile | Figure 5.18 — Food model training and ONNX export pipeline |
| **Figure 5.19** | 22 food classes | Table or graphic listing the 22 detected food classes | Figure 5.19 — Food classes supported by the on-device detection model |

**[FIGURE 5.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.2 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.3 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.4 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.5 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.6 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.7 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.8 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.9 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.10 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.11 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.12 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.13 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.14 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.15 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.16 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.17 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.18 — PLACEHOLDER: Insert image here]**

**[FIGURE 5.19 — PLACEHOLDER: Insert image here]**

---

### 17.6 Chapter 6 — Testing

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 6.1** | Automated testing | Terminal screenshot: `php artisan test` — **44 passed** | Figure 6.1 — Backend automated test results (Pest/PHPUnit) |
| **Figure 6.2** | Manual test cases | Table: Test ID, feature, steps, expected, pass/fail (create in Word) | Figure 6.2 — Sample manual test case summary |
| **Figure 6.3** | Food scan accuracy demo | Table or bar chart: 5 test dishes — expected vs detected vs correct (Y/N) | Figure 6.3 — Manual food scanner accuracy evaluation on sample dishes |
| **Figure 6.4** | Paystack webhook test | Terminal or Postman showing webhook test **or** test output from ConsultationTest | Figure 6.4 — Paystack webhook verification testing |

**[FIGURE 6.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 6.2 — PLACEHOLDER: Insert image here]**

**[FIGURE 6.3 — PLACEHOLDER: Insert image here]**

**[FIGURE 6.4 — PLACEHOLDER: Insert image here]**

---

### 17.7 Chapter 7 — Results and discussion

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 7.1** | AI performance | Chart: mAP50 ~75–78%, precision/recall ~73% (from training) | Figure 7.1 — Food detection model validation metrics (mAP50) |
| **Figure 7.2** | Objectives achieved | Table mapping each objective to Achieved/Partial/Not with evidence | Figure 7.2 — Project objectives achievement summary |
| **Figure 7.3** | Limitations | Infographic: 22 classes, reference macros, internet for sync | Figure 7.3 — Summary of system limitations |

**[FIGURE 7.1 — PLACEHOLDER: Insert image here]**

**[FIGURE 7.2 — PLACEHOLDER: Insert image here]**

**[FIGURE 7.3 — PLACEHOLDER: Insert image here]**

---

### 17.8 Chapter 8 — Conclusion

| Figure | Place after section discussing… | What to insert | Suggested caption |
|--------|--------------------------------|----------------|-------------------|
| **Figure 8.1** | Future work | Roadmap timeline graphic (Phase 1 done → Phase 2 portion edit → Phase 3 store launch) | Figure 8.1 — Proposed future development roadmap |

**[FIGURE 8.1 — PLACEHOLDER: Insert image here]**

---

### 17.9 Appendix figures (optional duplicates)

| Figure | Content |
|--------|---------|
| **Figure A.1** | Full bottom navigation bar (all five tabs visible) |
| **Figure A.2** | Notifications modal / inbox |
| **Figure A.3** | Advisor web login or advisor chat (browser) |
| **Figure A.4** | Sample API JSON response (dashboard or nutrition/food) |
| **Figure A.5** | Installation steps screenshot (Android APK install prompt) |

**[FIGURE A.1 — PLACEHOLDER: Insert image here]**

**[FIGURE A.2 — PLACEHOLDER: Insert image here]**

**[FIGURE A.3 — PLACEHOLDER: Insert image here]**

**[FIGURE A.4 — PLACEHOLDER: Insert image here]**

**[FIGURE A.5 — PLACEHOLDER: Insert image here]**

---

### 17.10 List of figures (for report front matter)

Ask Gemini to generate a **List of Figures** page after the table of contents, listing Figure 1.1 through Figure 8.1 and Appendix figures with page numbers as “[page]” placeholders until final pagination.

**Total recommended figures: 35+ placeholders** (student may reduce to 20–25 if page limit is strict; minimum for defense: Figures 4.1, 5.3–5.12, 5.16, 6.1, 7.1).

### 17.11 Screenshot tips for the student (Reginald / team)

- Use **Android emulator** or **physical phone** at consistent resolution (1080×2400 or similar).
- Hide personal data (use test account names).
- Capture in **light mode** for print clarity.
- Export PNG; insert in Word with width ~12–15 cm.
- Number figures sequentially even if some appendix figures use “A” prefix.

---

## 18. Suggested report chapter outline for Gemini

Ask Gemini to expand each section to 800–2000 words as required by your institution. **Insert figures from Section 17 at the points listed in each chapter.**

1. **Chapter 1 — Introduction:** Background, problem, objectives, scope, Ghana relevance. **Figures 1.1–1.2.**
2. **Chapter 2 — Literature review:** Mobile health in Africa, food recognition, telehealth, Paystack mobile money, offline-first apps. **Figures 2.1–2.2.**
3. **Chapter 3 — Methodology:** Agile, tools, requirements gathering, use cases, diagrams (use case, DFD). **Figures 3.1–3.3.**
4. **Chapter 4 — System analysis and design:** Architecture, ER diagram, API design, mobile screen flow, security design. **Figures 4.1–4.5.**
5. **Chapter 5 — Implementation:** Laravel modules, Flutter features, ML pipeline, integrations. **Figures 5.1–5.19 (main screenshots).**
6. **Chapter 6 — Testing:** Test cases table, Pest results, manual test scenarios, sample scan accuracy table. **Figures 6.1–6.4.**
7. **Chapter 7 — Results and discussion:** What works, limitations (macros, 22 classes, mAP), comparison to objectives. **Figures 7.1–7.3.**
8. **Chapter 8 — Conclusion and recommendation:** Summary, contribution, future work. **Figure 8.1.**
9. **References:** Laravel, Flutter, Ultralytics YOLO, Paystack docs, etc.
10. **Appendices:** API endpoint list, sample JSON, extra screenshots. **Figures A.1–A.5.**

---

## 19. Sample viva/defense Q&A (for Gemini to weave into report or appendix)

**Q: What is innovative about your project?**  
A: Combination of Ghana-specific food ONNX on-device, offline sync, and integrated Paystack tele-dietetics in one Flutter app.

**Q: How accurate is the AI?**  
A: ~75–78% mAP50 on validation for food **classification**; app shows per-image **confidence**; nutrition macros are database reference values, not AI-predicted.

**Q: Why Flutter and Laravel?**  
A: Cross-platform mobile, fast API development, Sanctum for mobile tokens, rich ecosystem.

**Q: How do you handle no internet?**  
A: SQLite cache and outbox; scanner works offline; sync when online.

**Q: Is it production ready?**  
A: Ready for academic demo and beta; store and security hardening remain.

---

## 20. Prompt you can paste to Gemini after this document

```
You are helping write a final year BSc project report for "AkwaabaFit AI".

Use the entire document above as the single source of truth for what was built.
Write in formal academic English suitable for a Ghanaian university.
Include: Abstract (250 words), five keywords, Table of Contents, List of Figures, numbered chapters, and tables where helpful.

IMPORTANT — FIGURES:
- Use Section 17 "Figures, diagrams, and screenshot placement" for ALL figures.
- At each figure location, insert exactly:
  [FIGURE X.X — PLACEHOLDER: Insert image here]
  Caption: Figure X.X — [caption from Section 17]
  Source: AkwaabaFit AI project (authors, 2026)
- Refer to each figure in the text before the placeholder.
- Chapter 5 must include Figures 5.1 through 5.19 (mobile and admin screenshots).
- Chapter 4 must include architecture, ER, and screen-flow diagrams (Figures 4.1–4.5).

Be honest about limitations (22 food classes, reference macros, mAP not equal to user-facing "accuracy").
Do not invent features not described in the source document.
Target total length: [INSERT YOUR REQUIRED PAGE COUNT] pages at 12pt Times New Roman 1.5 spacing.
Cite technologies using APA 7th where appropriate.
End with a conclusion that maps each primary objective to achieved/not achieved status.
```

---

*End of report source document.*
