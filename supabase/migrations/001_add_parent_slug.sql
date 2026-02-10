-- Run this if you already have the pages table (adds parent_slug column)

ALTER TABLE public.pages
ADD COLUMN IF NOT EXISTS parent_slug TEXT REFERENCES public.pages(slug) ON DELETE SET NULL;
