-- HCH Workforce initial database
-- Run this entire script once in Supabase SQL Editor.
-- It creates secure profile and course tables for the first platform stage.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('student','professional','organization')),
  email text,
  display_name text not null,
  headline text,
  location text,
  skills text[] not null default '{}',
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile"
on public.profiles for select to authenticated
using (auth.uid() = id);

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
on public.profiles for insert to authenticated
with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, role, email, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'role','student'),
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name','HCH Workforce Member')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text unique not null,
  description text,
  level text default 'Beginner',
  published boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.courses enable row level security;

drop policy if exists "Published courses are visible to signed in users" on public.courses;
create policy "Published courses are visible to signed in users"
on public.courses for select to authenticated
using (published = true);

-- Starter course. Edit or remove this row later if desired.
insert into public.courses (title, slug, description, level, published)
values (
  'Introduction to Health Data and Community Practice',
  'introduction-health-data-community-practice',
  'A beginner-friendly foundation for understanding health data, community practice and practical field work.',
  'Beginner',
  true
)
on conflict (slug) do nothing;

-- IMPORTANT:
-- Keep secret/service-role keys out of the website and GitHub.
-- The browser uses only the publishable key with RLS enabled.
