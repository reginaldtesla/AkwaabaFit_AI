AkwaabaFitAI Landing Page for Google Stitch
===========================================

Files:
- `index.html` — single-file static landing page (inline styles) ready to paste into Stitch.
- `images/` — app icon assets copied from `Mobile/assets/icon`, ready to upload into Stitch if needed.

Quick steps to use with Stitch:
1. Open https://stitch.withgoogle.com/ and create a new project/landing page.
2. Use the HTML editor and paste the contents of `index.html`.
3. Replace the following placeholders in the HTML before publishing:
   - `REPLACE_WITH_APK_URL` — URL where the APK will be hosted (e.g., `https://api.yourdomain.com/downloads/app-release.apk`)
   - `REPLACE_WITH_YOUR_DOMAIN` — your domain for API links
   - `REPLACE_FORM_ACTION` — a form endpoint to capture emails (e.g., Mailchimp, Getform, or your API endpoint)
   - Optional: replace the logo area with an image tag. Upload your icon to Stitch assets and replace the `.logo` div with:
     `<img src="/path/to/your/logo.png" alt="AkwaabaFitAI" style="width:88px;height:88px;border-radius:12px">`

Customizations you might want:
- Change colors in the `:root{}` block inside the `<style>` tag.
- Replace sample labels and screenshots with real images from `Mobile/assets`.

Notes:
- The page is intentionally small and dependency-free so Stitch's editor will accept it easily.
- Stitch will generate a public URL and QR code once you publish — use that for APK download and promos.

If you want, I can:
- Generate a version that includes an embedded APK download button that hosts the APK from your backend (requires a public URL).
- Extract the app icon from the repo and create an `index.html` that embeds it as base64.

