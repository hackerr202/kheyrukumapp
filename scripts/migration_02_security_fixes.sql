-- ==============================================================================
-- KHEYRUKUM MIGRATION 02: SECURITY & ROW LEVEL SECURITY (RLS) HARDENING (M4)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CONVERSATIONS SCHEMA ALIGNMENT (Fix PGRST204 & Chat Persistence)
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS participant_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS participant_names TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;

-- ------------------------------------------------------------------------------
-- 2. HARDEN ANNOUNCEMENTS RLS POLICIES (Prevent Unauthorized Posts/Deletions)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can delete announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins can update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins or creators can insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Authenticated users can read announcements" ON public.announcements;
DROP POLICY IF EXISTS "Public and authenticated read announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins insert announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins update announcements" ON public.announcements;
DROP POLICY IF EXISTS "Admins delete announcements" ON public.announcements;

CREATE POLICY "Public and authenticated read announcements"
ON public.announcements FOR SELECT TO public
USING (true);

CREATE POLICY "Admins insert announcements"
ON public.announcements FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins update announcements"
ON public.announcements FOR UPDATE TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins delete announcements"
ON public.announcements FOR DELETE TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ------------------------------------------------------------------------------
-- 3. HARDEN HALAQAHS RLS POLICIES (Drop Overly Permissive Policy)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can manage halaqahs" ON public.halaqahs;
DROP POLICY IF EXISTS "Admins manage halaqahs" ON public.halaqahs;

CREATE POLICY "Admins manage halaqahs"
ON public.halaqahs FOR ALL TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ------------------------------------------------------------------------------
-- 4. HARDEN STUDENTS RLS POLICIES (Drop Overly Permissive Policy)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can manage students" ON public.students;

-- ------------------------------------------------------------------------------
-- 5. HARDEN INVITATION CODES RLS POLICIES (Restrict to Admins)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Admins can manage invitation codes" ON public.invitation_codes;
DROP POLICY IF EXISTS "Admins manage invitation codes" ON public.invitation_codes;

CREATE POLICY "Admins manage invitation codes"
ON public.invitation_codes FOR ALL TO authenticated
USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ------------------------------------------------------------------------------
-- 6. HARDEN PARENT_STUDENTS RLS POLICIES (Prevent Student Mapping Leak & Recursion)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Authenticated users view parent_students links" ON public.parent_students;
DROP POLICY IF EXISTS "Authorized users view parent_students links" ON public.parent_students;

CREATE POLICY "Authorized users view parent_students links"
ON public.parent_students FOR SELECT TO authenticated
USING (
    parent_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'teacher'))
);

-- ------------------------------------------------------------------------------
-- 7. ENABLE AND DEFINE RLS FOR CONVERSATION_PARTICIPANTS
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users view conversation participants" ON public.conversation_participants;
CREATE POLICY "Authenticated users view conversation participants"
ON public.conversation_participants FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "Participants and admins manage conversation participants" ON public.conversation_participants;
CREATE POLICY "Participants and admins manage conversation participants"
ON public.conversation_participants FOR ALL TO authenticated
USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ------------------------------------------------------------------------------
-- 8. CONVERSATIONS RLS POLICIES
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants view conversations" ON public.conversations;
CREATE POLICY "Participants view conversations"
ON public.conversations FOR SELECT TO authenticated
USING (
    auth.uid()::text = ANY(participant_ids)
    OR id IN (SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS "Authenticated users create conversations" ON public.conversations;
CREATE POLICY "Authenticated users create conversations"
ON public.conversations FOR INSERT TO authenticated
WITH CHECK (
    auth.uid()::text = ANY(participant_ids)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    OR id IN (SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid())
);

DROP POLICY IF EXISTS "Participants update conversations" ON public.conversations;
CREATE POLICY "Participants update conversations"
ON public.conversations FOR UPDATE TO authenticated
USING (
    auth.uid()::text = ANY(participant_ids)
    OR id IN (SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ------------------------------------------------------------------------------
-- 9. MESSAGES RLS POLICIES
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Participants read messages" ON public.messages;
CREATE POLICY "Participants read messages"
ON public.messages FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = messages.conversation_id 
        AND (auth.uid()::text = ANY(c.participant_ids) OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
    )
    OR conversation_id IN (
        SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Participants send messages" ON public.messages;
CREATE POLICY "Participants send messages"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
    sender_id = auth.uid() 
    AND (
        EXISTS (
            SELECT 1 FROM public.conversations c 
            WHERE c.id = messages.conversation_id 
            AND (auth.uid()::text = ANY(c.participant_ids) OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
        )
        OR conversation_id IN (
            SELECT conversation_id FROM public.conversation_participants WHERE user_id = auth.uid()
        )
    )
);

-- ------------------------------------------------------------------------------
-- 10. STORAGE POLICIES: PUBLIC READ, AUTHENTICATED WRITE & UPSERT ON ALL BUCKETS
-- ------------------------------------------------------------------------------
-- Public Read
DROP POLICY IF EXISTS "Public and authenticated read announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public read announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Anyone read announcement attachments" ON storage.objects;
CREATE POLICY "Public read announcement attachments"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'announcement_attachments');

DROP POLICY IF EXISTS "Public and authenticated read chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users read chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Public read chat attachments" ON storage.objects;
CREATE POLICY "Public read chat attachments"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'chat_attachments');

DROP POLICY IF EXISTS "Public and authenticated read voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users read voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Public read voice messages" ON storage.objects;
CREATE POLICY "Public read voice messages"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'voice_messages');

-- Authenticated Write (INSERT)
DROP POLICY IF EXISTS "Authenticated upload chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users upload chat attachments" ON storage.objects;
CREATE POLICY "Authenticated upload chat attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'chat_attachments');

DROP POLICY IF EXISTS "Authenticated upload voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users upload voice messages" ON storage.objects;
CREATE POLICY "Authenticated upload voice messages"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'voice_messages');

DROP POLICY IF EXISTS "Admins and authenticated upload announcement attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated upload announcement attachments" ON storage.objects;
CREATE POLICY "Authenticated upload announcement attachments"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'announcement_attachments');

-- Authenticated Update (for upsert: true)
DROP POLICY IF EXISTS "Authenticated update storage objects" ON storage.objects;
CREATE POLICY "Authenticated update storage objects"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id IN ('announcement_attachments', 'chat_attachments', 'voice_messages'))
WITH CHECK (bucket_id IN ('announcement_attachments', 'chat_attachments', 'voice_messages'));

-- Owner & Admin Scoped Deletions
DROP POLICY IF EXISTS "Users delete chat attachments" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own chat attachments" ON storage.objects;
CREATE POLICY "Users delete own chat attachments"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'chat_attachments'
    AND (
        owner = auth.uid()
        OR (storage.foldername(name))[1] = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
);

DROP POLICY IF EXISTS "Users delete voice messages" ON storage.objects;
DROP POLICY IF EXISTS "Users delete own voice messages" ON storage.objects;
CREATE POLICY "Users delete own voice messages"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'voice_messages'
    AND (
        owner = auth.uid()
        OR (storage.foldername(name))[1] = auth.uid()::text
        OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
    )
);

-- Notify PostgREST schema reload
NOTIFY pgrst, 'reload schema';
