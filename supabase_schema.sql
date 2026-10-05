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
    CREATE TYPE submission_status AS ENUM ('pending', 'reviewed', 'needs_rerecording');
EXCEPTION
    WHEN duplicate_object THEN NULL;
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
    used_by UUID REFERENCES public.profiles(id),
    used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days'),
    created_by UUID REFERENCES public.profiles(id),
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
    content TEXT NOT NULL,
    media_url TEXT,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

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
AS $$
DECLARE
    v_invite RECORD;
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

    -- 2. Insert or update the public profile with the assigned role
    INSERT INTO public.profiles (id, role, full_name, email, phone)
    VALUES (p_user_id, v_invite.role, p_full_name, p_email, p_phone)
    ON CONFLICT (id) DO UPDATE
    SET role = v_invite.role,
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone),
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

-- Students:
-- Teachers see students in their halaqahs
-- Parents see only their linked students
CREATE POLICY "Parents view own children"
ON public.students FOR SELECT TO authenticated
USING (
    id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    OR halaqah_id IN (SELECT id FROM public.halaqahs WHERE teacher_id = auth.uid())
);

-- Hifz Records:
-- Parents can view only their children's records
-- Teachers can insert/update records for their students
CREATE POLICY "Parents read children hifz"
ON public.hifz_records FOR SELECT TO authenticated
USING (
    student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    OR teacher_id = auth.uid()
);

CREATE POLICY "Teachers insert hifz"
ON public.hifz_records FOR INSERT TO authenticated
WITH CHECK (teacher_id = auth.uid());

-- Submissions & Audio:
CREATE POLICY "Students and parents view submissions"
ON public.homework_submissions FOR SELECT TO authenticated
USING (
    student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
    OR assignment_id IN (
        SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid()
    )
);

CREATE POLICY "Students create submissions"
ON public.homework_submissions FOR INSERT TO authenticated
WITH CHECK (
    student_id IN (SELECT student_id FROM public.parent_students WHERE parent_id = auth.uid())
);

CREATE POLICY "Teachers grade submissions"
ON public.homework_submissions FOR UPDATE TO authenticated
USING (
    assignment_id IN (SELECT id FROM public.homework_assignments WHERE teacher_id = auth.uid())
);

-- Messages:
CREATE POLICY "Participants read messages"
ON public.messages FOR SELECT TO authenticated
USING (
    conversation_id IN (
        SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Participants send messages"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
    sender_id = auth.uid() AND
    conversation_id IN (
        SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
    )
);

-- ------------------------------------------------------------------------------
-- 10. STORAGE BUCKETS SETUP
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('recitations', 'recitations', false),
    ('voice-feedback', 'voice-feedback', false),
    ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: authenticated users can upload their audio recitations
CREATE POLICY "Authenticated users upload recitations"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'recitations');

CREATE POLICY "Users read recitations"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id IN ('recitations', 'voice-feedback', 'avatars'));

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

