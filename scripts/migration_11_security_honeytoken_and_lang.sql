-- ==============================================================================
-- KHEYRIKUM MOBILE APP — MIGRATION 11: PROFILE LANGUAGE & HONEYTOKEN ALERTS
-- ==============================================================================
-- Idempotent migration (safe to run multiple times in Supabase SQL Editor).
-- Addresses:
--   1. public.profiles.preferred_language ('en' | 'ar' | 'am') for server-side
--      multilingual push alerts and reminders.
--   2. Trilingual security alerts inside public.export_financial_ledger()
--      honeytoken RPC when triggered.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. USER PREFERRED LANGUAGE COLUMN ON PUBLIC.PROFILES
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS preferred_language TEXT NOT NULL DEFAULT 'en';

UPDATE public.profiles
SET preferred_language = 'en'
WHERE preferred_language IS NULL
   OR preferred_language NOT IN ('en', 'ar', 'am');

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'profiles_preferred_language_check'
          AND conrelid = 'public.profiles'::regclass
    ) THEN
        ALTER TABLE public.profiles
        ADD CONSTRAINT profiles_preferred_language_check
        CHECK (preferred_language IN ('en', 'ar', 'am'));
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. TRILINGUAL HONEYTOKEN RPC: public.export_financial_ledger()
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.export_financial_ledger()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller RECORD;
    v_actor_label TEXT;
    v_admin RECORD;
    v_lang TEXT;
    v_title TEXT;
    v_body TEXT;
BEGIN
    SELECT id, full_name, email, role
    INTO v_caller
    FROM public.profiles
    WHERE id = auth.uid();

    v_actor_label := COALESCE(
        NULLIF(TRIM(v_caller.full_name), ''),
        v_caller.email,
        auth.uid()::text,
        'Unknown user'
    );

    -- Notify all active superadmins in their saved preferred_language
    IF to_regclass('public.notifications') IS NOT NULL THEN
        FOR v_admin IN
            SELECT id, COALESCE(preferred_language, 'en') AS lang
            FROM public.profiles
            WHERE role::text = 'superadmin'
              AND COALESCE(is_suspended, FALSE) = FALSE
        LOOP
            v_lang := LOWER(TRIM(COALESCE(v_admin.lang, 'en')));
            IF v_lang = 'ar' THEN
                v_title := 'تنبيه أمني عاجل';
                v_body := 'حاول المستخدم ' || v_actor_label || ' الوصول إلى سجل المالية المقيد (export_financial_ledger).';
            ELSIF v_lang = 'am' THEN
                v_title := 'አስቸኳይ የደህንነት ማንቂያ';
                v_body := v_actor_label || ' የተገደበውን የፋይናንስ መዝገብ (export_financial_ledger) ለማውጣት ሞክሯል።';
            ELSE
                v_title := 'Security Alert';
                v_body := v_actor_label || ' attempted to access restricted export_financial_ledger().';
            END IF;

            INSERT INTO public.notifications (
                user_id,
                title,
                body,
                type,
                data
            )
            VALUES (
                v_admin.id,
                v_title,
                v_body,
                'security_alert',
                jsonb_build_object(
                    'event', 'honeytoken_export_financial_ledger',
                    'actor_id', auth.uid(),
                    'actor_role', v_caller.role::text
                )
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', false,
        'message', 'Access denied: financial ledger export is disabled.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.export_financial_ledger() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.export_financial_ledger() TO authenticated;
