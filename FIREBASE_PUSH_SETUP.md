# Firebase Cloud Messaging (Free Spark Plan) Setup Guide

Kheyrukum uses Firebase Cloud Messaging (FCM) on the **100% free Firebase Spark plan** together with your hardened Supabase Edge Function (`supabase/functions/send-push-notification/index.ts`) so parents, teachers, and directors receive closed-app push notifications for announcements, messages, attendance updates, homework assignments, absence requests, and tuition alerts.

Follow these steps to deploy push delivery and signed release builds:

## Step 1: Firebase Project & Android App (`com.kheyrukum.portal`)
1. Go to the [Firebase Console](https://console.firebase.google.com/) and open/create your project (Spark free plan).
2. Register the Android app with exact package name:
   `com.kheyrukum.portal`
3. Download `google-services.json`.
4. Add the following repository secrets under **GitHub → Settings → Secrets and variables → Actions**:
   - `GOOGLE_SERVICES_JSON`: Full JSON (or base64 JSON) of `google-services.json`
   - `ANDROID_KEYSTORE_BASE64`: Base64-encoded release `.jks` keystore
   - `KEY_ALIAS`: Release keystore alias
   - `STORE_PASSWORD`: Release keystore password
   - `KEY_PASSWORD`: Release key password

## Step 2: Generate a Firebase Service Account Key & Webhook Secret
1. In Firebase Console, open **Project settings → Service accounts → Generate new private key** and download the JSON file.
2. Generate a strong random `PUSH_WEBHOOK_SECRET` (for Database Webhook → Edge Function authentication):
   ```bash
   openssl rand -hex 32
   ```

## Step 3: Apply Migration 06 & Deploy the Secured Edge Function
1. Run `scripts/migration_06_push_notifications.sql` in the **Supabase SQL Editor**.
2. Set the required Edge Function secrets in Supabase:
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/firebase-service-account.json)"
   supabase secrets set PUSH_WEBHOOK_SECRET="<YOUR_GENERATED_HEX_SECRET>"
   ```
3. Deploy the Edge Function **with JWT verification enabled** (do NOT pass `--no-verify-jwt`):
   ```bash
   supabase functions deploy send-push-notification
   ```
4. *(Optional Database Webhook for server-triggered rows inserted into `public.notifications`)*: In Supabase Dashboard → **Database → Webhooks**, create an `INSERT` webhook on `public.notifications` pointing to `send-push-notification` with HTTP header `x-webhook-secret: <YOUR_GENERATED_HEX_SECRET>`.
5. Push to `main` (or trigger **Build Signed Android APK** in GitHub Actions) to produce the signed release APK.
