-- Migration 09: Add optional student sex/gender ('male' | 'female') to public.students
-- Idempotent and safe to run repeatedly in the Supabase SQL Editor.

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS gender TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'students_gender_check'
      AND conrelid = 'public.students'::regclass
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_gender_check
      CHECK (gender IN ('male', 'female'));
  END IF;
END $$;

COMMENT ON COLUMN public.students.gender IS
  'Student sex/gender: male or female (nullable for legacy records).';
