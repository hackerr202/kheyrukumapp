-- ==============================================================================
-- KHEYRIKUM MOBILE APP — MIGRATION 07: ACADEMIC TABLES & IDEMPOTENT FEE CRON
-- ==============================================================================
-- Idempotent migration that guarantees academic & tracking tables exist on live
-- Supabase databases (hifz_records, student_attendance, weekly_reports,
-- absence_requests, announcement_reads), aligns homework_submissions columns,
-- applies strict Migration 05 RLS policies, and installs an atomic idempotent
-- monthly fee reminder RPC (+ optional pg_cron daily schedule).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. REQUIRED ENUMS
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'hifz_rating') THEN
        CREATE TYPE hifz_rating AS ENUM ('excellent', 'very_good', 'good', 'needs_revision');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'submission_status') THEN
        CREATE TYPE submission_status AS ENUM ('pending', 'reviewed', 'needs_rerecording', 'completed_at_home');
    END IF;
END
$$;

-- ------------------------------------------------------------------------------
-- 2. ACADEMIC, ATTENDANCE, ABSENCE & ANNOUNCEMENT READ TABLES
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hifz_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    surah_number INT NOT NULL CHECK (surah_number BETWEEN 1 AND 114),
    ayah_start INT NOT NULL,
    ayah_end INT NOT NULL,
    rating hifz_rating NOT NULL DEFAULT 'good',
    mistakes_count INT NOT NULL DEFAULT 0,
    tajweed_notes TEXT,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.student_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'absent', 'late', 'excused')),
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (student_id, session_date)
);

CREATE TABLE IF NOT EXISTS public.weekly_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    week_start_date DATE NOT NULL,
    sabaq TEXT NOT NULL,
    sabqi TEXT NOT NULL,
    manzil TEXT NOT NULL,
    tajweed_rating TEXT NOT NULL DEFAULT 'Excellent' CHECK (tajweed_rating IN ('Excellent', 'Very Good', 'Good', 'Needs Revision')),
    teacher_remarks TEXT,
    attendance_days INT NOT NULL DEFAULT 0,
    mistakes_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.absence_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL,
    halaqah_name TEXT NOT NULL,
    parent_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    parent_name TEXT NOT NULL,
    parent_phone TEXT DEFAULT '',
    date DATE NOT NULL,
    reason TEXT NOT NULL DEFAULT 'illness',
    notes TEXT DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'declined')),
    reviewed_by TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.announcement_reads (
    announcement_id UUID NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (announcement_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_hifz_records_student_date
    ON public.hifz_records (student_id, session_date DESC);
CREATE INDEX IF NOT EXISTS idx_student_attendance_student_date
    ON public.student_attendance (student_id, session_date DESC);
CREATE INDEX IF NOT EXISTS idx_weekly_reports_student_created
    ON public.weekly_reports (student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_absence_requests_student_created
    ON public.absence_requests (student_id, created_at DESC);

-- ------------------------------------------------------------------------------
-- 3. ALIGN HOMEWORK_SUBMISSIONS COLUMNS FOR CLIENT & RLS PARITY
-- ------------------------------------------------------------------------------
ALTER TABLE public.homework_submissions
    ADD COLUMN IF NOT EXISTS student_name TEXT,
    ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS repetition_count INT NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS parent_note TEXT,
    ADD COLUMN IF NOT EXISTS practiced_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS teacher_rating TEXT,
    ADD COLUMN IF NOT EXISTS teacher_feedback TEXT,
    ADD COLUMN IF NOT EXISTS submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ------------------------------------------------------------------------------
-- 4. APPLY HARDENED MIGRATION 05 RLS POLICIES ON ALL 5 TABLES
-- ------------------------------------------------------------------------------
-- 4a. hifz_records
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

-- 4b. student_attendance
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

-- 4c. weekly_reports
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

-- 4d. absence_requests
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

-- 4e. announcement_reads
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their read receipts" ON public.announcement_reads;
CREATE POLICY "Users can manage their read receipts"
ON public.announcement_reads FOR ALL TO authenticated
USING (auth.uid() = user_id AND public.is_active_user())
WITH CHECK (auth.uid() = user_id AND public.is_active_user());

-- ------------------------------------------------------------------------------
-- 5. ATOMIC IDEMPOTENT MONTHLY FEE REMINDER DISPATCHER & OPTIONAL PG_CRON JOB
-- ------------------------------------------------------------------------------
ALTER TABLE public.monthly_payments
    ADD COLUMN IF NOT EXISTS fee_start_date DATE DEFAULT CURRENT_DATE,
    ADD COLUMN IF NOT EXISTS last_reminded_month TEXT;

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
            'Monthly Tuition Reminder 💳',
            format(
                'Tuition for %s (%s — %s) is due. Please submit your payment and upload your receipt.',
                COALESCE(s.full_name, 'your child'),
                dr.month_year,
                round(dr.amount, 0)::text
            ),
            'payment_reminder',
            jsonb_build_object(
                'payment_id', dr.id,
                'student_id', dr.student_id,
                'month', dr.month_year
            )
        FROM due_rows dr
        LEFT JOIN public.students s ON s.id = dr.student_id
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

-- Safely schedule daily 09:00 UTC reminder check if pg_cron extension is active.
DO $$
DECLARE
    v_existing_job_id BIGINT;
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        SELECT jobid INTO v_existing_job_id
        FROM cron.job
        WHERE jobname = 'kheyrukum_monthly_fee_reminders'
        LIMIT 1;

        IF v_existing_job_id IS NOT NULL THEN
            PERFORM cron.unschedule(v_existing_job_id);
        END IF;

        PERFORM cron.schedule(
            'kheyrukum_monthly_fee_reminders',
            '0 9 * * *',
            'SELECT public.dispatch_due_monthly_fee_reminders();'
        );
        RAISE NOTICE 'Scheduled daily pg_cron job kheyrukum_monthly_fee_reminders at 09:00 UTC.';
    ELSE
        RAISE NOTICE 'pg_cron extension is not enabled. Enable pg_cron in Supabase Dashboard -> Database -> Extensions, or invoke SELECT public.dispatch_due_monthly_fee_reminders(); on a daily schedule.';
    END IF;
END
$$;
