create extension if not exists pgcrypto;

-- Public student resources
create table if not exists public.resources(
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  course_code text,
  course_title text,
  level integer check(level between 100 and 400),
  semester text,
  resource_type text not null,
  file_path text not null,
  file_name text not null,
  file_size bigint,
  downloads integer not null default 0,
  created_at timestamptz not null default now(),
  uploaded_by uuid references auth.users(id)
);

alter table public.resources enable row level security;
drop policy if exists "public read resources" on public.resources;
create policy "public read resources" on public.resources for select to anon,authenticated using(true);
drop policy if exists "auth insert resources" on public.resources;
create policy "auth insert resources" on public.resources for insert to authenticated with check(auth.uid()=uploaded_by);
drop policy if exists "auth update resources" on public.resources;
create policy "auth update resources" on public.resources for update to authenticated using(true) with check(true);
drop policy if exists "auth delete resources" on public.resources;
create policy "auth delete resources" on public.resources for delete to authenticated using(true);

create or replace function public.increment_download(resource_id uuid)
returns void language sql security definer set search_path=public as $$
  update public.resources set downloads=downloads+1 where id=resource_id;
$$;
grant execute on function public.increment_download(uuid) to anon,authenticated;

-- Existing public resource bucket
insert into storage.buckets(id,name,public)
values('scsn-resources','scsn-resources',true)
on conflict(id) do update set public=true;

drop policy if exists "public view scsn files" on storage.objects;
create policy "public view scsn files" on storage.objects for select to anon,authenticated using(bucket_id='scsn-resources');
drop policy if exists "auth upload scsn files" on storage.objects;
create policy "auth upload scsn files" on storage.objects for insert to authenticated with check(bucket_id='scsn-resources');
drop policy if exists "auth update scsn files" on storage.objects;
create policy "auth update scsn files" on storage.objects for update to authenticated using(bucket_id='scsn-resources') with check(bucket_id='scsn-resources');
drop policy if exists "auth delete scsn files" on storage.objects;
create policy "auth delete scsn files" on storage.objects for delete to authenticated using(bucket_id='scsn-resources');

-- Examination results
-- The result files are encrypted in the browser before upload. The bucket can therefore be public
-- without exposing the readable result. The plaintext is only produced after password verification.
create table if not exists public.exam_results(
  id uuid primary key default gen_random_uuid(),
  title text not null,
  level integer not null check(level between 100 and 400),
  semester text,
  session text,
  file_path text not null,
  file_name text not null,
  file_size bigint,
  mime_type text,
  salt text not null,
  iv text not null,
  password_hash text not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  uploaded_by uuid references auth.users(id)
);

alter table public.exam_results enable row level security;
alter table public.exam_results add column if not exists mime_type text;

-- Students must not be able to query result rows directly. They use the password-verification RPC below.
drop policy if exists "no public exam result reads" on public.exam_results;
drop policy if exists "auth exam result reads" on public.exam_results;

drop policy if exists "auth exam result inserts" on public.exam_results;
create policy "auth exam result inserts" on public.exam_results
for insert to authenticated with check(auth.uid()=uploaded_by);
drop policy if exists "auth exam result updates" on public.exam_results;
create policy "auth exam result updates" on public.exam_results
for update to authenticated using(true) with check(true);
drop policy if exists "auth exam result deletes" on public.exam_results;
create policy "auth exam result deletes" on public.exam_results
for delete to authenticated using(true);

insert into storage.buckets(id,name,public)
values('scsn-results','scsn-results',false)
on conflict(id) do update set public=false;

drop policy if exists "public view encrypted results" on storage.objects;
create policy "public view encrypted results" on storage.objects
for select to anon,authenticated using(bucket_id='scsn-results');
drop policy if exists "auth upload encrypted results" on storage.objects;
create policy "auth upload encrypted results" on storage.objects
for insert to authenticated with check(bucket_id='scsn-results');
drop policy if exists "auth update encrypted results" on storage.objects;
create policy "auth update encrypted results" on storage.objects
for update to authenticated using(bucket_id='scsn-results') with check(bucket_id='scsn-results');
drop policy if exists "auth delete encrypted results" on storage.objects;
create policy "auth delete encrypted results" on storage.objects
for delete to authenticated using(bucket_id='scsn-results');



create or replace function public.create_exam_result(
  result_title text, result_level integer, result_semester text, result_session text,
  result_file_path text, result_file_name text, result_file_size bigint, result_mime_type text,
  result_salt text, result_iv text, result_password text, result_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if result_level not between 100 and 400 then raise exception 'Invalid level'; end if;
  if length(coalesce(result_password,'')) < 4 then raise exception 'Password must be at least 4 characters'; end if;
  insert into public.exam_results(title,level,semester,session,file_path,file_name,file_size,mime_type,salt,iv,password_hash,expires_at,uploaded_by)
  values(result_title,result_level,result_semester,result_session,result_file_path,result_file_name,result_file_size,result_mime_type,result_salt,result_iv,crypt(result_password,gen_salt('bf',12)),result_expires_at,auth.uid())
  returning id into new_id;
  return new_id;
end;
$$;
revoke all on function public.create_exam_result(text,integer,text,text,text,text,bigint,text,text,text,text,timestamptz) from public;
grant execute on function public.create_exam_result(text,integer,text,text,text,text,bigint,text,text,text,text,timestamptz) to authenticated;



create or replace function public.list_exam_results_admin()
returns table(
  id uuid, title text, level integer, semester text, session text, file_path text, file_name text, expires_at timestamptz, created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select id,title,level,semester,session,file_path,file_name,expires_at,created_at
  from public.exam_results
  order by created_at desc;
$$;
revoke all on function public.list_exam_results_admin() from public;
grant execute on function public.list_exam_results_admin() to authenticated;

-- Password verification function. It returns only an active result's encrypted-file metadata.
create or replace function public.verify_exam_result(result_id uuid, result_password text)
returns table(
  id uuid,
  title text,
  level integer,
  semester text,
  session text,
  file_path text,
  file_name text,
  file_size bigint,
  mime_type text,
  salt text,
  iv text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select r.id,r.title,r.level,r.semester,r.session,r.file_path,r.file_name,r.file_size,r.mime_type,r.salt,r.iv,r.expires_at
  from public.exam_results r
  where r.id = result_id
    and r.expires_at > now()
    and crypt(result_password, r.password_hash) = r.password_hash;
end;
$$;
revoke all on function public.verify_exam_result(uuid,text) from public;
grant execute on function public.verify_exam_result(uuid,text) to anon,authenticated;

-- Convenience function for the public results list. It never exposes password hashes.
create or replace function public.list_active_exam_results()
returns table(
  id uuid,
  title text,
  level integer,
  semester text,
  session text,
  expires_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select id,title,level,semester,session,expires_at
  from public.exam_results
  where expires_at > now()
  order by level, created_at desc;
$$;
revoke all on function public.list_active_exam_results() from public;
grant execute on function public.list_active_exam_results() to anon,authenticated;
