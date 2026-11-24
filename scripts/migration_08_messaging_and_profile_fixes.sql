-- ==============================================================================
-- MIGRATION 08: END-TO-END MESSAGING REPAIR, CONTACT DIRECTORY RPCs & PROFILE/STORAGE RLS
-- ==============================================================================
-- Idempotent migration safe to run repeatedly in the Supabase SQL Editor.
-- Fixes both pre-migration_05 schema drift and post-migration_05 RLS gaps:
--   1. Ensures conversations, conversation_participants, and messages have all
--      required columns and Realtime publication membership.
--   2. Syncs legacy participant_ids <-> conversation_participants rows.
--   3. Replaces recursive policies with non-recursive SECURITY DEFINER helpers and
--      restores non-admin UPDATE on conversations (dropped in migration_05).
--   4. Adds get_messageable_contacts() and hardens create_direct_conversation().
--   5. Aligns Storage object policies (avatars, chat_attachments, voice_messages)
--      and reasserts safe self-service profile editing for all active roles.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. ENSURE MESSAGING SCHEMA & ALL REQUIRED COLUMNS
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT,
    last_message TEXT,
    last_message_time TIMESTAMPTZ DEFAULT NOW(),
    is_group BOOLEAN DEFAULT FALSE,
    group_type TEXT DEFAULT 'direct_admin',
    halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL,
    participant_ids TEXT[] DEFAULT '{}',
    participant_names TEXT[] DEFAULT '{}',
    unread_count INT DEFAULT 0,
    is_pinned BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS title TEXT;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message TEXT;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS last_message_time TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_group BOOLEAN DEFAULT FALSE;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS group_type TEXT DEFAULT 'direct_admin';
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS halaqah_id UUID REFERENCES public.halaqahs(id) ON DELETE SET NULL;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS participant_ids TEXT[] DEFAULT '{}';
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS participant_names TEXT[] DEFAULT '{}';
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS unread_count INT DEFAULT 0;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN DEFAULT FALSE;
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.conversations ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

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
    content TEXT NOT NULL DEFAULT '',
    message_type TEXT DEFAULT 'text',
    media_url TEXT,
    attachment_url TEXT,
    attachment_name TEXT,
    audio_duration INT,
    is_read BOOLEAN DEFAULT FALSE,
    is_edited BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_name TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS sender_role TEXT DEFAULT 'parent';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS content TEXT NOT NULL DEFAULT '';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text';
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_name TEXT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS audio_duration INT;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_edited BOOLEAN DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_conversations_last_msg_time
    ON public.conversations (last_message_time DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_ids
    ON public.conversations USING GIN (participant_ids);
CREATE INDEX IF NOT EXISTS idx_conversation_participants_user
    ON public.conversation_participants (user_id, conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_created
    ON public.messages (conversation_id, created_at ASC);

-- ------------------------------------------------------------------------------
-- 2. SYNC LEGACY PARTICIPANTS & ENSURE REALTIME PUBLICATION
-- ------------------------------------------------------------------------------
INSERT INTO public.conversation_participants (conversation_id, user_id)
SELECT c.id, p.id
FROM public.conversations c
CROSS JOIN LATERAL UNNEST(COALESCE(c.participant_ids, '{}')) AS raw_uid
JOIN public.profiles p ON p.id::text = raw_uid
ON CONFLICT (conversation_id, user_id) DO NOTHING;

UPDATE public.conversations c
SET
    participant_ids = synced.ids,
    participant_names = synced.names
FROM (
    SELECT
        cp.conversation_id,
        ARRAY_AGG(cp.user_id::text ORDER BY cp.user_id::text) AS ids,
        ARRAY_AGG(COALESCE(NULLIF(TRIM(p.full_name), ''), p.email, 'User') ORDER BY cp.user_id::text) AS names
    FROM public.conversation_participants cp
    JOIN public.profiles p ON p.id = cp.user_id
    GROUP BY cp.conversation_id
) synced
WHERE c.id = synced.conversation_id
  AND (
      COALESCE(array_length(c.participant_ids, 1), 0) < array_length(synced.ids, 1)
      OR COALESCE(array_length(c.participant_names, 1), 0) = 0
  );

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = 'conversations'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM pg_publication_tables
            WHERE pubname = 'supabase_realtime'
              AND schemaname = 'public'
              AND tablename = 'messages'
        ) THEN
            ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
        END IF;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 3. NON-RECURSIVE MEMBERSHIP HELPERS
-- ------------------------------------------------------------------------------
-- SECURITY DEFINER helpers bypass table RLS cleanly (provided they are owned by
-- the table owner / postgres), preventing 42P17 mutual recursion between
-- conversations and conversation_participants.
CREATE OR REPLACE FUNCTION public.is_conversation_participant(p_conversation_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT public.is_active_user()
       AND (
           EXISTS (
               SELECT 1
               FROM public.conversation_participants cp
               WHERE cp.conversation_id = p_conversation_id
                 AND cp.user_id = auth.uid()
           )
           OR EXISTS (
               SELECT 1
               FROM public.conversations c
               WHERE c.id = p_conversation_id
                 AND auth.uid()::text = ANY(COALESCE(c.participant_ids, '{}'))
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
           OR public.is_conversation_participant(p_conv_id)
       );
$$;

REVOKE ALL ON FUNCTION public.is_conversation_participant(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_conversation_member(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_conversation_participant(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_conversation_member(UUID) TO authenticated;

-- ------------------------------------------------------------------------------
-- 4. REBUILD CLEAN MESSAGING RLS POLICIES
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- conversations
DROP POLICY IF EXISTS "Participants view conversations" ON public.conversations;
DROP POLICY IF EXISTS "Participants and admins view conversations" ON public.conversations;
DROP POLICY IF EXISTS "Participants update conversations" ON public.conversations;
DROP POLICY IF EXISTS "Participants and admins update conversations" ON public.conversations;
DROP POLICY IF EXISTS "Authenticated users create conversations" ON public.conversations;
DROP POLICY IF EXISTS "Admins manage conversations" ON public.conversations;
DROP POLICY IF EXISTS "Admins insert conversations" ON public.conversations;
DROP POLICY IF EXISTS "Admins delete conversations" ON public.conversations;

CREATE POLICY "Participants and admins view conversations"
ON public.conversations FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_conversation_participant(id)
    )
);

-- Critical: non-admin participants must be allowed to update last_message &
-- last_message_time when sending messages, without letting them reassign participants.
CREATE POLICY "Participants and admins update conversations"
ON public.conversations FOR UPDATE TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_conversation_participant(id)
    )
)
WITH CHECK (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_conversation_participant(id)
    )
);

CREATE POLICY "Admins insert conversations"
ON public.conversations FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

CREATE POLICY "Admins delete conversations"
ON public.conversations FOR DELETE TO authenticated
USING (public.is_admin());

-- conversation_participants
DROP POLICY IF EXISTS "Authenticated users view conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Participants and admins manage conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Members view conversation participants" ON public.conversation_participants;
DROP POLICY IF EXISTS "Admins manage conversation participants" ON public.conversation_participants;

CREATE POLICY "Members view conversation participants"
ON public.conversation_participants FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR user_id = auth.uid()
        OR public.is_conversation_participant(conversation_id)
    )
);

CREATE POLICY "Admins manage conversation participants"
ON public.conversation_participants FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- messages
DROP POLICY IF EXISTS "Participants read messages" ON public.messages;
DROP POLICY IF EXISTS "Participants send messages" ON public.messages;
DROP POLICY IF EXISTS "Senders update own messages" ON public.messages;
DROP POLICY IF EXISTS "Senders delete own messages" ON public.messages;

CREATE POLICY "Participants read messages"
ON public.messages FOR SELECT TO authenticated
USING (
    public.is_active_user()
    AND (
        public.is_admin()
        OR public.is_conversation_participant(conversation_id)
    )
);

CREATE POLICY "Participants send messages"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
    public.is_active_user()
    AND sender_id = auth.uid()
    AND (
        public.is_admin()
        OR public.is_conversation_participant(conversation_id)
    )
);

CREATE POLICY "Senders update own messages"
ON public.messages FOR UPDATE TO authenticated
USING (
    public.is_active_user()
    AND (sender_id = auth.uid() OR public.is_admin())
)
WITH CHECK (
    public.is_active_user()
    AND (sender_id = auth.uid() OR public.is_admin())
);

CREATE POLICY "Senders delete own messages"
ON public.messages FOR DELETE TO authenticated
USING (
    public.is_admin()
    OR (public.is_active_user() AND sender_id = auth.uid())
);

-- ------------------------------------------------------------------------------
-- 5. MESSAGEABLE CONTACTS DIRECTORY & DIRECT CONVERSATION RPCs
-- ------------------------------------------------------------------------------
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

        IF COALESCE(array_length(v_existing.participant_ids, 1), 0) < 2
           OR NOT (auth.uid()::text = ANY(COALESCE(v_existing.participant_ids, '{}')))
           OR NOT (p_other_user_id::text = ANY(COALESCE(v_existing.participant_ids, '{}'))) THEN
            UPDATE public.conversations
            SET
                participant_ids = ARRAY[auth.uid()::text, p_other_user_id::text],
                participant_names = ARRAY[v_caller_name, v_other_name]
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
    v_title := COALESCE(NULLIF(TRIM(COALESCE(p_title, '')), ''), v_other_name);

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
-- 6. STORAGE OBJECT POLICIES (AVATARS, CHAT ATTACHMENTS, VOICE MESSAGES)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Avatars read active" ON storage.objects;
DROP POLICY IF EXISTS "Avatars insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Avatars update scoped" ON storage.objects;
DROP POLICY IF EXISTS "Avatars delete scoped" ON storage.objects;

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

CREATE POLICY "Avatars update scoped"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'avatars'
    AND public.is_active_user()
    AND (
        public.is_admin()
        OR (storage.foldername(name))[1] = auth.uid()::text
    )
)
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

DROP POLICY IF EXISTS "Chat media read scoped" ON storage.objects;
DROP POLICY IF EXISTS "Chat media insert scoped" ON storage.objects;
DROP POLICY IF EXISTS "Chat media delete scoped" ON storage.objects;

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
            AND public.is_conversation_participant(((storage.foldername(name))[2])::uuid)
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
            AND public.is_conversation_participant(((storage.foldername(name))[2])::uuid)
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

-- ------------------------------------------------------------------------------
-- 7. REASSERT SELF-SERVICE PROFILE UPDATE POLICY (ALL ACTIVE ROLES)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users update own safe profile fields" ON public.profiles;

CREATE POLICY "Users update own safe profile fields"
ON public.profiles FOR UPDATE TO authenticated
USING (auth.uid() = id AND public.is_active_user())
WITH CHECK (
    auth.uid() = id
    AND public.is_active_user()
    AND role::text = public.current_user_role()
    AND COALESCE(is_suspended, FALSE) = FALSE
);
