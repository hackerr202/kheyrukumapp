-- ==============================================================================
-- KHEYRUKUM (خَيْرُكُمْ) ISLAMIC CENTER PORTAL - SUPABASE SQL SCHEMA
-- ==============================================================================
-- Features:
-- 1. Admin Invitation Code Registration Flow (Parent & Teacher)
-- 2. Student & Halaqah Management with Parent-Student linking
-- 3. Daily Hifz (Quran Memorization & Tajweed) Progress Tracking
-- 4. Audio Recitation Homework Submissions & Teacher Voice-Note Feedback
-- 5. Real-time Parent-Teacher Messaging
-- 6. Row Level Security (RLS) Policies on all tables
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. ENUMS & TYPES
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'teacher', 'parent', 'student');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE hifz_rating AS ENUM ('excellent', 'very_good', 'good', 'needs_revision');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE submission_status AS ENUM ('pending', 'reviewed', 'needs_rerecording', 'completed_at_home');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TYPE public.submission_status ADD VALUE IF NOT EXISTS 'completed_at_home';
EXCEPTION
    WHEN others THEN NULL;
END $$;

-- ------------------------------------------------------------------------------
-- 2. PROFILES & USERS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    avatar_url TEXT,
    is_suspended BOOLEAN DEFAULT FALSE,
    halaqah_id UUID,
    halaqah_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------------------------
-- 3. HALAQAHS (STUDY CIRCLES) & STUDENTS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.halaqahs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    description TEXT,
    schedule TEXT DEFAULT 'Daily Recitation Session',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL,
    date_of_birth DATE,
    current_juz INT DEFAULT 1 CHECK (current_juz BETWEEN 1 AND 30),
    current_surah INT DEFAULT 1 CHECK (current_surah BETWEEN 1 AND 114),
    current_ayah INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Many-to-many relationship: One parent can have multiple students enrolled
CREATE TABLE IF NOT EXISTS public.parent_students (
    parent_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (parent_id, student_id)
);

-- ------------------------------------------------------------------------------
-- 4. INVITATION CODES (ADMIN GENERATED SIGNUP FLOW)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invitation_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL,
    role user_role NOT NULL CHECK (role IN ('parent', 'teacher')),
    target_email TEXT, -- Optional: pre-assigned email
    linked_student_id UUID REFERENCES public.students(id) ON DELETE CASCADE, -- For parents
    target_halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL, -- For teachers
    is_used BOOLEAN DEFAULT FALSE,
    used_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invitation_codes_lookup 
ON public.invitation_codes(code) WHERE NOT is_used;

-- ------------------------------------------------------------------------------
-- 5. HIFZ (QURAN MEMORIZATION & TAJWEED) LOGS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hifz_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.profiles(id),
    surah_number INT NOT NULL CHECK (surah_number BETWEEN 1 AND 114),
    ayah_start INT NOT NULL,
    ayah_end INT NOT NULL,
    rating hifz_rating NOT NULL,
    mistakes_count INT DEFAULT 0,
    tajweed_notes TEXT,
    session_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hifz_student ON public.hifz_records(student_id, session_date DESC);

-- ------------------------------------------------------------------------------
-- 6. HOMEWORK ASSIGNMENTS & AUDIO RECITATION SUBMISSIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.homework_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    halaqah_id UUID NOT NULL REFERENCES public.halaqahs(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.profiles(id),
    title TEXT NOT NULL,
    surah_number INT NOT NULL CHECK (surah_number BETWEEN 1 AND 114),
    ayah_start INT NOT NULL,
    ayah_end INT NOT NULL,
    instructions TEXT,
    due_date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.homework_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.homework_assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    audio_url TEXT NOT NULL, -- Supabase Storage audio file path
    duration_seconds INT NOT NULL,
    status submission_status DEFAULT 'pending',
    teacher_feedback_text TEXT,
    teacher_feedback_audio_url TEXT, -- Voice note feedback from teacher
    grade INT CHECK (grade BETWEEN 0 AND 100),
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    reviewed_at TIMESTAMPTZ
);

-- ------------------------------------------------------------------------------
-- 7. MESSAGING & CHAT
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    last_message TEXT,
    last_message_time TIMESTAMPTZ DEFAULT NOW(),
    is_group BOOLEAN DEFAULT FALSE,
    group_type TEXT DEFAULT 'direct_admin',
    halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.conversation_participants (
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id),
    sender_name TEXT,
    sender_role TEXT DEFAULT 'parent',
    content TEXT NOT NULL,
    message_type TEXT DEFAULT 'text',
    media_url TEXT,
    attachment_url TEXT,
    attachment_name TEXT,
    audio_duration INT,
    is_read BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;

-- ------------------------------------------------------------------------------
-- 8. INVITATION CODE CONSUMPTION STORED PROCEDURE
-- ------------------------------------------------------------------------------
-- Atomically validates the invite code, creates/updates profile, and links student/halaqah
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
    -- 1. Find valid, unexpired, unused code (case-insensitive)
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

    -- 2. Insert or update the public profile with the assigned role
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

    -- 3. Link parent to student if it is a parent code
    IF v_invite.role = 'parent' AND v_invite.linked_student_id IS NOT NULL THEN
        INSERT INTO public.parent_students (parent_id, student_id)
        VALUES (p_user_id, v_invite.linked_student_id)
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4. Assign teacher to halaqah if it is a teacher code
    IF v_invite.role = 'teacher' AND v_invite.target_halaqah_id IS NOT NULL THEN
        UPDATE public.halaqahs
        SET teacher_id = p_user_id
        WHERE id = v_invite.target_halaqah_id;
    END IF;

    -- 5. Mark invitation code as used
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

-- Recursion-safe admin helper + user management RPCs
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin' AND COALESCE(is_suspended, FALSE) = FALSE
    );
$$;

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

    UPDATE public.halaqahs SET teacher_id = NULL WHERE teacher_id = p_teacher_id;

    IF p_halaqah_id IS NULL THEN
        UPDATE public.profiles SET halaqah_id = NULL, halaqah_name = NULL, updated_at = NOW() WHERE id = p_teacher_id;
        RETURN jsonb_build_object('success', true, 'halaqah_id', NULL, 'halaqah_name', NULL, 'message', 'Teacher unassigned from study circle.');
    END IF;

    SELECT name, teacher_id INTO v_halaqah_name, v_prev_teacher_id FROM public.halaqahs WHERE id = p_halaqah_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Selected study circle was not found.');
    END IF;

    IF v_prev_teacher_id IS NOT NULL AND v_prev_teacher_id <> p_teacher_id THEN
        UPDATE public.profiles SET halaqah_id = NULL, halaqah_name = NULL, updated_at = NOW()
        WHERE id = v_prev_teacher_id AND halaqah_id = p_halaqah_id;
    END IF;

    UPDATE public.halaqahs SET teacher_id = p_teacher_id WHERE id = p_halaqah_id;
    UPDATE public.profiles SET halaqah_id = p_halaqah_id, halaqah_name = v_halaqah_name, updated_at = NOW() WHERE id = p_teacher_id;

    RETURN jsonb_build_object('success', true, 'halaqah_id', p_halaqah_id, 'halaqah_name', v_halaqah_name, 'message', 'Study circle assigned successfully.');
END;
$$;

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
    SELECT id, role, email INTO v_target FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'User account not found.');
    END IF;
    IF LOWER(COALESCE(v_target.email, '')) = 'admin@kheyrukum.com' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Primary administrator account cannot be removed.');
    END IF;

    UPDATE public.invitation_codes SET used_by = NULL WHERE used_by = p_user_id;
    UPDATE public.invitation_codes SET created_by = NULL WHERE created_by = p_user_id;
    UPDATE public.halaqahs SET teacher_id = NULL WHERE teacher_id = p_user_id;
    UPDATE public.announcements SET author_id = NULL WHERE author_id = p_user_id;
    DELETE FROM public.messages WHERE sender_id = p_user_id;
    DELETE FROM public.hifz_records WHERE teacher_id = p_user_id;
    DELETE FROM public.homework_assignments WHERE teacher_id = p_user_id;
    DELETE FROM public.profiles WHERE id = p_user_id;
    BEGIN
        DELETE FROM auth.users WHERE id = p_user_id;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    RETURN jsonb_build_object('success', true, 'deleted_user_id', p_user_id, 'message', 'User account permanently removed.');
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY (RLS) POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqahs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitation_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hifz_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.homework_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can read profiles in their circles, update their own
CREATE POLICY "Public profiles readable by authenticated"
ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

DO $$ BEGIN
    CREATE POLICY "Admins manage all profiles"
    ON public.profiles FOR ALL TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Halaqahs:
DO $$ BEGIN
    CREATE POLICY "Authenticated users view halaqahs"
    ON public.halaqahs FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins manage halaqahs"
    ON public.halaqahs FOR ALL TO authenticated
    USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers view and update assigned halaqah"
    ON public.halaqahs FOR UPDATE TO authenticated
    USING (teacher_id = auth.uid())
    WITH CHECK (teacher_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Students:
-- Admins and teachers have full manage rights, parents can view their children
DO $$ BEGIN
    CREATE POLICY "Admins and teachers manage students"
    ON public.students FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'teacher'))
        OR id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'teacher'))
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Parents view own children"
    ON public.students FOR SELECT TO authenticated
    USING (
        id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR halaqah_id IN (SELECT id FROM public.halaqahs WHERE teacher_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Parent-Students Link:
DO $$ BEGIN
    CREATE POLICY "Admins manage parent_students"
    ON public.parent_students FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
        OR parent_id = auth.uid()
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
        OR parent_id = auth.uid()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Authenticated users view parent_students links"
    ON public.parent_students FOR SELECT TO authenticated USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Hifz Records:
-- Parents can view only their children's records
-- Teachers can insert/update records for their students
DO $$ BEGIN
    CREATE POLICY "Parents read children hifz"
    ON public.hifz_records FOR SELECT TO authenticated
    USING (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR teacher_id = auth.uid()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers insert hifz"
    ON public.hifz_records FOR INSERT TO authenticated
    WITH CHECK (teacher_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Submissions & Audio:
DO $$ BEGIN
    CREATE POLICY "Students and parents view submissions"
    ON public.homework_submissions FOR SELECT TO authenticated
    USING (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR assignment_id IN (
            SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid()
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Students create submissions"
    ON public.homework_submissions FOR INSERT TO authenticated
    WITH CHECK (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers grade submissions"
    ON public.homework_submissions FOR UPDATE TO authenticated
    USING (
        assignment_id IN (SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Conversations:
DO $$ BEGIN
    CREATE POLICY "Participants view conversations"
    ON public.conversations FOR SELECT TO authenticated
    USING (
        id IN (SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Authenticated users create conversations"
    ON public.conversations FOR INSERT TO authenticated
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Participants update conversations"
    ON public.conversations FOR UPDATE TO authenticated
    USING (
        id IN (SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Messages:
DO $$ BEGIN
    CREATE POLICY "Participants read messages"
    ON public.messages FOR SELECT TO authenticated
    USING (
        conversation_id IN (
            SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Participants send messages"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid() AND
        conversation_id IN (
            SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Senders update own messages"
    ON public.messages FOR UPDATE TO authenticated
    USING (sender_id = auth.uid())
    WITH CHECK (sender_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Senders delete own messages"
    ON public.messages FOR DELETE TO authenticated
    USING (sender_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 10. STORAGE BUCKETS SETUP
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('recitations', 'recitations', false),
    ('voice-feedback', 'voice-feedback', false),
    ('avatars', 'avatars', true),
    ('announcement_attachments', 'announcement_attachments', true),
    ('chat_attachments', 'chat_attachments', true),
    ('voice_messages', 'voice_messages', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DO $$ BEGIN
    CREATE POLICY "Public and authenticated view buckets"
    ON storage.buckets FOR SELECT TO public
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Storage policies: authenticated users can upload their audio recitations
DO $$ BEGIN
    CREATE POLICY "Authenticated users upload recitations"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'recitations');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users read recitations"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id IN ('recitations', 'voice-feedback', 'avatars'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins upload announcement attachments"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'announcement_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Anyone read announcement attachments"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'announcement_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Public read announcement attachments"
    ON storage.objects FOR SELECT TO anon
    USING (bucket_id = 'announcement_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins delete announcement attachments"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'announcement_attachments'
        AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users upload chat attachments"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'chat_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users read chat attachments"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'chat_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users delete chat attachments"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'chat_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users upload voice messages"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'voice_messages');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users read voice messages"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'voice_messages');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users delete voice messages"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'voice_messages');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 11. INITIAL SEED DATA (SAMPLE HALAQAH, STUDENT, & INVITATION CODES)
-- ------------------------------------------------------------------------------
-- Sample Halaqah
INSERT INTO public.halaqahs (id, name, description)
VALUES (
    'a0000000-0000-0000-0000-000000000001',
    'Halaqah Abu Bakr Al-Siddiq (حلقة أبي بكر)',
    'Intermediate Quran Recitation & Tajweed Circle'
)
ON CONFLICT (id) DO NOTHING;

-- Sample Student
INSERT INTO public.students (id, full_name, halaqah_id, current_juz, current_surah, current_ayah)
VALUES (
    'b0000000-0000-0000-0000-000000000001',
    'Abdur-Rahman Muhammed',
    'a0000000-0000-0000-0000-000000000001',
    30,
    67,
    1
)
ON CONFLICT (id) DO NOTHING;

-- Active Parent Invitation Code (linked to student Abdur-Rahman)
INSERT INTO public.invitation_codes (code, role, linked_student_id, is_used)
VALUES (
    'KHY-7842-PAR',
    'parent',
    'b0000000-0000-0000-0000-000000000001',
    false
)
ON CONFLICT (code) DO NOTHING;

-- Active Teacher Invitation Code (linked to Halaqah Abu Bakr)
INSERT INTO public.invitation_codes (code, role, target_halaqah_id, is_used)
VALUES (
    'KHY-9102-TEA',
    'teacher',
    'a0000000-0000-0000-0000-000000000001',
    false
)
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------------------------
-- 12. ANNOUNCEMENTS & REALTIME NOTIFICATIONS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    category TEXT DEFAULT 'general' CHECK (category IN ('general', 'urgent', 'event', 'quran_halaqah', 'holiday')),
    target_audience TEXT DEFAULT 'all' CHECK (target_audience IN ('all', 'parents', 'teachers')),
    author_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    author_name TEXT NOT NULL DEFAULT 'Center Administration',
    is_pinned BOOLEAN DEFAULT FALSE,
    attachment_name TEXT,
    attachment_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.announcement_reads (
    announcement_id UUID REFERENCES public.announcements(id) ON DELETE CASCADE,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (announcement_id, user_id)
);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Authenticated users can read announcements"
    ON public.announcements FOR SELECT TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins or creators can insert announcements"
    ON public.announcements FOR INSERT TO authenticated
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins can update announcements"
    ON public.announcements FOR UPDATE TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins can delete announcements"
    ON public.announcements FOR DELETE TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users can manage their read receipts"
    ON public.announcement_reads FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 12.5 ADMIN INVITATION CODE GENERATION STORED PROCEDURE & REALTIME PUBLICATION
-- ------------------------------------------------------------------------------
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
AS $$
DECLARE
    v_code TEXT;
    v_new_id UUID;
    v_expires_at TIMESTAMPTZ;
    v_role user_role;
BEGIN
    IF LOWER(p_role) NOT IN ('teacher', 'parent') THEN
        RETURN jsonb_build_object('success', false, 'message', 'Role must be either teacher or parent');
    END IF;
    v_role := LOWER(p_role)::user_role;

    IF p_code IS NOT NULL AND TRIM(p_code) <> '' THEN
        v_code := UPPER(TRIM(p_code));
    ELSE
        IF v_role = 'teacher' THEN
            v_code := 'KHY-TEA-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
        ELSE
            v_code := 'KHY-PAR-' || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0');
        END IF;
    END IF;

    v_expires_at := NOW() + (p_days_valid || ' days')::INTERVAL;

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
        NULLIF(TRIM(p_target_email), ''),
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
        'role', v_role,
        'expires_at', v_expires_at,
        'target_email', p_target_email,
        'message', 'Invitation code generated successfully.'
    );
EXCEPTION WHEN unique_violation THEN
    v_code := v_code || '-' || FLOOR(RANDOM() * 90 + 10)::TEXT;
    INSERT INTO public.invitation_codes (code, role, target_email, linked_student_id, target_halaqah_id, expires_at, created_by)
    VALUES (v_code, v_role, NULLIF(TRIM(p_target_email), ''), p_linked_student_id, p_target_halaqah_id, v_expires_at, auth.uid())
    RETURNING id INTO v_new_id;
    RETURN jsonb_build_object(
        'success', true,
        'id', v_new_id,
        'code', v_code,
        'role', v_role,
        'expires_at', v_expires_at,
        'target_email', p_target_email,
        'message', 'Invitation code generated successfully.'
    );
END;
$$;

DO $$ BEGIN
    CREATE POLICY "Admins can manage invitation codes"
    ON public.invitation_codes FOR ALL TO authenticated
    USING (true)
    WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Anyone can check active invite codes"
    ON public.invitation_codes FOR SELECT TO anon
    USING (NOT is_used AND expires_at > NOW());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.announcements;
ALTER PUBLICATION supabase_realtime ADD TABLE public.invitation_codes;

-- ------------------------------------------------------------------------------
-- 13. USER DEVICE TOKENS (FOR OFF-APP CLOSED-APP PUSH NOTIFICATIONS)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android', -- 'android' or 'ios'
    provider TEXT DEFAULT 'fcm',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, device_token)
);

ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can manage their own device tokens"
    ON public.user_device_tokens FOR ALL TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 14. STUDENT DAILY ATTENDANCE
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    session_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'absent', 'late', 'excused')),
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(student_id, session_date)
);

ALTER TABLE public.student_attendance ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Parents view own children attendance"
    ON public.student_attendance FOR SELECT TO authenticated
    USING (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers and admins record attendance"
    ON public.student_attendance FOR ALL TO authenticated
    USING (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 15. WEEKLY PROGRESS REPORTS
-- ------------------------------------------------------------------------------
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
    attendance_days INT DEFAULT 5,
    mistakes_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.weekly_reports ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Parents view own children weekly reports"
    ON public.weekly_reports FOR SELECT TO authenticated
    USING (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers and admins manage weekly reports"
    ON public.weekly_reports FOR ALL TO authenticated
    USING (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 16. MONTHLY PAYMENTS & RECEIPT VERIFICATION
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.monthly_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    month_year TEXT NOT NULL,
    amount NUMERIC(10, 2) NOT NULL DEFAULT 50.00,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'approved', 'rejected', 'overdue')),
    receipt_url TEXT,
    rejection_reason TEXT,
    notes TEXT,
    submitted_at TIMESTAMPTZ,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.monthly_payments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Parents view own payments"
    ON public.monthly_payments FOR SELECT TO authenticated
    USING (
        parent_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Parents update receipt submission"
    ON public.monthly_payments FOR UPDATE TO authenticated
    USING (parent_id = auth.uid())
    WITH CHECK (parent_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins manage all payments"
    ON public.monthly_payments FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 17. ACCOUNT SUSPENSION & STATUS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.account_status (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'removed')),
    suspension_reason TEXT,
    suspended_at TIMESTAMPTZ,
    suspended_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.account_status ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Users can check own status"
    ON public.account_status FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins manage account status"
    ON public.account_status FOR ALL TO authenticated
    USING (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ------------------------------------------------------------------------------
-- 18. HOMEWORK ENHANCEMENTS & ABSENCE REQUESTS
-- ------------------------------------------------------------------------------
ALTER TABLE public.homework_assignments ADD COLUMN IF NOT EXISTS halaqah_name TEXT;
ALTER TABLE public.homework_assignments ADD COLUMN IF NOT EXISTS teacher_name TEXT;
ALTER TABLE public.homework_assignments ADD COLUMN IF NOT EXISTS surah_name TEXT;
ALTER TABLE public.homework_assignments ADD COLUMN IF NOT EXISTS tajweed_focus TEXT;

ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS student_name TEXT;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS repetition_count INT DEFAULT 1;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS parent_note TEXT;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS practiced_at TIMESTAMPTZ;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS teacher_rating TEXT;
ALTER TABLE public.homework_submissions ADD COLUMN IF NOT EXISTS teacher_feedback TEXT;
ALTER TABLE public.homework_submissions ALTER COLUMN audio_url DROP NOT NULL;
ALTER TABLE public.homework_submissions ALTER COLUMN duration_seconds DROP NOT NULL;

DO $$ BEGIN
    CREATE POLICY "Teachers and admins manage homework assignments"
    ON public.homework_assignments FOR ALL TO authenticated
    USING (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
        OR halaqah_id IN (SELECT id FROM public.halaqahs WHERE teacher_id = auth.uid())
    )
    WITH CHECK (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Parents view children homework assignments"
    ON public.homework_assignments FOR SELECT TO authenticated
    USING (
        halaqah_id IN (
            SELECT s.halaqah_id FROM public.students s
            JOIN public.parent_students ps ON ps.student_id = s.id
            WHERE ps.parent_id = auth.uid()
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Parents update children homework submissions"
    ON public.homework_submissions FOR UPDATE TO authenticated
    USING (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    )
    WITH CHECK (
        student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

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
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.absence_requests ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Parents manage own absence requests"
    ON public.absence_requests FOR ALL TO authenticated
    USING (
        parent_id = auth.uid()
        OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR halaqah_id IN (SELECT id FROM public.halaqahs WHERE teacher_id = auth.uid())
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        parent_id = auth.uid()
        OR student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
        OR halaqah_id IN (SELECT id FROM public.halaqahs WHERE teacher_id = auth.uid())
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Realtime Publications
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.student_attendance; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.weekly_reports; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.monthly_payments; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.halaqahs; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.students; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.messages; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.homework_assignments; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.homework_submissions; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.absence_requests; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';



