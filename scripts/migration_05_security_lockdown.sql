-- ==============================================================================
-- KHEYRUKUM MIGRATION 05: COMPREHENSIVE SECURITY & PRIVACY LOCKDOWN
-- ==============================================================================
-- Idempotent PostgreSQL / Supabase migration resolving P0/P1/P2 audit findings:
--   P0-04 : Lock down public.profiles (trigger + scoped SELECT/UPDATE RLS)
--   P0-05 : Harden public.consume_invitation_code (bind to auth.uid(), REVOKE PUBLIC)
--   P0-06 : Harden public.generate_invitation_code (is_admin(), pgcrypto)
--   P0-07 : Remove anon invitation_codes dump + add validate_invitation_code RPC
--   P0-08 : Lock down public.parent_students writes strictly to public.is_admin()
--   P0-09 : Prevent parent payment self-approval + isolate financial data from admin
--   P0-10 : Convert sensitive Storage buckets to private + path-scoped Storage RLS
--   P0-11 : Enforce public.is_active_user() (is_suspended = FALSE) across all RLS
--   P0-12 : Replace legacy inline role='admin' policies with public.is_admin()
--   P0-13 : Lock down conversation_participants / conversations + safe DM RPC
--   P0-14 : Harden academic tables (hifz, attendance, reports, homework, absence)
--   P0-17 : Protect superadmin/admin accounts in admin_delete_user & admin_set_user_role
--   P2-08 : Enforce SET search_path = public, pg_temp across all SECURITY DEFINER functions
--   P2-09 : Restrict announcements SELECT to active authenticated users by audience
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ------------------------------------------------------------------------------
-- 1. SECURITY PREDICATES (STABLE SECURITY DEFINER, SET search_path = public, pg_temp)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_active_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT auth.uid() IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM public.profiles
           WHERE id = auth.uid()
             AND COALESCE(is_suspended, FALSE) = FALSE
       );
$$;

CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT auth.uid() IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM public.profiles
           WHERE id = auth.uid()
             AND role::text = 'superadmin'
             AND COALESCE(is_suspended, FALSE) = FALSE
       );
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT auth.uid() IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM public.profiles
           WHERE id = auth.uid()
             AND role::text IN ('admin', 'superadmin')
             AND COALESCE(is_suspended, FALSE) = FALSE
       );
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT role::text
    FROM public.profiles
    WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_teacher()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT auth.uid() IS NOT NULL
       AND EXISTS (
           SELECT 1
           FROM public.profiles
           WHERE id = auth.uid()
             AND role::text = 'teacher'
             AND COALESCE(is_suspended, FALSE) = FALSE
       );
$$;

-- Checks whether caller (teacher/admin) teaches or manages a student
CREATE OR REPLACE FUNCTION public.teaches_student(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.is_teacher()
       AND EXISTS (
           SELECT 1
           FROM public.students s
           LEFT JOIN public.halaqahs h ON h.id = s.halaqah_id
           LEFT JOIN public.profiles caller ON caller.id = auth.uid()
           WHERE s.id = p_student_id
             AND (
                 h.teacher_id = auth.uid()
                 OR (caller.halaqah_id IS NOT NULL AND s.halaqah_id = caller.halaqah_id)
             )
       );
$$;

CREATE OR REPLACE FUNCTION public.teaches_halaqah(p_halaqah_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.is_teacher()
       AND EXISTS (
           SELECT 1
           FROM public.halaqahs h
           LEFT JOIN public.profiles caller ON caller.id = auth.uid()
           WHERE h.id = p_halaqah_id
             AND (
                 h.teacher_id = auth.uid()
                 OR caller.halaqah_id = h.id
             )
       );
$$;

-- Scoped profile visibility: self, admins, active school staff directory (teachers/directors),
-- parents of caller's assigned circle students, or shared conversation participants.
CREATE OR REPLACE FUNCTION public.can_view_profile(target_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.is_active_user()
       AND (
           target_id = auth.uid()
           OR public.is_admin()
           OR EXISTS (
               SELECT 1
               FROM public.profiles tp
               WHERE tp.id = target_id
                 AND tp.role::text IN ('teacher', 'admin', 'superadmin')
                 AND COALESCE(tp.is_suspended, FALSE) = FALSE
           )
           OR EXISTS (
               SELECT 1
               FROM public.halaqahs h
               WHERE h.teacher_id = target_id
           )
           OR (
               public.is_teacher()
               AND EXISTS (
                   SELECT 1
                   FROM public.parent_students ps
                   WHERE ps.parent_id = target_id
                     AND public.teaches_student(ps.student_id)
               )
           )
           OR EXISTS (
               SELECT 1
               FROM public.conversation_participants cp1
               JOIN public.conversation_participants cp2
                 ON cp1.conversation_id = cp2.conversation_id
               WHERE cp1.user_id = auth.uid()
                 AND cp2.user_id = target_id
           )
       );
$$;

CREATE OR REPLACE FUNCTION public.is_conversation_member(p_conv_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.is_active_user()
       AND (
           public.is_admin()
           OR EXISTS (
               SELECT 1
               FROM public.conversation_participants cp
               WHERE cp.conversation_id = p_conv_id
                 AND cp.user_id = auth.uid()
           )
           OR EXISTS (
               SELECT 1
               FROM public.conversations c
               WHERE c.id = p_conv_id
                 AND auth.uid()::text = ANY(COALESCE(c.participant_ids, '{}'))
           )
       );
$$;

REVOKE ALL ON FUNCTION public.is_active_user() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_superadmin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_teacher() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.teaches_student(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.teaches_halaqah(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.can_view_profile(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_conversation_member(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.is_active_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_teacher() TO authenticated;
GRANT EXECUTE ON FUNCTION public.teaches_student(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.teaches_halaqah(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_view_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 2. LOCK DOWN public.profiles (PREVENT SELF-ESCALATION & PII EXPOSURE)
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public profiles readable by authenticated" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Admins can manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins manage all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Scoped profile reads" ON public.profiles;
DROP POLICY IF EXISTS "Users update own safe profile fields" ON public.profiles;

CREATE POLICY "Scoped profile reads"
ON public.profiles FOR SELECT TO authenticated
USING (public.can_view_profile(id));

CREATE POLICY "Users update own safe profile fields"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id AND public.is_active_user())
WITH CHECK (
    auth.uid() = id
    AND public.is_active_user()
    AND role::text = public.current_user_role()
    AND COALESCE(is_suspended, FALSE) = FALSE
);

CREATE POLICY "Admins manage all profiles"
ON public.profiles FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.guard_profile_privileged_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_db_role TEXT;
BEGIN
    v_db_role := current_setting('role', true);
    IF v_db_role IN ('service_role', 'postgres', 'supabase_admin') THEN
        RETURN NEW;
    END IF;

    -- Allow migration / controlled SECURITY DEFINER RPCs when jwt is absent
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF NEW.role IS DISTINCT FROM OLD.role THEN
        IF NOT public.is_superadmin() THEN
            RAISE EXCEPTION 'Only superadmins can modify user roles.';
        END IF;
    END IF;

    IF COALESCE(NEW.is_suspended, FALSE) IS DISTINCT FROM COALESCE(OLD.is_suspended, FALSE) THEN
        IF OLD.id = auth.uid() THEN
            RAISE EXCEPTION 'Users cannot modify their own suspension status.';
        END IF;

        IF OLD.role::text IN ('admin', 'superadmin') THEN
            IF NOT public.is_superadmin() THEN
                RAISE EXCEPTION 'Only superadmins can suspend or reactivate admin or superadmin accounts.';
            END IF;
        ELSE
            IF NOT public.is_admin() THEN
                RAISE EXCEPTION 'Only administrators can modify suspension status.';
            END IF;
        END IF;
    END IF;

    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION 'Profile ID is immutable.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_privileged_fields ON public.profiles;
CREATE TRIGGER trg_guard_profile_privileged_fields
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.guard_profile_privileged_fields();

-- ------------------------------------------------------------------------------
-- 3. HARDEN INVITATION CODES & RPC FUNCTIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.invitation_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage invitation codes" ON public.invitation_codes;
DROP POLICY IF EXISTS "Admins manage invitation codes" ON public.invitation_codes;
DROP POLICY IF EXISTS "Anyone can check active invite codes" ON public.invitation_codes;

CREATE POLICY "Admins manage invitation codes"
ON public.invitation_codes FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Minimal safe RPC for pre-signup invitation code validation (no table dump, no PII)
CREATE OR REPLACE FUNCTION public.validate_invitation_code(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_role TEXT;
    v_clean_code TEXT;
BEGIN
    v_clean_code := UPPER(TRIM(COALESCE(p_code, '')));
    IF v_clean_code = '' THEN
        RETURN jsonb_build_object('valid', false, 'target_role', NULL);
    END IF;

    SELECT role::text INTO v_role
    FROM public.invitation_codes
    WHERE UPPER(code) = v_clean_code
      AND NOT COALESCE(is_used, FALSE)
      AND expires_at > NOW()
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('valid', false, 'target_role', NULL);
    END IF;

    RETURN jsonb_build_object('valid', true, 'target_role', v_role);
END;
$$;

REVOKE ALL ON FUNCTION public.validate_invitation_code(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_invitation_code(TEXT) TO anon, authenticated;

-- Hardened consume_invitation_code: authenticated caller only, bound to auth.uid()
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
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id UUID;
    v_auth_email TEXT;
    v_invite RECORD;
    v_existing RECORD;
    v_halaqah_name TEXT;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Authentication required to consume an invitation code.');
    END IF;

    IF p_user_id IS NOT NULL AND p_user_id <> v_caller_id THEN
        RETURN jsonb_build_object('success', false, 'message', 'Access denied: caller identity mismatch.');
    END IF;

    SELECT email INTO v_auth_email
    FROM auth.users
    WHERE id = v_caller_id;

    SELECT * INTO v_invite
    FROM public.invitation_codes
    WHERE UPPER(code) = UPPER(TRIM(COALESCE(p_code, '')))
      AND NOT COALESCE(is_used, FALSE)
      AND expires_at > NOW()
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid, expired, or already used invitation code.');
    END IF;

    -- Enforce target_email restriction if invitation code was locked to an email
    IF v_invite.target_email IS NOT NULL AND TRIM(v_invite.target_email) <> '' THEN
        IF LOWER(TRIM(COALESCE(v_auth_email, p_email, ''))) <> LOWER(TRIM(v_invite.target_email)) THEN
            RETURN jsonb_build_object('success', false, 'message', 'This invitation code is restricted to a different email address.');
        END IF;
    END IF;

    -- Check existing profile so privileged or suspended accounts cannot be overwritten/unsuspended
    SELECT id, role, is_suspended INTO v_existing
    FROM public.profiles
    WHERE id = v_caller_id;

    IF FOUND THEN
        IF COALESCE(v_existing.is_suspended, FALSE) = TRUE THEN
            RETURN jsonb_build_object('success', false, 'message', 'Suspended accounts cannot redeem invitation codes.');
        END IF;
        IF v_existing.role::text IN ('admin', 'superadmin') THEN
            RETURN jsonb_build_object('success', false, 'message', 'Existing administrator profiles cannot be overwritten via invite codes.');
        END IF;
    END IF;

    IF v_invite.role::text = 'teacher' AND v_invite.target_halaqah_id IS NOT NULL THEN
        SELECT name INTO v_halaqah_name
        FROM public.halaqahs
        WHERE id = v_invite.target_halaqah_id;
    END IF;

    INSERT INTO public.profiles (id, role, full_name, email, phone, is_suspended, halaqah_id, halaqah_name)
    VALUES (
        v_caller_id,
        v_invite.role,
        TRIM(COALESCE(NULLIF(p_full_name, ''), 'User')),
        COALESCE(v_auth_email, TRIM(p_email)),
        NULLIF(TRIM(COALESCE(p_phone, '')), ''),
        FALSE,
        CASE WHEN v_invite.role::text = 'teacher' THEN v_invite.target_halaqah_id ELSE NULL END,
        CASE WHEN v_invite.role::text = 'teacher' THEN v_halaqah_name ELSE NULL END
    )
    ON CONFLICT (id) DO UPDATE
    SET role = v_invite.role,
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
        halaqah_id = COALESCE(EXCLUDED.halaqah_id, public.profiles.halaqah_id),
        halaqah_name = COALESCE(EXCLUDED.halaqah_name, public.profiles.halaqah_name),
        updated_at = NOW();

    IF v_invite.role::text = 'parent' AND v_invite.linked_student_id IS NOT NULL THEN
        INSERT INTO public.parent_students (parent_id, student_id)
        VALUES (v_caller_id, v_invite.linked_student_id)
        ON CONFLICT DO NOTHING;
    END IF;

    IF v_invite.role::text = 'teacher' AND v_invite.target_halaqah_id IS NOT NULL THEN
        UPDATE public.halaqahs
        SET teacher_id = v_caller_id
        WHERE id = v_invite.target_halaqah_id;
    END IF;

    UPDATE public.invitation_codes
    SET is_used = TRUE,
        used_by = v_caller_id,
        used_at = NOW()
    WHERE id = v_invite.id;

    RETURN jsonb_build_object(
        'success', true,
        'role', v_invite.role::text,
        'message', 'Registration completed successfully.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.consume_invitation_code(TEXT, UUID, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.consume_invitation_code(TEXT, UUID, TEXT, TEXT, TEXT) TO authenticated;

-- Hardened generate_invitation_code: is_admin() required + pgcrypto randomness
CREATE OR REPLACE FUNCTION public.generate_invitation_code(
    p_role TEXT,
    p_code TEXT DEFAULT NULL,
    p_target_email TEXT DEFAULT NULL,
    p_linked_student_id UUID DEFAULT NULL,
    p_target_halaqah_id UUID DEFAULT NULL,
    p_days_valid INT DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
    v_code TEXT;
    v_new_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_role user_role;
    v_days INT;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Access denied: only administrators can generate invitation codes.');
    END IF;

    IF LOWER(TRIM(COALESCE(p_role, ''))) NOT IN ('teacher', 'parent') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Role must be either teacher or parent.');
    END IF;
    v_role := LOWER(TRIM(p_role))::user_role;
    v_days := GREATEST(1, LEAST(COALESCE(p_days_valid, 30), 365));

    IF p_code IS NOT NULL AND TRIM(p_code) <> '' THEN
        v_code := UPPER(TRIM(p_code));
    ELSE
        v_code := (CASE WHEN v_role::text = 'teacher' THEN 'KHY-TEA-' ELSE 'KHY-PAR-' END)
                  || UPPER(encode(gen_random_bytes(4), 'hex'));
    END IF;

    v_expires_at := NOW() + make_interval(days => v_days);

    INSERT INTO public.invitation_codes (
        code,
        role,
        target_email,
        linked_student_id,
        target_halaqah_id,
        expires_at,
        created_by
    )
    VALUES (
        v_code,
        v_role,
        NULLIF(TRIM(COALESCE(p_target_email, '')), ''),
        p_linked_student_id,
        p_target_halaqah_id,
        v_expires_at,
        auth.uid()
    )
    RETURNING id INTO v_new_id;

    RETURN jsonb_build_object(
        'success', true,
        'id', v_new_id,
        'code', v_code,
        'role', v_role::text,
        'expires_at', v_expires_at,
        'target_email', p_target_email,
        'message', 'Invitation code generated successfully.'
    );
EXCEPTION WHEN unique_violation THEN
    v_code := (CASE WHEN v_role::text = 'teacher' THEN 'KHY-TEA-' ELSE 'KHY-PAR-' END)
              || UPPER(encode(gen_random_bytes(5), 'hex'));
    INSERT INTO public.invitation_codes (code, role, target_email, linked_student_id, target_halaqah_id, expires_at, created_by)
    VALUES (v_code, v_role, NULLIF(TRIM(COALESCE(p_target_email, '')), ''), p_linked_student_id, p_target_halaqah_id, v_expires_at, auth.uid())
    RETURNING id INTO v_new_id;
    RETURN jsonb_build_object(
        'success', true,
        'id', v_new_id,
        'code', v_code,
        'role', v_role::text,
        'expires_at', v_expires_at,
        'target_email', p_target_email,
        'message', 'Invitation code generated successfully.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.generate_invitation_code(TEXT, TEXT, TEXT, UUID, UUID, INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.generate_invitation_code(TEXT, TEXT, TEXT, UUID, UUID, INT) TO authenticated;

-- Harden admin_assign_teacher_halaqah search_path
CREATE OR REPLACE FUNCTION public.admin_assign_teacher_halaqah(
    p_teacher_id UUID,
    p_halaqah_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_halaqah_name TEXT;
    v_prev_teacher_id UUID;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only center administrators can assign study circles.');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_teacher_id AND role::text = 'teacher') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Teacher profile not found.');
    END IF;

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

-- Harden admin_set_user_role: search_path, prevent leaving 0 active superadmins
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
    p_user_id UUID,
    p_new_role user_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_target RECORD;
    v_other_superadmins INT;
    v_updated RECORD;
BEGIN
    IF NOT public.is_superadmin() THEN
        RAISE EXCEPTION 'Only a superadmin can promote or modify user roles.';
    END IF;

    SELECT id, email, role, is_suspended INTO v_target
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found.';
    END IF;

    IF v_target.role::text = 'superadmin' AND p_new_role::text <> 'superadmin' THEN
        IF p_user_id = auth.uid() THEN
            RAISE EXCEPTION 'Superadmins cannot demote their own active account.';
        END IF;

        SELECT COUNT(*) INTO v_other_superadmins
        FROM public.profiles
        WHERE role::text = 'superadmin'
          AND COALESCE(is_suspended, FALSE) = FALSE
          AND id <> p_user_id;

        IF v_other_superadmins < 1 THEN
            RAISE EXCEPTION 'Cannot demote the last active superadmin account.';
        END IF;
    END IF;

    UPDATE public.profiles
    SET role = p_new_role,
        updated_at = NOW()
    WHERE id = p_user_id
    RETURNING id, full_name, email, role, halaqah_name, is_suspended INTO v_updated;

    RETURN jsonb_build_object(
        'success', TRUE,
        'user_id', v_updated.id,
        'full_name', v_updated.full_name,
        'email', v_updated.email,
        'new_role', v_updated.role::text
    );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_user_role(UUID, user_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(UUID, user_role) TO authenticated;

-- Harden admin_delete_user: protect superadmins/admins & isolate monthly_payments from standard admins
CREATE OR REPLACE FUNCTION public.admin_delete_user(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_target RECORD;
    v_is_super BOOLEAN;
    v_has_payments BOOLEAN := FALSE;
BEGIN
    IF NOT public.is_admin() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only center administrators can remove users.');
    END IF;

    v_is_super := public.is_superadmin();

    IF p_user_id = auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'You cannot remove your own active administrator account.');
    END IF;

    SELECT id, role, email, full_name INTO v_target
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'User account not found.');
    END IF;

    IF v_target.role::text = 'superadmin' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Superadmin accounts cannot be deleted.');
    END IF;

    IF v_target.role::text = 'admin' AND NOT v_is_super THEN
        RETURN jsonb_build_object('success', false, 'message', 'Only superadmins can remove administrator accounts.');
    END IF;

    IF to_regclass('public.monthly_payments') IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1 FROM public.monthly_payments
            WHERE parent_id = p_user_id OR reviewed_by = p_user_id
        ) INTO v_has_payments;

        IF v_has_payments AND NOT v_is_super THEN
            RETURN jsonb_build_object('success', false, 'message', 'Users with financial payment records can only be removed by a superadmin.');
        END IF;

        IF v_is_super THEN
            UPDATE public.monthly_payments SET reviewed_by = NULL WHERE reviewed_by = p_user_id;
            DELETE FROM public.monthly_payments WHERE parent_id = p_user_id;
        END IF;
    END IF;

    UPDATE public.invitation_codes SET used_by = NULL WHERE used_by = p_user_id;
    UPDATE public.invitation_codes SET created_by = NULL WHERE created_by = p_user_id;
    UPDATE public.halaqahs SET teacher_id = NULL WHERE teacher_id = p_user_id;
    UPDATE public.announcements SET author_id = NULL WHERE author_id = p_user_id;

    DELETE FROM public.messages WHERE sender_id = p_user_id;
    IF to_regclass('public.hifz_records') IS NOT NULL THEN
        EXECUTE 'DELETE FROM public.hifz_records WHERE teacher_id = $1' USING p_user_id;
    END IF;
    DELETE FROM public.homework_assignments WHERE teacher_id = p_user_id;

    IF to_regclass('public.homework_submissions') IS NOT NULL THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'homework_submissions' AND column_name = 'parent_id'
        ) THEN
            EXECUTE 'UPDATE public.homework_submissions SET parent_id = NULL WHERE parent_id = $1' USING p_user_id;
        END IF;
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

    DELETE FROM public.profiles WHERE id = p_user_id;

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
-- 4. LOCK DOWN PARENT_STUDENTS, STUDENTS & HALAQAHS
-- ------------------------------------------------------------------------------
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins manage parent_students" ON public.parent_students;
DROP POLICY IF EXISTS "Authenticated users view parent_students links" ON public.parent_students;
DROP POLICY IF EXISTS "Authorized users view parent_students links" ON public.parent_students;
DROP POLICY IF EXISTS "Admins write parent_students links" ON public.parent_students;

CREATE POLICY "Authorized users view parent_students links"
ON public.parent_students FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        parent_id = auth.uid()
        OR public.is_admin()
        OR public.teaches_student(student_id)
    )
);

CREATE POLICY "Admins write parent_students links"
ON public.parent_students FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

ALTER TABLE public.halaqahs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users view halaqahs" ON public.halaqahs;
DROP POLICY IF EXISTS "Admins can manage halaqahs" ON public.halaqahs;
DROP POLICY IF EXISTS "Admins manage halaqahs" ON public.halaqahs;
DROP POLICY IF EXISTS "Teachers view and update assigned halaqah" ON public.halaqahs;

CREATE POLICY "Authenticated users view halaqahs"
ON public.halaqahs FOR SELECT TO authenticated
USING (public.is_active_user());

CREATE POLICY "Admins manage halaqahs"
ON public.halaqahs FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "Teachers view and update assigned halaqah"
ON public.halaqahs FOR UPDATE TO authenticated
USING (public.is_teacher() AND teacher_id = auth.uid())
WITH CHECK (public.is_teacher() AND teacher_id = auth.uid());

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can manage students" ON public.students;
DROP POLICY IF EXISTS "Admins and teachers manage students" ON public.students;
DROP POLICY IF EXISTS "Parents view own children" ON public.students;
DROP POLICY IF EXISTS "Admins manage students" ON public.students;
DROP POLICY IF EXISTS "Teachers read and enroll circle students" ON public.students;
DROP POLICY IF EXISTS "Teachers update circle students" ON public.students;

CREATE POLICY "Admins manage students"
ON public.students FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "Parents view own children"
ON public.students FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR public.teaches_halaqah(halaqah_id)
    )
);

CREATE POLICY "Teachers update circle students"
ON public.students FOR UPDATE TO authenticated
USING (public.teaches_halaqah(halaqah_id))
WITH CHECK (public.teaches_halaqah(halaqah_id));

-- ------------------------------------------------------------------------------
-- 5. LOCK DOWN monthly_payments (SUPERADMIN ONLY + SAFE PARENT RECEIPT SUBMISSION)
-- ------------------------------------------------------------------------------
ALTER TABLE public.monthly_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Superadmins manage all payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents view own payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents update own payment receipts" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents update receipt submission" ON public.monthly_payments;
DROP POLICY IF EXISTS "Admins manage all payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents submit own payment receipt" ON public.monthly_payments;

CREATE POLICY "Superadmins manage all payments"
ON public.monthly_payments FOR ALL TO authenticated
USING (public.is_superadmin())
WITH CHECK (public.is_superadmin());

CREATE POLICY "Parents view own payments"
ON public.monthly_payments FOR SELECT TO authenticated
USING (public.is_active_user() AND parent_id = auth.uid());

CREATE POLICY "Parents submit own payment receipt"
ON public.monthly_payments FOR UPDATE TO authenticated
USING (
    public.is_active_user()
    AND parent_id = auth.uid()
    AND status IN ('pending', 'rejected', 'overdue')
)
WITH CHECK (
    public.is_active_user()
    AND parent_id = auth.uid()
    AND status = 'submitted'
);

CREATE OR REPLACE FUNCTION public.guard_monthly_payment_parent_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_db_role TEXT;
BEGIN
    v_db_role := current_setting('role', true);
    IF v_db_role IN ('service_role', 'postgres', 'supabase_admin') OR auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.is_superadmin() THEN
        RETURN NEW;
    END IF;

    IF NEW.parent_id IS DISTINCT FROM OLD.parent_id
       OR NEW.student_id IS DISTINCT FROM OLD.student_id
       OR NEW.month_year IS DISTINCT FROM OLD.month_year
       OR NEW.amount IS DISTINCT FROM OLD.amount
       OR NEW.due_date IS DISTINCT FROM OLD.due_date
       OR NEW.fee_start_date IS DISTINCT FROM OLD.fee_start_date
       OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
       OR NEW.reviewed_by IS DISTINCT FROM OLD.reviewed_by THEN
        RAISE EXCEPTION 'Parents can only attach a receipt to their pending tuition invoice.';
    END IF;

    IF NEW.status <> 'submitted' THEN
        RAISE EXCEPTION 'Parents can only transition invoice status to submitted.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_monthly_payment_parent_update ON public.monthly_payments;
CREATE TRIGGER trg_guard_monthly_payment_parent_update
BEFORE UPDATE ON public.monthly_payments
FOR EACH ROW
EXECUTE FUNCTION public.guard_monthly_payment_parent_update();

-- ------------------------------------------------------------------------------
-- 6. LOCK DOWN CONVERSATIONS, PARTICIPANTS & MESSAGES + SAFE DM RPC
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users view conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Participants and admins manage conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Members view conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Admins manage conversation participants" ON public.conversation_participants;

CREATE POLICY "Members view conversation participants"
ON public.conversation_participants FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        user_id = auth.uid()
        OR public.is_admin()
        OR public.is_conversation_member(conversation_id)
    )
);

CREATE POLICY "Admins manage conversation participants"
ON public.conversation_participants FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Participants view conversations" ON public.conversations;
DROP POLICY IF EXISTS "Authenticated users create conversations" ON public.conversations;
DROP POLICY IF EXISTS "Participants update conversations" ON public.conversations;
DROP POLICY IF EXISTS "Admins manage conversations" ON public.conversations;

CREATE POLICY "Participants view conversations"
ON public.conversations FOR SELECT TO authenticated
USING (public.is_conversation_member(id));

CREATE POLICY "Admins manage conversations"
ON public.conversations FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Participants read messages" ON public.messages;
DROP POLICY IF EXISTS "Participants send messages" ON public.messages;
DROP POLICY IF EXISTS "Senders update own messages" ON public.messages;
DROP POLICY IF EXISTS "Senders delete own messages" ON public.messages;

CREATE POLICY "Participants read messages"
ON public.messages FOR SELECT TO authenticated
USING (public.is_conversation_member(conversation_id));

CREATE POLICY "Participants send messages"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
    public.is_active_user()
    AND sender_id = auth.uid()
    AND public.is_conversation_member(conversation_id)
);

CREATE POLICY "Senders update own messages"
ON public.messages FOR UPDATE TO authenticated
USING (public.is_active_user() AND sender_id = auth.uid())
WITH CHECK (public.is_active_user() AND sender_id = auth.uid());

CREATE POLICY "Senders delete own messages"
ON public.messages FOR DELETE TO authenticated
USING (
    public.is_admin()
    OR (public.is_active_user() AND sender_id = auth.uid())
);

-- Safe RPC for creating a verified 1-on-1 direct conversation without trusting client participant inserts
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
BEGIN
    IF NOT public.is_active_user() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Active authenticated session required.');
    END IF;

    IF p_other_user_id IS NULL OR p_other_user_id = auth.uid() THEN
        RETURN jsonb_build_object('success', false, 'message', 'Valid recipient user is required.');
    END IF;

    SELECT id, role, full_name, is_suspended INTO v_caller
    FROM public.profiles
    WHERE id = auth.uid();

    SELECT id, role, full_name, is_suspended INTO v_other
    FROM public.profiles
    WHERE id = p_other_user_id;

    IF NOT FOUND OR COALESCE(v_other.is_suspended, FALSE) = TRUE THEN
        RETURN jsonb_build_object('success', false, 'message', 'Recipient account is unavailable.');
    END IF;

    -- Verify permitted communication pair
    IF v_caller.role::text IN ('admin', 'superadmin')
       OR v_other.role::text IN ('admin', 'superadmin') THEN
        v_allowed := TRUE;
    ELSIF v_caller.role::text = 'teacher' AND v_other.role::text = 'parent' THEN
        v_allowed := EXISTS (
            SELECT 1 FROM public.parent_students ps
            WHERE ps.parent_id = v_other.id
              AND public.teaches_student(ps.student_id)
        );
    ELSIF v_caller.role::text = 'parent' AND v_other.role::text = 'teacher' THEN
        v_allowed := EXISTS (
            SELECT 1 FROM public.parent_students ps
            JOIN public.students s ON s.id = ps.student_id
            LEFT JOIN public.halaqahs h ON h.id = s.halaqah_id
            WHERE ps.parent_id = v_caller.id
              AND (h.teacher_id = v_other.id OR v_other.id IN (
                  SELECT p.id FROM public.profiles p WHERE p.id = v_other.id AND p.halaqah_id = s.halaqah_id
              ))
        );
    ELSIF v_caller.role::text = 'teacher' AND v_other.role::text = 'teacher' THEN
        v_allowed := TRUE;
    END IF;

    IF NOT v_allowed THEN
        RETURN jsonb_build_object('success', false, 'message', 'You are not authorized to initiate this conversation.');
    END IF;

    -- Return existing 1-on-1 conversation if already created
    SELECT c.* INTO v_existing
    FROM public.conversations c
    WHERE COALESCE(c.is_group, FALSE) = FALSE
      AND auth.uid()::text = ANY(COALESCE(c.participant_ids, '{}'))
      AND p_other_user_id::text = ANY(COALESCE(c.participant_ids, '{}'))
    ORDER BY c.created_at DESC
    LIMIT 1;

    IF FOUND THEN
        INSERT INTO public.conversation_participants (conversation_id, user_id)
        VALUES (v_existing.id, auth.uid()), (v_existing.id, p_other_user_id)
        ON CONFLICT DO NOTHING;

        RETURN jsonb_build_object(
            'success', true,
            'conversation', to_jsonb(v_existing)
        );
    END IF;

    v_group_type := COALESCE(
        NULLIF(TRIM(COALESCE(p_group_type, '')), ''),
        CASE
            WHEN v_caller.role::text IN ('admin', 'superadmin') OR v_other.role::text IN ('admin', 'superadmin') THEN 'direct_admin'
            ELSE 'direct_teacher'
        END
    );
    v_title := COALESCE(NULLIF(TRIM(COALESCE(p_title, '')), ''), v_other.full_name);

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
        ARRAY[v_caller.full_name, v_other.full_name],
        v_group_type,
        p_halaqah_id,
        NOW()
    )
    RETURNING * INTO v_conv;

    INSERT INTO public.conversation_participants (conversation_id, user_id)
    VALUES (v_conv.id, auth.uid()), (v_conv.id, p_other_user_id)
    ON CONFLICT DO NOTHING;

    RETURN jsonb_build_object(
        'success', true,
        'conversation', to_jsonb(v_conv)
    );
END;
$$;

REVOKE ALL ON FUNCTION public.create_direct_conversation(UUID, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_direct_conversation(UUID, TEXT, UUID, TEXT) TO authenticated;

-- ------------------------------------------------------------------------------
-- 7. HARDEN ACADEMIC TABLES (HIFZ, ATTENDANCE, REPORTS, HOMEWORK, ABSENCE)
-- ------------------------------------------------------------------------------
-- 7a. hifz_records
DO $$
BEGIN
    IF to_regclass('public.hifz_records') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.hifz_records ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Parents read children hifz" ON public.hifz_records;
            DROP POLICY IF EXISTS "Teachers insert hifz" ON public.hifz_records;
            DROP POLICY IF EXISTS "Admins manage hifz" ON public.hifz_records;

            CREATE POLICY "Parents read children hifz"
            ON public.hifz_records FOR SELECT TO authenticated
            USING (
                public.is_active_user()
                AND (
                    public.is_admin()
                    OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
                    OR public.teaches_student(student_id)
                    OR (public.is_teacher() AND teacher_id = auth.uid())
                )
            );

            CREATE POLICY "Teachers insert hifz"
            ON public.hifz_records FOR INSERT TO authenticated
            WITH CHECK (
                public.is_admin()
                OR (
                    public.is_teacher()
                    AND teacher_id = auth.uid()
                    AND public.teaches_student(student_id)
                )
            );

            CREATE POLICY "Admins manage hifz"
            ON public.hifz_records FOR ALL TO authenticated
            USING (public.is_admin())
            WITH CHECK (public.is_admin());
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.hifz_records';
    END IF;
END
$$;

-- 7b. student_attendance
DO $$
BEGIN
    IF to_regclass('public.student_attendance') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.student_attendance ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Parents view own children attendance" ON public.student_attendance;
            DROP POLICY IF EXISTS "Teachers and admins record attendance" ON public.student_attendance;

            CREATE POLICY "Parents view own children attendance"
            ON public.student_attendance FOR SELECT TO authenticated
            USING (
                public.is_active_user()
                AND (
                    public.is_admin()
                    OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
                    OR public.teaches_student(student_id)
                    OR (public.is_teacher() AND teacher_id = auth.uid())
                )
            );

            CREATE POLICY "Teachers and admins record attendance"
            ON public.student_attendance FOR ALL TO authenticated
            USING (
                public.is_admin()
                OR (public.is_teacher() AND public.teaches_student(student_id))
            )
            WITH CHECK (
                public.is_admin()
                OR (
                    public.is_teacher()
                    AND teacher_id = auth.uid()
                    AND public.teaches_student(student_id)
                )
            );
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.student_attendance';
    END IF;
END
$$;

-- 7c. weekly_reports
DO $$
BEGIN
    IF to_regclass('public.weekly_reports') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.weekly_reports ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Parents view own children weekly reports" ON public.weekly_reports;
            DROP POLICY IF EXISTS "Teachers and admins manage weekly reports" ON public.weekly_reports;

            CREATE POLICY "Parents view own children weekly reports"
            ON public.weekly_reports FOR SELECT TO authenticated
            USING (
                public.is_active_user()
                AND (
                    public.is_admin()
                    OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
                    OR public.teaches_student(student_id)
                    OR (public.is_teacher() AND teacher_id = auth.uid())
                )
            );

            CREATE POLICY "Teachers and admins manage weekly reports"
            ON public.weekly_reports FOR ALL TO authenticated
            USING (
                public.is_admin()
                OR (public.is_teacher() AND public.teaches_student(student_id))
            )
            WITH CHECK (
                public.is_admin()
                OR (
                    public.is_teacher()
                    AND teacher_id = auth.uid()
                    AND public.teaches_student(student_id)
                )
            );
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.weekly_reports';
    END IF;
END
$$;

-- 7d. homework_assignments
ALTER TABLE public.homework_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users view assignments" ON public.homework_assignments;
DROP POLICY IF EXISTS "Parents view children homework assignments" ON public.homework_assignments;
DROP POLICY IF EXISTS "Teachers and admins manage homework assignments" ON public.homework_assignments;
DROP POLICY IF EXISTS "Teachers and admins manage assignments" ON public.homework_assignments;

CREATE POLICY "Parents view children homework assignments"
ON public.homework_assignments FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.teaches_halaqah(halaqah_id)
        OR (public.is_teacher() AND teacher_id = auth.uid())
        OR halaqah_id IN (
            SELECT s.halaqah_id
            FROM public.students s
            JOIN public.parent_students ps ON ps.student_id = s.id
            WHERE ps.parent_id = auth.uid()
        )
    )
);

CREATE POLICY "Teachers and admins manage homework assignments"
ON public.homework_assignments FOR ALL TO authenticated
USING (
    public.is_admin()
    OR (public.is_teacher() AND (teacher_id = auth.uid() OR public.teaches_halaqah(halaqah_id)))
)
WITH CHECK (
    public.is_admin()
    OR (
        public.is_teacher()
        AND teacher_id = auth.uid()
        AND public.teaches_halaqah(halaqah_id)
    )
);

-- 7e. homework_submissions
ALTER TABLE public.homework_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Students and parents view submissions" ON public.homework_submissions;
DROP POLICY IF EXISTS "Students create submissions" ON public.homework_submissions;
DROP POLICY IF EXISTS "Teachers grade submissions" ON public.homework_submissions;
DROP POLICY IF EXISTS "Parents update children homework submissions" ON public.homework_submissions;
DROP POLICY IF EXISTS "Admins manage homework submissions" ON public.homework_submissions;

CREATE POLICY "Students and parents view submissions"
ON public.homework_submissions FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR public.teaches_student(student_id)
        OR assignment_id IN (
            SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid()
        )
    )
);

CREATE POLICY "Students create submissions"
ON public.homework_submissions FOR INSERT TO authenticated
WITH CHECK (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.teaches_student(student_id)
        OR (
            student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
            AND COALESCE(status::text, 'pending') IN ('pending', 'completed_at_home')
            AND grade IS NULL
            AND reviewed_at IS NULL
        )
    )
);

CREATE POLICY "Parents update children homework submissions"
ON public.homework_submissions FOR UPDATE TO authenticated
USING (
    public.is_active_user()
    AND student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
)
WITH CHECK (
    public.is_active_user()
    AND student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    AND status::text IN ('pending', 'completed_at_home', 'needs_rerecording')
);

CREATE POLICY "Teachers grade submissions"
ON public.homework_submissions FOR UPDATE TO authenticated
USING (
    public.is_admin()
    OR (
        public.is_teacher()
        AND (
            public.teaches_student(student_id)
            OR assignment_id IN (SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid())
        )
    )
)
WITH CHECK (
    public.is_admin()
    OR (
        public.is_teacher()
        AND (
            public.teaches_student(student_id)
            OR assignment_id IN (SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid())
        )
    )
);

CREATE POLICY "Admins manage homework submissions"
ON public.homework_submissions FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE OR REPLACE FUNCTION public.guard_homework_submission_parent_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_db_role TEXT;
BEGIN
    v_db_role := current_setting('role', true);
    IF v_db_role IN ('service_role', 'postgres', 'supabase_admin') OR auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    IF public.is_admin() OR public.is_teacher() THEN
        RETURN NEW;
    END IF;

    IF NEW.grade IS DISTINCT FROM OLD.grade
       OR NEW.teacher_feedback_text IS DISTINCT FROM OLD.teacher_feedback_text
       OR NEW.teacher_feedback_audio_url IS DISTINCT FROM OLD.teacher_feedback_audio_url
       OR NEW.teacher_feedback IS DISTINCT FROM OLD.teacher_feedback
       OR NEW.teacher_rating IS DISTINCT FROM OLD.teacher_rating
       OR NEW.reviewed_at IS DISTINCT FROM OLD.reviewed_at
       OR NEW.status::text = 'reviewed' THEN
        RAISE EXCEPTION 'Only teachers or administrators can grade or review homework submissions.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_homework_submission_parent_update ON public.homework_submissions;
CREATE TRIGGER trg_guard_homework_submission_parent_update
BEFORE UPDATE ON public.homework_submissions
FOR EACH ROW
EXECUTE FUNCTION public.guard_homework_submission_parent_update();

-- 7f. absence_requests
DO $$
BEGIN
    IF to_regclass('public.absence_requests') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.absence_requests ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Parents manage own absence requests" ON public.absence_requests;
            DROP POLICY IF EXISTS "Absence requests scoped read" ON public.absence_requests;
            DROP POLICY IF EXISTS "Parents submit own children absence requests" ON public.absence_requests;
            DROP POLICY IF EXISTS "Staff review absence requests" ON public.absence_requests;

            CREATE POLICY "Absence requests scoped read"
            ON public.absence_requests FOR SELECT TO authenticated
            USING (
                public.is_active_user()
                AND (
                    public.is_admin()
                    OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
                    OR public.teaches_student(student_id)
                    OR public.teaches_halaqah(halaqah_id)
                )
            );

            CREATE POLICY "Parents submit own children absence requests"
            ON public.absence_requests FOR INSERT TO authenticated
            WITH CHECK (
                public.is_active_user()
                AND (
                    public.is_admin()
                    OR (
                        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
                        AND (parent_id IS NULL OR parent_id = auth.uid())
                        AND status = 'pending'
                    )
                )
            );

            CREATE POLICY "Staff review absence requests"
            ON public.absence_requests FOR UPDATE TO authenticated
            USING (
                public.is_admin()
                OR (public.is_teacher() AND (public.teaches_student(student_id) OR public.teaches_halaqah(halaqah_id)))
            )
            WITH CHECK (
                public.is_admin()
                OR (public.is_teacher() AND (public.teaches_student(student_id) OR public.teaches_halaqah(halaqah_id)))
            );
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.absence_requests';
    END IF;
END
$$;

-- 7g. account_status & user_device_tokens & announcement_reads
DO $$
BEGIN
    IF to_regclass('public.account_status') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.account_status ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Users can check own status" ON public.account_status;
            DROP POLICY IF EXISTS "Admins manage account status" ON public.account_status;

            CREATE POLICY "Users can check own status"
            ON public.account_status FOR SELECT TO authenticated
            USING (user_id = auth.uid() OR public.is_admin());

            CREATE POLICY "Admins manage account status"
            ON public.account_status FOR ALL TO authenticated
            USING (public.is_admin())
            WITH CHECK (public.is_admin());
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.account_status';
    END IF;
END
$$;

DO $$
BEGIN
    IF to_regclass('public.user_device_tokens') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Users can manage their own device tokens" ON public.user_device_tokens;
            CREATE POLICY "Users can manage their own device tokens"
            ON public.user_device_tokens FOR ALL TO authenticated
            USING (auth.uid() = user_id AND public.is_active_user())
            WITH CHECK (auth.uid() = user_id AND public.is_active_user());
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.user_device_tokens';
    END IF;
END
$$;

DO $$
BEGIN
    IF to_regclass('public.announcement_reads') IS NOT NULL THEN
        EXECUTE $ddl$
            ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

            DROP POLICY IF EXISTS "Users can manage their read receipts" ON public.announcement_reads;
            CREATE POLICY "Users can manage their read receipts"
            ON public.announcement_reads FOR ALL TO authenticated
            USING (auth.uid() = user_id AND public.is_active_user())
            WITH CHECK (auth.uid() = user_id AND public.is_active_user());
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.announcement_reads';
    END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 8. LOCK DOWN ANNOUNCEMENTS & NOTIFICATIONS
-- ------------------------------------------------------------------------------
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public and authenticated read announcements" ON public.announcements;
DROP POLICY IF EXISTS "Authenticated users can read announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins or creators can insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins delete announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can delete announcements" ON public.announcements;

CREATE POLICY "Authenticated active users read announcements"
ON public.announcements FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR COALESCE(target_audience, 'all') = 'all'
        OR EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = auth.uid()
              AND (
                  (target_audience = 'parents' AND p.role::text = 'parent')
                  OR (target_audience = 'teachers' AND p.role::text = 'teacher')
                  OR (target_audience = 'admins' AND p.role::text IN ('admin', 'superadmin'))
              )
        )
    )
);

CREATE POLICY "Admins insert announcements"
ON public.announcements FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "Admins update announcements"
ON public.announcements FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE POLICY "Admins delete announcements"
ON public.announcements FOR DELETE TO authenticated
USING (public.is_admin());

DO $$
BEGIN
    IF to_regclass('public.notifications') IS NOT NULL THEN
        EXECUTE $ddl$
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
        $ddl$;
    ELSE
        RAISE NOTICE 'Skipping RLS lockdown for missing table public.notifications';
    END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 9. PRIVATE STORAGE BUCKETS & PATH-SCOPED STORAGE RLS
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
    ('payment_receipts', 'payment_receipts', false),
    ('avatars', 'avatars', false),
    ('voice_messages', 'voice_messages', false),
    ('recitations', 'recitations', false),
    ('voice-feedback', 'voice-feedback', false),
    ('chat_attachments', 'chat_attachments', false),
    ('announcement_attachments', 'announcement_attachments', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Drop legacy overly-permissive storage policies
DROP POLICY IF EXISTS "Public and authenticated view buckets" ON storage.buckets;
DROP POLICY IF EXISTS "Authenticated view storage buckets" ON storage.buckets;
DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete avatars" ON storage.objects;
DROP POLICY IF EXISTS "Public and authenticated read announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public read announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Anyone read announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Admins upload announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Admins and authenticated upload announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Admins delete announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public and authenticated read chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users read chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public read chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users delete chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public and authenticated read voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users read voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Public read voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users upload voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users delete voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update storage objects" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users upload recitations" ON storage.objects;
DROP POLICY IF EXISTS "Users read recitations" ON storage.objects;

-- Drop Migration 05 policy names in case of re-run
DROP POLICY IF EXISTS "Payment receipts read scoped" ON storage.objects;
DROP POLICY IF EXISTS "Payment receipts insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Payment receipts delete scoped" ON storage.objects;
DROP POLICY IF EXISTS "Avatars read active" ON storage.objects;
DROP POLICY IF EXISTS "Avatars insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Avatars delete scoped" ON storage.objects;
DROP POLICY IF EXISTS "Chat media read scoped" ON storage.objects;
DROP POLICY IF EXISTS "Chat media insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Chat media delete scoped" ON storage.objects;
DROP POLICY IF EXISTS "Recitations read scoped" ON storage.objects;
DROP POLICY IF EXISTS "Recitations insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Recitations delete scoped" ON storage.objects;
DROP POLICY IF EXISTS "Announcement attachments read active" ON storage.objects;
DROP POLICY IF EXISTS "Announcement attachments admin write" ON storage.objects;
DROP POLICY IF EXISTS "Announcement attachments admin delete" ON storage.objects;

-- Allow active authenticated users to inspect bucket metadata if needed
CREATE POLICY "Authenticated view storage buckets"
ON storage.buckets FOR SELECT TO authenticated
USING (public.is_active_user());

-- 9a. payment_receipts: STRICTLY Superadmin OR owning parent (standard admin blocked!)
CREATE POLICY "Payment receipts read scoped"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id = 'payment_receipts'
    AND (
        public.is_superadmin()
        OR (
            public.is_active_user()
            AND (storage.foldername(name))[1] = auth.uid()::text
        )
    )
);

CREATE POLICY "Payment receipts insert scoped"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'payment_receipts'
    AND public.is_active_user()
    AND (
        public.is_superadmin()
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
);

CREATE POLICY "Payment receipts delete scoped"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'payment_receipts'
    AND (
        public.is_superadmin()
        OR (
            public.is_active_user()
            AND owner = auth.uid()
            AND (storage.foldername(name))[1] = auth.uid()::text
        )
    )
);

-- 9b. avatars: Active users can read; admins or own user folder can upload/delete
CREATE POLICY "Avatars read active"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'avatars' AND public.is_active_user());

CREATE POLICY "Avatars insert scoped"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'avatars'
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
);

CREATE POLICY "Avatars delete scoped"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'avatars'
    AND (
        public.is_admin()
        OR (
            public.is_active_user()
            AND owner = auth.uid()
            AND (storage.foldername(name))[1] = auth.uid()::text
        )
    )
);

-- 9c. chat_attachments & voice_messages: conversation members or admins only
CREATE POLICY "Chat media read scoped"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id IN ('chat_attachments', 'voice_messages')
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR (
            (storage.foldername(name))[1] IN ('chat', 'voice')
            AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            AND public.is_conversation_member(((storage.foldername(name))[2])::uuid)
        )
    )
);

CREATE POLICY "Chat media insert scoped"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id IN ('chat_attachments', 'voice_messages')
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR (
            (storage.foldername(name))[1] IN ('chat', 'voice')
            AND (storage.foldername(name))[2] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            AND public.is_conversation_member(((storage.foldername(name))[2])::uuid)
        )
    )
);

CREATE POLICY "Chat media delete scoped"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id IN ('chat_attachments', 'voice_messages')
    AND (
        public.is_admin()
        OR (public.is_active_user() AND owner = auth.uid())
    )
);

-- 9d. recitations & voice-feedback: owners, teachers, or admins only
CREATE POLICY "Recitations read scoped"
ON storage.objects FOR SELECT TO authenticated
USING (
    bucket_id IN ('recitations', 'voice-feedback')
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_teacher()
        OR owner = auth.uid()
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
);

CREATE POLICY "Recitations insert scoped"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id IN ('recitations', 'voice-feedback')
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_teacher()
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
);

CREATE POLICY "Recitations delete scoped"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id IN ('recitations', 'voice-feedback')
    AND (
        public.is_admin()
        OR (public.is_active_user() AND owner = auth.uid())
    )
);

-- 9e. announcement_attachments: active authenticated read, admin-only write/delete
CREATE POLICY "Announcement attachments read active"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'announcement_attachments' AND public.is_active_user());

CREATE POLICY "Announcement attachments admin write"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'announcement_attachments' AND public.is_admin());

CREATE POLICY "Announcement attachments admin delete"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'announcement_attachments' AND public.is_admin());

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
