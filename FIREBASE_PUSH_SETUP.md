# Firebase Cloud Messaging (Free Spark Plan) Setup Guide

Kheyrukum uses Firebase Cloud Messaging (FCM) on the **100% free Firebase Spark plan** together with your Supabase Edge Function (`supabase/functions/send-push-notification/index.ts`) so parents, teachers, and directors receive closed-app push notifications for announcements, messages, attendance updates, homework assignments, absence requests, and tuition alerts.

Follow these 3 one-time steps to activate live push delivery with your Firebase project:

## Step 1: Create a Free Firebase Project & Android App
1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a project (stays on the free **Spark** plan — no billing card required for FCM).
2. Add an **Android app** with package name:
   `com.kheyrukum.portal.kheyrukummobileapp`
3. Download `google-services.json`.
4. Add it to your CI build in either of two ways:
   - **Recommended (keeps config out of git)**: Open GitHub → Repository **Settings → Secrets and variables → Actions** and add a repository secret named `GOOGLE_SERVICES_JSON` containing the full JSON (or base64-encoded JSON) of `google-services.json`.
   - **Or via repository folder**: Place the file at `android_config/google-services.json` and push to `main`.

## Step 2: Generate a Firebase Service Account Key
1. In Firebase Console, open **Project settings → Service accounts**.
2. Click **Generate new private key** and download the `.json` file.

## Step 3: Deploy the Supabase Edge Function & Set the Secret
1. Set your Firebase service account JSON in your Supabase project secrets (using the Supabase CLI or Dashboard → Edge Functions → Secrets):
   ```bash
   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/firebase-service-account.json)"
   ```
2. Deploy the free FCM HTTP v1 Edge Function:
   ```bash
   supabase functions deploy send-push-notification --no-verify-jwt
   ```
   *(Or deploy via the Supabase Dashboard Edge Functions editor by pasting `supabase/functions/send-push-notification/index.ts`.)*

3. Push or manually re-run the **Build Android APK** workflow on GitHub Actions so the APK bundles your `google-services.json`. Once installed on Android, users' FCM tokens automatically save to `public.user_device_tokens` (`provider = 'fcm'`) on sign-in.
