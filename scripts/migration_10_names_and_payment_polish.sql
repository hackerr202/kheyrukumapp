-- ==============================================================================
-- KHEYRIKUM MOBILE APP — MIGRATION 10: REAL NAMES, ETB PAYMENTS & BANK CHANNELS
-- ==============================================================================
-- Idempotent migration (safe to run multiple times in Supabase SQL Editor).
-- Addresses:
--   1. public.monthly_payments.verified_by_name + historical backfill from profiles
--   2. public.center_payment_channels table (RLS: active read, superadmin edit)
--   3. Live participant name lookup RPC (get_conversation_participant_names),
--      live participant_names refresh in create_direct_conversation, and ranking
--      real active accounts ahead of test placeholders in get_messageable_contacts
--   4. Optional commented SQL snippet to inspect/remove leftover test accounts
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PERSIST VERIFIED APPROVER NAME ON MONTHLY PAYMENTS (NO RAW UUID IN UI)
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('public.monthly_payments') IS NOT NULL THEN
        ALTER TABLE public.monthly_payments
        ADD COLUMN IF NOT EXISTS verified_by_name TEXT;

        UPDATE public.monthly_payments mp
        SET verified_by_name = COALESCE(NULLIF(TRIM(p.full_name), ''), p.email)
        FROM public.profiles p
        WHERE mp.reviewed_by IS NOT NULL
          AND mp.reviewed_by::text = p.id::text
          AND (mp.verified_by_name IS NULL OR TRIM(mp.verified_by_name) = '');
    ELSE
        RAISE NOTICE 'Skipping monthly_payments.verified_by_name (table missing).';
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. EDITABLE CENTER PAYMENT ACCOUNTS (CBE / TELEBIRR) WITH STRICT RLS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.center_payment_channels (
    id TEXT PRIMARY KEY,
    label_key TEXT NOT NULL,
    account_name TEXT NOT NULL DEFAULT '',
    account_number TEXT NOT NULL,
    display_order INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

ALTER TABLE public.center_payment_channels ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Active users read payment channels" ON public.center_payment_channels;
DROP POLICY IF EXISTS "Superadmins manage payment channels" ON public.center_payment_channels;

CREATE POLICY "Active users read payment channels"
ON public.center_payment_channels FOR SELECT TO authenticated
USING (public.is_active_user());

CREATE POLICY "Superadmins manage payment channels"
ON public.center_payment_channels FOR ALL TO authenticated
USING (public.is_superadmin())
WITH CHECK (public.is_superadmin());

-- Idempotent starter rows (edit real CBE & Telebirr numbers inside the app as Superadmin)
INSERT INTO public.center_payment_channels (
    id,
    label_key,
    account_name,
    account_number,
    display_order
)
VALUES
    ('cbe', 'cbeBankName', 'Kheyrukum Islamic Center', '1000123456789', 1),
    ('telebirr', 'telebirrAccountLabel', 'Kheyrukum Islamic Center', '+251 91 123 4567', 2)
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 3. LIVE PROFILE NAME RESOLUTION FOR DIRECT CHATS & REVIEWER LABELS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_conversation_participant_names(p_user_ids UUID[])
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    role TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NOT public.is_active_user() THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        p.id,
        COALESCE(NULLIF(TRIM(p.full_name), ''), p.email, 'User')::TEXT AS full_name,
        p.role::text AS role
    FROM public.profiles p
    WHERE p.id = ANY(COALESCE(p_user_ids, ARRAY[]::UUID[]))
      AND COALESCE(p.is_suspended, FALSE) = FALSE
      AND (
          p.id = auth.uid()
          OR public.is_admin()
          OR EXISTS (
              SELECT 1
              FROM public.get_messageable_contacts() mc
              WHERE mc.id = p.id
          )
          OR EXISTS (
              SELECT 1
              FROM public.conversations c
              WHERE (
                  auth.uid()::text = ANY(COALESCE(c.participant_ids, '{}'))
                  OR EXISTS (
                      SELECT 1
                      FROM public.conversation_participants cp_self
                      WHERE cp_self.conversation_id = c.id
                        AND cp_self.user_id = auth.uid()
                  )
              )
                AND (
                    p.id::text = ANY(COALESCE(c.participant_ids, '{}'))
                    OR EXISTS (
                        SELECT 1
                        FROM public.conversation_participants cp_other
                        WHERE cp_other.conversation_id = c.id
                          AND cp_other.user_id = p.id
                    )
                )
          )
      );
END;
$$;

REVOKE ALL ON FUNCTION public.get_conversation_participant_names(UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_conversation_participant_names(UUID[]) TO authenticated;

-- Rank real active profiles ahead of any leftover test/challenger accounts.
CREATE OR REPLACE FUNCTION public.get_messageable_contacts()
RETURNS TABLE (
    id UUID,
    full_name TEXT,
    email TEXT,
    role TEXT,
    avatar_url TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF NOT public.is_active_user() THEN
        RETURN;
    END IF;

    SELECT p.role::text INTO v_role
    FROM public.profiles p
    WHERE p.id = auth.uid();

    IF v_role IN ('superadmin', 'admin') THEN
        RETURN QUERY
        SELECT
            p.id,
            COALESCE(NULLIF(TRIM(p.full_name), ''), p.email, 'User')::TEXT AS full_name,
            COALESCE(p.email, '')::TEXT AS email,
            p.role::text AS role,
            p.avatar_url::TEXT AS avatar_url
        FROM public.profiles p
        WHERE p.id <> auth.uid()
          AND COALESCE(p.is_suspended, FALSE) = FALSE
        ORDER BY
            CASE
                WHEN LOWER(COALESCE(p.full_name, '')) LIKE '%challenger%'
                  OR LOWER(COALESCE(p.full_name, '')) LIKE 'test%' THEN 2
                ELSE 1
            END,
            CASE p.role::text
                WHEN 'superadmin' THEN 1
                WHEN 'admin' THEN 2
                WHEN 'teacher' THEN 3
                ELSE 4
            END,
            LOWER(COALESCE(p.full_name, p.email, ''));
        RETURN;
    END IF;

    IF v_role = 'teacher' THEN
        RETURN QUERY
        SELECT
            p.id,
            COALESCE(NULLIF(TRIM(p.full_name), ''), p.email, 'User')::TEXT AS full_name,
            COALESCE(p.email, '')::TEXT AS email,
            p.role::text AS role,
            p.avatar_url::TEXT AS avatar_url
        FROM public.profiles p
        WHERE p.id <> auth.uid()
          AND COALESCE(p.is_suspended, FALSE) = FALSE
          AND (
              p.role::text IN ('superadmin', 'admin', 'teacher')
              OR (
                  p.role::text = 'parent'
                  AND (
                      EXISTS (
                          SELECT 1
                          FROM public.parent_students ps
                          WHERE ps.parent_id = p.id
                            AND public.teaches_student(ps.student_id)
                      )
                      OR EXISTS (
                          SELECT 1
                          FROM public.students s
                          LEFT JOIN public.halaqahs h ON h.id = s.halaqah_id
                          LEFT JOIN public.profiles me ON me.id = auth.uid()
                          WHERE s.parent_id = p.id
                            AND (
                                h.teacher_id = auth.uid()
                                OR (me.halaqah_id IS NOT NULL AND s.halaqah_id = me.halaqah_id)
                            )
                      )
                  )
              )
          )
        ORDER BY
            CASE
                WHEN LOWER(COALESCE(p.full_name, '')) LIKE '%challenger%'
                  OR LOWER(COALESCE(p.full_name, '')) LIKE 'test%' THEN 2
                ELSE 1
            END,
            CASE p.role::text
                WHEN 'superadmin' THEN 1
                WHEN 'admin' THEN 2
                WHEN 'teacher' THEN 3
                ELSE 4
            END,
            LOWER(COALESCE(p.full_name, p.email, ''));
        RETURN;
    END IF;

    -- Parents (and fallback active role): active admins + teachers of their children's halaqahs
    RETURN QUERY
    SELECT
        p.id,
        COALESCE(NULLIF(TRIM(p.full_name), ''), p.email, 'User')::TEXT AS full_name,
        COALESCE(p.email, '')::TEXT AS email,
        p.role::text AS role,
        p.avatar_url::TEXT AS avatar_url
    FROM public.profiles p
    WHERE p.id <> auth.uid()
      AND COALESCE(p.is_suspended, FALSE) = FALSE
      AND (
          p.role::text IN ('superadmin', 'admin')
          OR (
              p.role::text = 'teacher'
              AND EXISTS (
                  SELECT 1
                  FROM public.students s
                  LEFT JOIN public.parent_students ps
                    ON ps.student_id = s.id AND ps.parent_id = auth.uid()
                  LEFT JOIN public.halaqahs h
                    ON h.id = s.halaqah_id
                  WHERE (ps.parent_id = auth.uid() OR s.parent_id = auth.uid())
                    AND (
                        h.teacher_id = p.id
                        OR (p.halaqah_id IS NOT NULL AND p.halaqah_id = s.halaqah_id)
                    )
              )
          )
      )
    ORDER BY
        CASE
            WHEN LOWER(COALESCE(p.full_name, '')) LIKE '%challenger%'
              OR LOWER(COALESCE(p.full_name, '')) LIKE 'test%' THEN 2
            ELSE 1
        END,
        CASE p.role::text
            WHEN 'superadmin' THEN 1
            WHEN 'admin' THEN 2
            WHEN 'teacher' THEN 3
            ELSE 4
        END,
        LOWER(COALESCE(p.full_name, p.email, ''));
END;
$$;

REVOKE ALL ON FUNCTION public.get_messageable_contacts() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_messageable_contacts() TO authenticated;

-- Always refresh participant_names (and stale titles) from live public.profiles
-- when reusing an existing 1-on-1 direct conversation.
CREATE OR REPLACE FUNCTION public.create_direct_conversation(
    p_other_user_id UUID,
    p_title TEXT DEFAULT NULL,
    p_halaqah_id UUID DEFAULT NULL,
    p_group_type TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller RECORD;
    v_other RECORD;
    v_existing RECORD;
    v_conv RECORD;
    v_allowed BOOLEAN := FALSE;
    v_group_type TEXT;
    v_title TEXT;
    v_halaqah_id UUID := NULL;
    v_caller_name TEXT;
    v_other_name TEXT;
BEGIN
    IF NOT public.is_active_user() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Active authenticated session required.');
    END IF;

    IF p_other_user_id IS NULL OR p_other_user_id = auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Valid recipient user is required.');
    END IF;

    SELECT id, role, full_name, email, is_suspended INTO v_caller
    FROM public.profiles
    WHERE id = auth.uid();

    SELECT id, role, full_name, email, is_suspended INTO v_other
    FROM public.profiles
    WHERE id = p_other_user_id;

    IF NOT FOUND OR COALESCE(v_other.is_suspended, FALSE) = TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'Recipient account is unavailable.');
    END IF;

    v_allowed := EXISTS (
        SELECT 1 FROM public.get_messageable_contacts() mc
        WHERE mc.id = p_other_user_id
    );

    IF NOT v_allowed THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not authorized to initiate this conversation.');
    END IF;

    IF p_halaqah_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.halaqahs WHERE id = p_halaqah_id
    ) THEN
        v_halaqah_id := p_halaqah_id;
    END IF;

    v_caller_name := COALESCE(NULLIF(TRIM(v_caller.full_name), ''), v_caller.email, 'User');
    v_other_name := COALESCE(NULLIF(TRIM(v_other.full_name), ''), v_other.email, 'User');

    -- Reuse any existing 1-on-1 conversation (checking both join table and participant_ids)
    SELECT c.* INTO v_existing
    FROM public.conversations c
    WHERE COALESCE(c.is_group, FALSE) = FALSE
      AND (
          (
              EXISTS (
                  SELECT 1 FROM public.conversation_participants cp1
                  WHERE cp1.conversation_id = c.id AND cp1.user_id = auth.uid()
              )
              AND EXISTS (
                  SELECT 1 FROM public.conversation_participants cp2
                  WHERE cp2.conversation_id = c.id AND cp2.user_id = p_other_user_id
              )
              AND (
                  SELECT COUNT(*) FROM public.conversation_participants cp_cnt
                  WHERE cp_cnt.conversation_id = c.id
              ) <= 2
          )
          OR (
              auth.uid()::text = ANY(COALESCE(c.participant_ids, '{}'))
              AND p_other_user_id::text = ANY(COALESCE(c.participant_ids, '{}'))
              AND COALESCE(array_length(c.participant_ids, 1), 0) <= 2
          )
      )
    ORDER BY c.last_message_time DESC NULLS LAST, c.created_at DESC
    LIMIT 1;

    IF FOUND THEN
        INSERT INTO public.conversation_participants (conversation_id, user_id)
        VALUES (v_existing.id, auth.uid()), (v_existing.id, p_other_user_id)
        ON CONFLICT (conversation_id, user_id) DO NOTHING;

        IF COALESCE(v_existing.participant_ids, '{}') IS DISTINCT FROM ARRAY[auth.uid()::text, p_other_user_id::text]
           OR COALESCE(v_existing.participant_names, '{}') IS DISTINCT FROM ARRAY[v_caller_name, v_other_name]
           OR COALESCE(NULLIF(TRIM(v_existing.title), ''), '') = '' THEN
            UPDATE public.conversations
            SET
                participant_ids = ARRAY[auth.uid()::text, p_other_user_id::text],
                participant_names = ARRAY[v_caller_name, v_other_name],
                title = CASE
                    WHEN COALESCE(NULLIF(TRIM(v_existing.title), ''), '') = ''
                      OR LOWER(v_existing.title) LIKE '%challenger%'
                      OR v_existing.title IN ('Center Director', 'Admin Director', 'Direct Chat')
                    THEN v_other_name
                    ELSE v_existing.title
                END
            WHERE id = v_existing.id
            RETURNING * INTO v_existing;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'conversation', to_jsonb(v_existing)
        );
    END IF;

    v_group_type := COALESCE(
        NULLIF(TRIM(COALESCE(p_group_type, '')), ''),
        CASE
            WHEN v_caller.role::text IN ('admin', 'superadmin')
              OR v_other.role::text IN ('admin', 'superadmin') THEN 'direct_admin'
            ELSE 'direct_teacher'
        END
    );
    v_title := COALESCE(
        NULLIF(TRIM(COALESCE(p_title, '')), ''),
        v_other_name
    );

    INSERT INTO public.conversations (
        title,
        is_group,
        participant_ids,
        participant_names,
        group_type,
        halaqah_id,
        last_message_time
    )
    VALUES (
        v_title,
        FALSE,
        ARRAY[auth.uid()::text, p_other_user_id::text],
        ARRAY[v_caller_name, v_other_name],
        v_group_type,
        v_halaqah_id,
        NOW()
    )
    RETURNING * INTO v_conv;

    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv.id, auth.uid()), (v_conv.id, p_other_user_id)
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'conversation', to_jsonb(v_conv)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_direct_conversation(UUID, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_direct_conversation(UUID, TEXT, UUID, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. OPTIONAL SAFE CLEANUP SNIPPET FOR LEFTOVER TEST ACCOUNTS (COMMENTED OUT)
-- ------------------------------------------------------------------------------
-- Run the SELECT first in Supabase SQL Editor to verify the exact row(s) before
-- uncommenting any DELETE statements. Deleting from auth.users cascades cleanly
-- to public.profiles when FK ON DELETE CASCADE is active; delete child test
-- rows or use admin_delete_user() if foreign keys block deletion.
--
-- SELECT id, full_name, email, role, created_at
-- FROM public.profiles
-- WHERE LOWER(full_name) LIKE '%challenger%'
--    OR LOWER(email) LIKE '%challenger%';
--
-- -- After verifying the exact UUID returned above:
-- -- DELETE FROM auth.users WHERE id = '<VERIFIED_TEST_USER_UUID>';
-- -- UPDATE public.conversations SET is_group = is_group WHERE FALSE; -- noop placeholder
