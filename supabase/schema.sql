-- Run this in your Supabase SQL Editor to create the pages table for the wiki
-- If you already have the table, run supabase/migrations/001_add_parent_slug.sql instead to add parent_slug

CREATE TABLE IF NOT EXISTS public.pages (
  slug TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  parent_slug TEXT REFERENCES public.pages(slug) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS (required for API access)
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read pages (public wiki)
CREATE POLICY "Allow public read"
  ON public.pages FOR SELECT
  USING (true);

-- Allow anyone to insert new pages
CREATE POLICY "Allow public insert"
  ON public.pages FOR INSERT
  WITH CHECK (true);

-- Allow anyone to update pages (upsert for editing)
CREATE POLICY "Allow public update"
  ON public.pages FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Allow anyone to delete pages (optional - remove if you want read-only delete)
CREATE POLICY "Allow public delete"
  ON public.pages FOR DELETE
  USING (true);
