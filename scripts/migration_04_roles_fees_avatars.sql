-- ==============================================================================
-- KHEYRUKUM MIGRATION 04:
-- 1. SUPERADMIN ROLE & STRICT PAYMENT PERMISSIONS
-- 2. STUDENT AGE (MANDATORY) & AVATARS
-- 3. MONTHLY PAYMENTS TABLE & FEE START DATE
-- 4. NOTIFICATIONS TABLE (BACKGROUND / CLOSED APP DELIVERY)
-- 5. AVATAR STORAGE BUCKET POLICIES
-- 6. SUPERADMIN ROLE PROMOTION RPC
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. EXPAND user_role ENUM TO INCLUDE 'superadmin'
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'superadmin';
EXCEPTION
    WHEN duplicate_object THEN NULL;
    WHEN others THEN NULL;
END $$;

-- Update the primary director to superadmin
UPDATE public.profiles
SET role = 'superadmin', updated_at = NOW()
WHERE email = 'admin@kheyrukum.com';

-- ------------------------------------------------------------------------------
-- 2. ROLE CHECK FUNCTIONS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_superadmin()
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
          AND role = 'superadmin'
          AND COALESCE(is_suspended, FALSE) = FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.is_superadmin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_superadmin() TO authenticated;

-- Update is_admin() to include both admin and superadmin for standard admin operations
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
          AND role IN ('admin', 'superadmin')
          AND COALESCE(is_suspended, FALSE) = FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ------------------------------------------------------------------------------
-- 3. STUDENTS TABLE: ADD AGE (MANDATORY) & AVATAR_URL
-- ------------------------------------------------------------------------------
ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS age INT,
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Backfill default age for existing test students
UPDATE public.students
SET age = 8
WHERE age IS NULL;

-- Enforce NOT NULL on age
ALTER TABLE public.students
ALTER COLUMN age SET NOT NULL;

-- ------------------------------------------------------------------------------
-- 4. MONTHLY PAYMENTS TABLE (FEE START DATE & SUPERADMIN-ONLY PERMISSION)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.monthly_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    month_year TEXT NOT NULL,
    amount NUMERIC(10,2) NOT NULL DEFAULT 50.00,
    due_date DATE NOT NULL,
    fee_start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'pending',
    receipt_url TEXT,
    receipt_local_mock TEXT,
    rejection_reason TEXT,
    submitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure fee_start_date exists if table was already created
ALTER TABLE public.monthly_payments
ADD COLUMN IF NOT EXISTS fee_start_date DATE NOT NULL DEFAULT CURRENT_DATE;

-- Enable RLS on monthly_payments
ALTER TABLE public.monthly_payments ENABLE ROW LEVEL SECURITY;

-- Drop prior policies if any
DROP POLICY IF EXISTS "Superadmins manage all payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents view own payments" ON public.monthly_payments;
DROP POLICY IF EXISTS "Parents update own payment receipts" ON public.monthly_payments;
DROP POLICY IF EXISTS "Admins manage all payments" ON public.monthly_payments;

-- Policy 1: Only SUPERADMIN can see, insert, update, or delete all payments.
-- Regular admin CANNOT access payment data or payment registration!
CREATE POLICY "Superadmins manage all payments"
ON public.monthly_payments FOR ALL TO authenticated
USING (public.is_superadmin())
WITH CHECK (public.is_superadmin());

-- Policy 2: Parents can view only their own payments
CREATE POLICY "Parents view own payments"
ON public.monthly_payments FOR SELECT TO authenticated
USING (parent_id = auth.uid());

-- Policy 3: Parents can submit receipts for their own pending payments
CREATE POLICY "Parents update own payment receipts"
ON public.monthly_payments FOR UPDATE TO authenticated
USING (parent_id = auth.uid())
WITH CHECK (parent_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 5. NOTIFICATIONS TABLE (PERSISTENT LOG FOR CLOSED-APP NOTIFICATION RETRIEVAL)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'general',
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their notifications" ON public.notifications;
DROP POLICY IF EXISTS "Admins can insert notifications" ON public.notifications;
DROP POLICY IF EXISTS "Users can mark own notifications read" ON public.notifications;

CREATE POLICY "Users can view their notifications"
ON public.notifications FOR SELECT TO authenticated
USING (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "Admins can insert notifications"
ON public.notifications FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "Users can mark own notifications read"
ON public.notifications FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 6. STORAGE POLICIES FOR AVATARS BUCKET
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Public read avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated update avatars" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated delete avatars" ON storage.objects;

CREATE POLICY "Public read avatars"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated upload avatars"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "Authenticated update avatars"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars');

CREATE POLICY "Authenticated delete avatars"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'avatars');

-- ------------------------------------------------------------------------------
-- 7. SUPERADMIN USER ROLE PROMOTION RPC
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
    p_user_id UUID,
    p_new_role user_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller_role user_role;
    v_target_email TEXT;
    v_updated RECORD;
BEGIN
    -- Verify caller is superadmin
    IF NOT public.is_superadmin() THEN
        RAISE EXCEPTION 'Only a superadmin can promote or modify user roles.';
    END IF;

    -- Look up target user
    SELECT email INTO v_target_email
    FROM public.profiles
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'User profile not found.';
    END IF;

    -- Safety check: Cannot demote primary director account
    IF v_target_email = 'admin@kheyrukum.com' AND p_new_role != 'superadmin' THEN
        RAISE EXCEPTION 'The primary center director account cannot be demoted.';
    END IF;

    -- Update user role
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
