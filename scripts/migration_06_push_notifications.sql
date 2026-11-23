-- ==============================================================================
-- KHEYRIKUM MOBILE APP — MIGRATION 06: PUSH NOTIFICATIONS & READ TRACKING
-- ==============================================================================
-- Idempotent migration ensuring FCM device tokens, notifications, per-user
-- global notification read receipts (notification_reads), and batch token
-- retrieval RPC exist with strict RLS & SECURITY DEFINER hardening.
-- Assumes Migration 05 helpers (public.is_active_user(), public.is_admin())
-- are already installed.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. USER DEVICE TOKENS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android',
    platform TEXT DEFAULT 'android',
    provider TEXT DEFAULT 'fcm',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, device_token)
);

ALTER TABLE public.user_device_tokens
    ADD COLUMN IF NOT EXISTS device_type TEXT DEFAULT 'android',
    ADD COLUMN IF NOT EXISTS platform TEXT DEFAULT 'android',
    ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'fcm',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.user_device_tokens'::regclass
          AND contype = 'u'
    ) THEN
        ALTER TABLE public.user_device_tokens
            ADD CONSTRAINT user_device_tokens_user_id_device_token_key
            UNIQUE (user_id, device_token);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user_provider
    ON public.user_device_tokens (user_id, provider);

CREATE INDEX IF NOT EXISTS idx_user_device_tokens_token
    ON public.user_device_tokens (device_token);

ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own device tokens" ON public.user_device_tokens;
CREATE POLICY "Users can manage their own device tokens"
ON public.user_device_tokens FOR ALL TO authenticated
USING (auth.uid() = user_id AND public.is_active_user())
WITH CHECK (auth.uid() = user_id AND public.is_active_user());

-- ------------------------------------------------------------------------------
-- 2. NOTIFICATIONS INBOX & AUDIT LOG
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'general',
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_created
    ON public.notifications (user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_global_created
    ON public.notifications (created_at DESC)
    WHERE user_id IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can mark own notifications read" ON public.notifications;

CREATE POLICY "Users can view their notifications"
ON public.notifications FOR SELECT TO authenticated
USING (public.is_active_user() AND (user_id = auth.uid() OR user_id IS NULL));

CREATE POLICY "Admins can insert notifications"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "Users can mark own notifications read"
ON public.notifications FOR UPDATE TO authenticated
USING (public.is_active_user() AND user_id = auth.uid())
WITH CHECK (public.is_active_user() AND user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 3. PER-USER READ TRACKING FOR GLOBAL (user_id IS NULL) NOTIFICATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notification_reads (
    notification_id UUID NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (notification_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_notification_reads_user_notif
    ON public.notification_reads (user_id, notification_id);

ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own notification read receipts" ON public.notification_reads;
CREATE POLICY "Users can manage own notification read receipts"
ON public.notification_reads FOR ALL TO authenticated
USING (auth.uid() = user_id AND public.is_active_user())
WITH CHECK (auth.uid() = user_id AND public.is_active_user());

-- ------------------------------------------------------------------------------
-- 4. BATCH TOKEN LOOKUP RPC FOR EDGE FUNCTION (AVOIDS URL LENGTH OVERFLOW)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fcm_tokens_for_users(p_user_ids UUID[])
RETURNS TABLE (
    user_id UUID,
    device_token TEXT,
    device_type TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT DISTINCT
        udt.user_id,
        udt.device_token,
        COALESCE(udt.platform, udt.device_type, 'android') AS device_type
    FROM public.user_device_tokens udt
    JOIN public.profiles p ON p.id = udt.user_id
    WHERE udt.user_id = ANY(COALESCE(p_user_ids, ARRAY[]::UUID[]))
      AND COALESCE(p.is_suspended, FALSE) = FALSE
      AND COALESCE(udt.provider, 'fcm') = 'fcm'
      AND NULLIF(BTRIM(udt.device_token), '') IS NOT NULL
      AND udt.device_token NOT LIKE 'dev\_%' ESCAPE '\';
$$;

REVOKE ALL ON FUNCTION public.get_fcm_tokens_for_users(UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_fcm_tokens_for_users(UUID[]) FROM anon;
REVOKE ALL ON FUNCTION public.get_fcm_tokens_for_users(UUID[]) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_fcm_tokens_for_users(UUID[]) TO service_role;

-- ==============================================================================
-- 5. SUPABASE DATABASE WEBHOOK SETUP (FOR SERVER-SIDE NOTIFICATIONS / CRON)
-- ==============================================================================
-- Whenever a server-side job (pg_cron tuition reminders, triggers, etc.) inserts
-- a row into public.notifications, wire a Supabase Database Webhook so closed-app
-- pushes fire reliably without relying on any client staying open:
--
-- Option A — Supabase Dashboard UI (Recommended, no Vault secrets needed in SQL):
--   1. Generate a webhook secret and set it on your Edge Function:
--        supabase secrets set PUSH_WEBHOOK_SECRET="<YOUR_RANDOM_HEX_SECRET>"
--   2. Dashboard -> Database -> Webhooks -> Create a new hook:
--        * Name:    dispatch_push_on_notification_insert
--        * Table:   public.notifications
--        * Events:  [x] Insert
--        * Type:    Supabase Edge Functions -> Edge Function: send-push-notification
--        * HTTP Headers:
--            Content-Type:     application/json
--            x-webhook-secret: <YOUR_RANDOM_HEX_SECRET>
--
-- Option B — SQL / pg_net (if pg_net extension is enabled; replace placeholders):
--   CREATE OR REPLACE FUNCTION public.notify_fcm_on_notification_insert()
--   RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
--   BEGIN
--       PERFORM net.http_post(
--           url := 'https://<YOUR_PROJECT_REF>.supabase.co/functions/v1/send-push-notification',
--           headers := jsonb_build_object(
--               'Content-Type', 'application/json',
--               'x-webhook-secret', '<YOUR_RANDOM_HEX_SECRET>'
--           ),
--           body := jsonb_build_object(
--               'type', 'INSERT',
--               'table', 'notifications',
--               'record', to_jsonb(NEW)
--           )
--       );
--       RETURN NEW;
--   END;
--   $$;
--   DROP TRIGGER IF EXISTS trg_notify_fcm_on_notification_insert ON public.notifications;
--   CREATE TRIGGER trg_notify_fcm_on_notification_insert
--   AFTER INSERT ON public.notifications
--   FOR EACH ROW EXECUTE FUNCTION public.notify_fcm_on_notification_insert();
-- ==============================================================================
