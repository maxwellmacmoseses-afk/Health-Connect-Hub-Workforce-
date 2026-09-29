-- HCH Workforce: learning + role-specific profile expansion
alter table public.profiles
  add column if not exists institution text,
  add column if not exists course_of_study text,
  add column if not exists academic_level text,
  add column if not exists qualifications text,
  add column if not exists experience text,
  add column if not exists professional_registration text,
  add column if not exists services text,
  add column if not exists organization_type text,
  add column if not exists workforce_needs text,
  add column if not exists website text;

create table if not exists public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  title text not null,
  description text,
  module_order integer not null default 1,
  created_at timestamptz not null default now()
);

alter table public.course_modules enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='course_modules'
    and policyname='Authenticated users can view modules of published courses'
  ) then
    create policy "Authenticated users can view modules of published courses"
    on public.course_modules
    for select to authenticated
    using (
      exists (
        select 1 from public.courses c
        where c.id = course_id and c.published = true
      )
    );
  end if;
end $$;

create table if not exists public.course_lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.course_modules(id) on delete cascade,
  title text not null,
  content text,
  lesson_order integer not null default 1,
  created_at timestamptz not null default now()
);

alter table public.course_lessons enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='course_lessons'
    and policyname='Authenticated users can view lessons of published courses'
  ) then
    create policy "Authenticated users can view lessons of published courses"
    on public.course_lessons
    for select to authenticated
    using (
      exists (
        select 1
        from public.course_modules m
        join public.courses c on c.id = m.course_id
        where m.id = module_id and c.published = true
      )
    );
  end if;
end $$;

create table if not exists public.course_enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  enrolled_at timestamptz not null default now(),
  unique(user_id, course_id)
);

alter table public.course_enrollments enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='course_enrollments'
    and policyname='Users can view their own enrollments'
  ) then
    create policy "Users can view their own enrollments"
    on public.course_enrollments for select to authenticated
    using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='course_enrollments'
    and policyname='Users can enroll themselves'
  ) then
    create policy "Users can enroll themselves"
    on public.course_enrollments for insert to authenticated
    with check (auth.uid() = user_id);
  end if;
end $$;

create table if not exists public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id uuid not null references public.course_lessons(id) on delete cascade,
  completed boolean not null default false,
  completed_at timestamptz,
  unique(user_id, lesson_id)
);

alter table public.lesson_progress enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='lesson_progress'
    and policyname='Users can view their own lesson progress'
  ) then
    create policy "Users can view their own lesson progress"
    on public.lesson_progress for select to authenticated
    using (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='lesson_progress'
    and policyname='Users can create their own lesson progress'
  ) then
    create policy "Users can create their own lesson progress"
    on public.lesson_progress for insert to authenticated
    with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='lesson_progress'
    and policyname='Users can update their own lesson progress'
  ) then
    create policy "Users can update their own lesson progress"
    on public.lesson_progress for update to authenticated
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);
  end if;
end $$;

-- Seed modules and lessons for the starter course.
do $$
declare
  cid uuid;
  m1 uuid;
  m2 uuid;
  m3 uuid;
begin
  select id into cid from public.courses
  where slug = 'introduction-health-data-community-practice';

  if cid is not null then
    insert into public.course_modules(course_id,title,description,module_order)
    select cid,'Module 1: Understanding Health Data','What health data is, why it matters, and common sources of community health data.',1
    where not exists (select 1 from public.course_modules where course_id=cid and module_order=1);

    insert into public.course_modules(course_id,title,description,module_order)
    select cid,'Module 2: Collecting and Documenting Data','Practical approaches to basic health data collection, documentation and data quality.',2
    where not exists (select 1 from public.course_modules where course_id=cid and module_order=2);

    insert into public.course_modules(course_id,title,description,module_order)
    select cid,'Module 3: Applying Data in Community Practice','Turning simple data into useful insights for outreach, monitoring and community action.',3
    where not exists (select 1 from public.course_modules where course_id=cid and module_order=3);

    select id into m1 from public.course_modules where course_id=cid and module_order=1;
    select id into m2 from public.course_modules where course_id=cid and module_order=2;
    select id into m3 from public.course_modules where course_id=cid and module_order=3;

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m1,'What is Health Data?','Health data is information collected about people, health conditions, services, behaviours, environments and outcomes. In this lesson, learners identify common examples and understand why reliable data supports better decisions.',1
    where not exists (select 1 from public.course_lessons where module_id=m1 and lesson_order=1);

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m1,'Sources of Community Health Data','Explore surveys, registers, screening activities, outreach records, routine health records and community observations as common sources of health information.',2
    where not exists (select 1 from public.course_lessons where module_id=m1 and lesson_order=2);

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m2,'Basic Data Collection','Learn how to define what you need to collect, use simple collection tools, reduce missing information and document field activities consistently.',1
    where not exists (select 1 from public.course_lessons where module_id=m2 and lesson_order=1);

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m2,'Data Quality and Documentation','Understand completeness, consistency, accuracy and timely documentation. Learn why clear records matter for monitoring and reporting.',2
    where not exists (select 1 from public.course_lessons where module_id=m2 and lesson_order=2);

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m3,'From Data to Insight','Learn how to summarise simple findings and identify patterns that can inform community health activities.',1
    where not exists (select 1 from public.course_lessons where module_id=m3 and lesson_order=1);

    insert into public.course_lessons(module_id,title,content,lesson_order)
    select m3,'Using Findings in Projects','Apply basic findings to outreach planning, monitoring, documentation and communication while protecting personal information.',2
    where not exists (select 1 from public.course_lessons where module_id=m3 and lesson_order=2);
  end if;
end $$;