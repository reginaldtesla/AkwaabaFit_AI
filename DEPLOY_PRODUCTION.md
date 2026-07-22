# Deploy AkwaabaFit to production (api.tesnet.xyz)

AkwaabaFit runs on **physical phones only** — emulators and simulators are blocked at app startup.

Use this checklist after pulling the latest code with health-assistant features.

## 1. Server — backend

```bash
cd /path/to/AkwaabaFitAIProject/Backend
git pull
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan db:seed --class=FoodNutritionItemSeeder --force
php artisan config:cache
php artisan route:cache
sudo systemctl reload php-fpm   # or restart Apache
```

Ensure `.env` on the server includes:

```env
APP_URL=https://api.tesnet.xyz
GEMINI_API_KEY=your_key
HUGGINGFACE_API_TOKEN=your_token
# Optional landing page CTAs:
# LANDING_APK_URL=https://drive.google.com/file/d/YOUR_FILE_ID/view?usp=drive_link

# Staff usage dashboard at /admin
# ADMIN_PASSWORD=your-strong-password
# LANDING_BETA_FORM_ACTION=
# LANDING_SUPPORT_EMAIL=support@akwaabafit.com
```

Visiting **https://api.tesnet.xyz/** (no `/api`) serves the AkwaabaFit marketing landing page. Mobile API routes stay under **/api/**.

After deploy, clear cached views if the homepage still shows the old Laravel welcome screen:

```bash
php artisan view:clear
php artisan route:clear
php artisan config:clear
php artisan config:cache
php artisan route:cache
```

## 2. Verify API

```bash
curl -s https://api.tesnet.xyz/api/app/version
curl -s https://api.tesnet.xyz/api/health/options
```

After login, dashboard should return `hydration`, `dietitianAdvice.bodyMetrics`, and profile fields:
`health_conditions`, `eating_pattern`, `life_stage`, `meal_source_preference`, `activity_context`.

## 3. Mobile — point at production

Default in `app_config.dart` is already `https://api.tesnet.xyz/api`.

Release build:

```bash
cd Mobile
flutter pub get
flutter build apk --release --dart-define=API_BASE_URL=https://api.tesnet.xyz/api
```

## 4. New registration flow (users)

On first sign-up, users complete **two steps**:

1. **Basics** — name, age, gender, height, weight, activity level  
2. **Health assistant** — weight goal, conditions, eating pattern (Ramadan/Lent/etc.), life stage (pregnancy/child care), chop bar vs home, daily routine (trotro/office), meal reminders  

This powers condition-aware coaching, Ghana step goals, water targets, and meal-time notifications.

## 5. Admin broadcast notifications

Staff can message every user from **https://api.tesnet.xyz/admin/broadcast** (after signing in with `ADMIN_PASSWORD`).

- Users see the message in the **app notification bell**
- The phone also shows a **system notification** when the app syncs (on open/resume, and periodically in the background step service)

For push while the app is fully closed, add Firebase:

```env
FIREBASE_CREDENTIALS=/absolute/path/to/firebase-service-account.json
FIREBASE_PROJECT_ID=your-firebase-project-id
```

Then install `google-services.json` in the Android app and register FCM device tokens (API: `POST /api/device-tokens`). Until then, sync-based delivery still covers inbox + tray for active users.

## 6. New API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health/options` | Profile pick-list values |
| GET | `/hydration/today` | Water progress |
| POST | `/hydration/log` | Log water (ml) |
| GET | `/nutrition/foods/search` | Manual meal search |
| GET | `/nutrition/recent` | Quick re-log |
| GET | `/accountability` | Partner code + linked partner |
| POST | `/accountability/link` | Link by partner code |
| DELETE | `/accountability/partner` | Unlink |

## 6. Smoke test

1. Register a new user → complete both profile steps  
2. Home → water card → add a glass  
3. History → manual log (pencil) → search waakye → log  
4. Profile → Accountability partner → copy code  
5. Dietitian coach → BMI, steps, condition tips visible  
