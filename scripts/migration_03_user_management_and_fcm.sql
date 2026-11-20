-- ==============================================================================
-- KHEYRUKUM MIGRATION 03: USER MANAGEMENT FIXES & FIREBASE FCM TOKEN SUPPORT
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. REPAIR public.profiles MISSING COLUMNS
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS halaqah_name TEXT;

UPDATE public.profiles
SET is_suspended = FALSE
WHERE is_suspended IS NULL;

-- Backfill teacher halaqah_id and halaqah_name from existing halaqahs assignments
UPDATE public.profiles p
SET halaqah_id = h.id,
    halaqah_name = h.name,
    updated_at = NOW()
FROM public.halaqahs h
WHERE h.teacher_id = p.id
  AND (p.halaqah_id IS DISTINCT FROM h.id OR p.halaqah_name IS DISTINCT FROM h.name);

-- ------------------------------------------------------------------------------
-- 2. RECURSION-SAFE ADMIN CHECK & PROFILES RLS POLICIES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles
        WHERE id = auth.uid()
          AND role = 'admin'
          AND COALESCE(is_suspended, FALSE) = FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins manage all profiles" ON public.profiles;
CREATE POLICY "Admins manage all profiles"
ON public.profiles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Ensure invitation_codes policy also uses public.is_admin() cleanly
DROP POLICY IF EXISTS "Admins manage invitation codes" ON public.invitation_codes;
CREATE POLICY "Admins manage invitation codes"
ON public.invitation_codes FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ------------------------------------------------------------------------------
-- 3. SOFTEN NON-CRITICAL INVITATION CODE FOREIGN KEYS FOR SAFE USER REMOVAL
-- ------------------------------------------------------------------------------
ALTER TABLE public.invitation_codes
DROP CONSTRAINT IF EXISTS invitation_codes_created_by_fkey;

ALTER TABLE public.invitation_codes
ADD CONSTRAINT invitation_codes_created_by_fkey
FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.invitation_codes
DROP CONSTRAINT IF EXISTS invitation_codes_used_by_fkey;

ALTER TABLE public.invitation_codes
ADD CONSTRAINT invitation_codes_used_by_fkey
FOREIGN KEY (used_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- ------------------------------------------------------------------------------
-- 4. SYNC consume_invitation_code SO NEW TEACHERS RECEIVE halaqah_id/halaqah_name
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.consume_invitation_code(
    p_code TEXT,
    p_user_id UUID,
    p_full_name TEXT,
    p_email TEXT,
    p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_invite RECORD;
    v_halaqah_name TEXT;
BEGIN
    SELECT * INTO v_invite
    FROM public.invitation_codes
    WHERE UPPER(code) = UPPER(TRIM(p_code))
      AND NOT is_used
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid, expired, or already used invitation code.');
    END IF;

    IF v_invite.role = 'teacher' AND v_invite.target_halaqah_id IS NOT NULL THEN
        SELECT name INTO v_halaqah_name
        FROM public.halaqahs
        WHERE id = v_invite.target_halaqah_id;
    END IF;

    INSERT INTO public.profiles (id, role, full_name, email, phone, is_suspended, halaqah_id, halaqah_name)
    VALUES (
        p_user_id,
        v_invite.role,
        p_full_name,
        p_email,
        p_phone,
        FALSE,
        CASE WHEN v_invite.role = 'teacher' THEN v_invite.target_halaqah_id ELSE NULL END,
        CASE WHEN v_invite.role = 'teacher' THEN v_halaqah_name ELSE NULL END
    )
    ON CONFLICT (id) DO UPDATE
    SET role = v_invite.role,
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        is_suspended = FALSE,
        halaqah_id = COALESCE(EXCLUDED.halaqah_id, public.profiles.halaqah_id),
        halaqah_name = COALESCE(EXCLUDED.halaqah_name, public.profiles.halaqah_name),
        updated_at = NOW();

    IF v_invite.role = 'parent' AND v_invite.linked_student_id IS NOT NULL THEN
        INSERT INTO public.parent_students (parent_id, student_id)
        VALUES (p_user_id, v_invite.linked_student_id)
        ON CONFLICT DO NOTHING;
    END IF;

    IF v_invite.role = 'teacher' AND v_invite.target_halaqah_id IS NOT NULL THEN
        UPDATE public.halaqahs
        SET teacher_id = p_user_id
        WHERE id = v_invite.target_halaqah_id;
    END IF;

    UPDATE public.invitation_codes
    SET is_used = TRUE,
        used_by = p_user_id,
        used_at = NOW()
    WHERE id = v_invite.id;

    RETURN jsonb_build_object(
        'success', true,
        'role', v_invite.role,
        'message', 'Registration completed successfully.'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. ATOMIC ADMIN RPC: ASSIGN OR UNASSIGN TEACHER HALAQAH
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_assign_teacher_halaqah(
    p_teacher_id UUID,
    p_halaqah_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_halaqah_name TEXT;
    v_prev_teacher_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only center administrators can assign study circles.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_teacher_id AND role = 'teacher') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Teacher profile not found.');
    END IF;

    -- Clear this teacher from any previous halaqah they led
    UPDATE public.halaqahs
    SET teacher_id = NULL
    WHERE teacher_id = p_teacher_id;

    IF p_halaqah_id IS NULL THEN
        UPDATE public.profiles
        SET halaqah_id = NULL,
            halaqah_name = NULL,
            updated_at = NOW()
        WHERE id = p_teacher_id;

        RETURN jsonb_build_object(
            'success', true,
            'halaqah_id', NULL,
            'halaqah_name', NULL,
            'message', 'Teacher unassigned from study circle.'
        );
    END IF;

    SELECT name, teacher_id INTO v_halaqah_name, v_prev_teacher_id
    FROM public.halaqahs
    WHERE id = p_halaqah_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Selected study circle was not found.');
    END IF;

    IF v_prev_teacher_id IS NOT NULL AND v_prev_teacher_id <> p_teacher_id THEN
        UPDATE public.profiles
        SET halaqah_id = NULL,
            halaqah_name = NULL,
            updated_at = NOW()
        WHERE id = v_prev_teacher_id
          AND halaqah_id = p_halaqah_id;
    END IF;

    UPDATE public.halaqahs
    SET teacher_id = p_teacher_id
    WHERE id = p_halaqah_id;

    UPDATE public.profiles
    SET halaqah_id = p_halaqah_id,
        halaqah_name = v_halaqah_name,
        updated_at = NOW()
    WHERE id = p_teacher_id;

    RETURN jsonb_build_object(
        'success', true,
        'halaqah_id', p_halaqah_id,
        'halaqah_name', v_halaqah_name,
        'message', 'Study circle assigned successfully.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_assign_teacher_halaqah(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assign_teacher_halaqah(UUID, UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 6. ATOMIC ADMIN RPC: PERMANENTLY REMOVE USER & CLEAN DEPENDENT REFERENCES
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_target RECORD;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only center administrators can remove users.');
    END IF;

    IF p_user_id = auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'You cannot remove your own active administrator account.');
    END IF;

    SELECT id, role, email, full_name INTO v_target
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'User account not found.');
    END IF;

    IF LOWER(COALESCE(v_target.email, '')) = 'admin@kheyrukum.com' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Primary administrator account cannot be removed.');
    END IF;

    -- Nullify nullable references
    UPDATE public.invitation_codes SET used_by = NULL WHERE used_by = p_user_id;
    UPDATE public.invitation_codes SET created_by = NULL WHERE created_by = p_user_id;
    UPDATE public.halaqahs SET teacher_id = NULL WHERE teacher_id = p_user_id;
    UPDATE public.announcements SET author_id = NULL WHERE author_id = p_user_id;

    -- Remove non-nullable referencing rows in active tables
    DELETE FROM public.messages WHERE sender_id = p_user_id;
    DELETE FROM public.hifz_records WHERE teacher_id = p_user_id;
    DELETE FROM public.homework_assignments WHERE teacher_id = p_user_id;

    -- Defensive cleanup for optional schema tables if deployed
    IF to_regclass('public.homework_submissions') IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'homework_submissions' AND column_name = 'parent_id'
        ) THEN
            EXECUTE 'UPDATE public.homework_submissions SET parent_id = NULL WHERE parent_id = $1' USING p_user_id;
        END IF;
    END IF;
    IF to_regclass('public.monthly_payments') IS NOT NULL THEN
        EXECUTE 'UPDATE public.monthly_payments SET reviewed_by = NULL WHERE reviewed_by = $1' USING p_user_id;
        EXECUTE 'DELETE FROM public.monthly_payments WHERE parent_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.weekly_reports') IS NOT NULL THEN
        EXECUTE 'UPDATE public.weekly_reports SET teacher_id = NULL WHERE teacher_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.student_attendance') IS NOT NULL THEN
        EXECUTE 'UPDATE public.student_attendance SET teacher_id = NULL WHERE teacher_id = $1' USING p_user_id;
    END IF;
    IF to_regclass('public.absence_requests') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.absence_requests WHERE parent_id = $1' USING p_user_id;
    END IF;

    -- Delete profile (cascades conversation_participants, parent_students, user_device_tokens, announcement_reads)
    DELETE FROM public.profiles WHERE id = p_user_id;

    -- Attempt cleanup in Supabase Auth so email cannot re-login or linger
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN jsonb_build_object(
        'success', true,
        'deleted_user_id', p_user_id,
        'message', 'User account permanently removed.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_delete_user(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_user(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 7. FIREBASE CLOUD MESSAGING TOKEN METADATA ON user_device_tokens
-- ------------------------------------------------------------------------------
ALTER TABLE public.user_device_tokens
ADD COLUMN IF NOT EXISTS provider TEXT DEFAULT 'fcm';

UPDATE public.user_device_tokens
SET provider = 'local'
WHERE device_token LIKE 'dev\_%' ESCAPE '\'
  AND (provider IS NULL OR provider = 'fcm');

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
