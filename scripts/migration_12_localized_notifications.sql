-- ==============================================================================
-- KHEYRIKUM MOBILE APP — MIGRATION 12: LOCALIZED PUSH & SERVER REMINDERS
-- ==============================================================================
-- Idempotent migration (safe to run multiple times in Supabase SQL Editor).
-- Addresses:
--   1. public.get_fcm_tokens_with_lang(p_user_ids UUID[]) returning
--      (user_id, device_token, device_type, preferred_language) in one RPC call.
--   2. public.dispatch_due_monthly_fee_reminders() rendering monthly fee
--      notifications in each parent's preferred_language ('en' | 'ar' | 'am')
--      with ETB/بر/ብር currency and template metadata in public.notifications.data.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. BATCH FCM TOKEN + PREFERRED LANGUAGE LOOKUP RPC FOR EDGE FUNCTION
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_fcm_tokens_with_lang(p_user_ids UUID[])
RETURNS TABLE (
    user_id UUID,
    device_token TEXT,
    device_type TEXT,
    preferred_language TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT DISTINCT
        udt.user_id,
        udt.device_token,
        COALESCE(udt.platform, udt.device_type, 'android') AS device_type,
        COALESCE(NULLIF(LOWER(BTRIM(p.preferred_language)), ''), 'en') AS preferred_language
    FROM public.user_device_tokens udt
    JOIN public.profiles p ON p.id = udt.user_id
    WHERE udt.user_id = ANY(COALESCE(p_user_ids, ARRAY[]::UUID[]))
      AND COALESCE(p.is_suspended, FALSE) = FALSE
      AND COALESCE(udt.provider, 'fcm') = 'fcm'
      AND NULLIF(BTRIM(udt.device_token), '') IS NOT NULL
      AND udt.device_token NOT LIKE 'dev\_%' ESCAPE '\';
$$;

REVOKE ALL ON FUNCTION public.get_fcm_tokens_with_lang(UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_fcm_tokens_with_lang(UUID[]) FROM anon;
REVOKE ALL ON FUNCTION public.get_fcm_tokens_with_lang(UUID[]) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.get_fcm_tokens_with_lang(UUID[]) TO service_role;

-- ------------------------------------------------------------------------------
-- 2. LOCALIZED MONTHLY TUITION REMINDER DISPATCHER (EN / AR / AM + METADATA)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.dispatch_due_monthly_fee_reminders()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_db_role TEXT;
    v_jwt_role TEXT;
    v_month_key TEXT;
    v_count INT := 0;
BEGIN
    v_db_role := current_setting('role', true);
    v_jwt_role := COALESCE(
        NULLIF(current_setting('request.jwt.claims', true), '')::jsonb->>'role',
        NULLIF(current_setting('request.jwt.claim.role', true), ''),
        v_db_role
    );

    IF NOT (
        v_jwt_role = 'service_role'
        OR (auth.uid() IS NULL AND COALESCE(v_jwt_role, '') NOT IN ('anon', 'authenticated'))
        OR public.is_superadmin()
    ) THEN
        RAISE EXCEPTION 'Access denied: only system cron or superadmins may dispatch monthly fee reminders.';
    END IF;

    v_month_key := to_char(CURRENT_DATE, 'YYYY-MM');

    WITH due_rows AS (
        UPDATE public.monthly_payments mp
        SET last_reminded_month = v_month_key,
            updated_at = NOW()
        WHERE mp.status IN ('pending', 'overdue', 'rejected')
          AND COALESCE(mp.fee_start_date, mp.due_date, CURRENT_DATE) <= CURRENT_DATE
          AND EXTRACT(DAY FROM COALESCE(mp.fee_start_date, mp.due_date, CURRENT_DATE)) = EXTRACT(DAY FROM CURRENT_DATE)
          AND COALESCE(mp.last_reminded_month, '') <> v_month_key
        RETURNING mp.id, mp.parent_id, mp.student_id, mp.month_year, mp.amount
    ),
    inserted_notifs AS (
        INSERT INTO public.notifications (user_id, title, body, type, data)
        SELECT
            dr.parent_id,
            CASE LOWER(TRIM(COALESCE(pr.preferred_language, 'en')))
                WHEN 'ar' THEN 'تذكير بالرسوم الشهرية 💳'
                WHEN 'am' THEN 'ወርሃዊ የትምህርት ክፍያ ማስታወሻ 💳'
                ELSE 'Monthly Tuition Reminder 💳'
            END AS title,
            CASE LOWER(TRIM(COALESCE(pr.preferred_language, 'en')))
                WHEN 'ar' THEN format(
                    'تستحق رسوم الطالب %s لشهر %s بمبلغ %s بر. يرجى السداد ورفع إيصال التحويل.',
                    COALESCE(s.full_name, 'ابنكم'),
                    dr.month_year,
                    round(dr.amount, 0)::text
                )
                WHEN 'am' THEN format(
                    'የ%s የ%s ወርሃዊ ክፍያ (%s ብር) ደርሷል። እባክዎ ከፍለው ደረሰኙን ይስቀሉ።',
                    COALESCE(s.full_name, 'ልጅዎ'),
                    dr.month_year,
                    round(dr.amount, 0)::text
                )
                ELSE format(
                    'Tuition for %s (%s — %s ETB) is due. Please submit your payment and upload your receipt.',
                    COALESCE(s.full_name, 'your child'),
                    dr.month_year,
                    round(dr.amount, 0)::text
                )
            END AS body,
            'payment_reminder',
            jsonb_build_object(
                'payment_id', dr.id,
                'student_id', dr.student_id,
                'month', dr.month_year,
                'template_key', 'monthly_tuition_reminder',
                'params', jsonb_build_object(
                    'student_name', COALESCE(s.full_name, ''),
                    'month', dr.month_year,
                    'amount', round(dr.amount, 0)::text
                )
            )
        FROM due_rows dr
        LEFT JOIN public.students s ON s.id = dr.student_id
        LEFT JOIN public.profiles pr ON pr.id = dr.parent_id
        WHERE dr.parent_id IS NOT NULL
        RETURNING id
    )
    SELECT COUNT(*) INTO v_count FROM inserted_notifs;

    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_due_monthly_fee_reminders() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.dispatch_due_monthly_fee_reminders() FROM anon;
GRANT EXECUTE ON FUNCTION public.dispatch_due_monthly_fee_reminders() TO authenticated, service_role;
