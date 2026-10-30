-- ==============================================================================
-- KHEYRUKUM SCHEMA REPAIR & FEATURE ENHANCEMENT MIGRATION (M1)
-- ==============================================================================
-- 1. Fix Announcements Schema (PGRST204 Resolution)
-- ------------------------------------------------------------------------------
ALTER TABLE public.announcements 
ADD COLUMN IF NOT EXISTS attachment_name TEXT,
ADD COLUMN IF NOT EXISTS attachment_url TEXT;

-- 2. Fix Halaqahs Schema & Missing Columns
-- ------------------------------------------------------------------------------
ALTER TABLE public.halaqahs 
ADD COLUMN IF NOT EXISTS schedule TEXT DEFAULT 'Daily Recitation Session';

-- 3. Row Level Security Policies for Halaqahs
-- ------------------------------------------------------------------------------
ALTER TABLE public.halaqahs ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Authenticated users view halaqahs"
    ON public.halaqahs FOR SELECT TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins manage halaqahs"
    ON public.halaqahs FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers view and update assigned halaqah"
    ON public.halaqahs FOR UPDATE TO authenticated
    USING (teacher_id = auth.uid())
    WITH CHECK (teacher_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 4. Row Level Security Policies for Students & Parent Linking
-- ------------------------------------------------------------------------------
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_students ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Admins and teachers manage students"
    ON public.students FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role IN ('admin', 'teacher')
        )
        OR id IN (
            SELECT student_id FROM public.parent_students 
            WHERE parent_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role IN ('admin', 'teacher')
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins manage parent_students"
    ON public.parent_students FOR ALL TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
        OR parent_id = auth.uid()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() AND role = 'admin'
        )
        OR parent_id = auth.uid()
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Authenticated users view parent_students links"
    ON public.parent_students FOR SELECT TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 5. Row Level Security Policies for Homework Assignments
-- ------------------------------------------------------------------------------
ALTER TABLE public.homework_assignments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
    CREATE POLICY "Authenticated users view assignments"
    ON public.homework_assignments FOR SELECT TO authenticated
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Teachers and admins manage assignments"
    ON public.homework_assignments FOR ALL TO authenticated
    USING (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
    WITH CHECK (
        teacher_id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 6. Fix Conversations & Messages Schema and RLS
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS last_message TEXT,
ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ DEFAULT NOW(),
ADD COLUMN IF NOT EXISTS is_group BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS group_type TEXT DEFAULT 'direct_admin',
ADD COLUMN IF NOT EXISTS halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL;

ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS sender_name TEXT,
ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'parent',
ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text',
ADD COLUMN IF NOT EXISTS attachment_url TEXT,
ADD COLUMN IF NOT EXISTS attachment_name TEXT,
ADD COLUMN IF NOT EXISTS audio_duration INT;

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

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

-- 7. Supabase Cloud Storage Buckets Creation & RLS Policies
-- ------------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('announcement_attachments', 'announcement_attachments', true),
    ('chat_attachments', 'chat_attachments', true),
    ('voice_messages', 'voice_messages', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DO $$ BEGIN
    CREATE POLICY "Public and authenticated view buckets"
    ON storage.buckets FOR SELECT TO public
    USING (true);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins and authenticated upload announcement attachments"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (bucket_id = 'announcement_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Anyone read announcement attachments"
    ON storage.objects FOR SELECT TO authenticated
    USING (bucket_id = 'announcement_attachments');
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
    CREATE POLICY "Public read announcement attachments"
    ON storage.objects FOR SELECT TO anon
    USING (bucket_id = 'announcement_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Admins delete announcement attachments"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'announcement_attachments' 
        AND EXISTS (
            SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'
        )
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users delete chat attachments"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'chat_attachments');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE POLICY "Users delete voice messages"
    ON storage.objects FOR DELETE TO authenticated
    USING (bucket_id = 'voice_messages');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 8. Enable Realtime Publications for Dynamic Subscriptions
-- ------------------------------------------------------------------------------
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.halaqahs;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.students;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 9. Refresh PostgREST Schema Cache
-- ------------------------------------------------------------------------------
NOTIFY pgrst, 'reload schema';
