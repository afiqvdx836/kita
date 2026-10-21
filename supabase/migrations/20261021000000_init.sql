-- Kita MVP: couples, pairing via invite code, shared notes and tasks.
-- Every shared row carries couple_id; RLS limits access to your own couple.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------- tables

create table public.couples (
  id             uuid primary key default gen_random_uuid(),
  together_since date,
  created_at     timestamptz not null default now()
);

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  couple_id    uuid references public.couples (id) on delete set null,
  created_at   timestamptz not null default now()
);
create index profiles_couple_id_idx on public.profiles (couple_id);

create table public.invites (
  code       text primary key,
  couple_id  uuid not null references public.couples (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '7 days',
  used_at    timestamptz
);
create index invites_couple_id_idx on public.invites (couple_id);

create table public.notes (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  author_id  uuid references auth.users (id) on delete set null,
  title      text not null default '',
  body       text not null default '',
  pinned     boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index notes_couple_id_idx on public.notes (couple_id, updated_at desc);

create table public.tasks (
  id         uuid primary key default gen_random_uuid(),
  couple_id  uuid not null references public.couples (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  title      text not null check (length(trim(title)) > 0),
  done       boolean not null default false,
  done_by    uuid references auth.users (id) on delete set null,
  done_at    timestamptz,
  due_date   date,
  created_at timestamptz not null default now()
);
create index tasks_couple_id_idx on public.tasks (couple_id, created_at);

-- ---------------------------------------------------------------- helpers

-- security definer so policies can read profiles without recursing into RLS.
create function public.my_couple_id()
returns uuid
language sql stable security definer set search_path = ''
as $$
  select couple_id from public.profiles where id = auth.uid()
$$;

create function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger notes_touch_updated_at
  before update on public.notes
  for each row execute function public.touch_updated_at();

-- Stamps who completed a task, so the client cannot fake it.
create function public.stamp_task_done()
returns trigger
language plpgsql
as $$
begin
  if new.done and not coalesce(old.done, false) then
    new.done_by := auth.uid();
    new.done_at := now();
  elsif not new.done then
    new.done_by := null;
    new.done_at := null;
  end if;
  return new;
end;
$$;

create trigger tasks_stamp_done
  before insert or update of done on public.tasks
  for each row execute function public.stamp_task_done();

-- ---------------------------------------------------------------- pairing RPCs

-- Returns the caller's active invite code, creating a solo couple and a
-- fresh code when needed. Fails once the couple already has two members.
create function public.create_invite()
returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_couple_id uuid;
  v_code      text;
  v_alphabet  constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  v_bytes     bytea;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select couple_id into v_couple_id from public.profiles where id = v_uid for update;

  if v_couple_id is null then
    insert into public.couples default values returning id into v_couple_id;
    update public.profiles set couple_id = v_couple_id where id = v_uid;
  elsif (select count(*) from public.profiles where couple_id = v_couple_id) >= 2 then
    raise exception 'already_paired';
  end if;

  select code into v_code
  from public.invites
  where couple_id = v_couple_id and used_at is null and expires_at > now()
  order by expires_at desc
  limit 1;

  if v_code is not null then
    return v_code;
  end if;

  loop
    v_bytes := extensions.gen_random_bytes(6);
    v_code := '';
    for i in 0..5 loop
      v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % length(v_alphabet)) + 1, 1);
    end loop;
    exit when not exists (select 1 from public.invites where code = v_code);
  end loop;

  insert into public.invites (code, couple_id, created_by) values (v_code, v_couple_id, v_uid);
  return v_code;
end;
$$;

-- Joins the couple behind an invite code. A joiner who only had a solo
-- couple brings their notes and tasks along; the empty couple is removed.
create function public.join_couple(p_code text)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid        uuid := auth.uid();
  v_invite     public.invites%rowtype;
  v_old_couple uuid;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_invite
  from public.invites
  where code = upper(trim(p_code))
  for update;

  if not found or v_invite.used_at is not null or v_invite.expires_at <= now() then
    raise exception 'invalid_code';
  end if;
  if v_invite.created_by = v_uid then
    raise exception 'own_code';
  end if;
  if (select count(*) from public.profiles where couple_id = v_invite.couple_id) >= 2 then
    raise exception 'couple_full';
  end if;

  select couple_id into v_old_couple from public.profiles where id = v_uid for update;

  if v_old_couple is not null then
    if (select count(*) from public.profiles where couple_id = v_old_couple) > 1 then
      raise exception 'already_paired';
    end if;
    update public.notes set couple_id = v_invite.couple_id where couple_id = v_old_couple;
    update public.tasks set couple_id = v_invite.couple_id where couple_id = v_old_couple;
  end if;

  update public.profiles set couple_id = v_invite.couple_id where id = v_uid;
  update public.invites set used_at = now() where code = v_invite.code;

  if v_old_couple is not null then
    delete from public.couples where id = v_old_couple;
  end if;

  return v_invite.couple_id;
end;
$$;

-- Leaves the current couple. Shared data stays with the partner; the couple
-- is deleted once nobody is left in it.
create function public.leave_couple()
returns void
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid       uuid := auth.uid();
  v_couple_id uuid;
begin
  select couple_id into v_couple_id from public.profiles where id = v_uid for update;
  if v_couple_id is null then
    return;
  end if;

  update public.profiles set couple_id = null where id = v_uid;
  delete from public.invites where couple_id = v_couple_id;

  if not exists (select 1 from public.profiles where couple_id = v_couple_id) then
    delete from public.couples where id = v_couple_id;
  end if;
end;
$$;

revoke execute on function public.create_invite() from public, anon;
revoke execute on function public.join_couple(text) from public, anon;
revoke execute on function public.leave_couple() from public, anon;
grant execute on function public.create_invite() to authenticated;
grant execute on function public.join_couple(text) to authenticated;
grant execute on function public.leave_couple() to authenticated;

-- ---------------------------------------------------------------- RLS

alter table public.couples  enable row level security;
alter table public.profiles enable row level security;
alter table public.invites  enable row level security;
alter table public.notes    enable row level security;
alter table public.tasks    enable row level security;

-- Couples: read and edit the date of your own couple; rows are created by RPC.
create policy couples_select on public.couples
  for select to authenticated using (id = public.my_couple_id());
create policy couples_update on public.couples
  for update to authenticated
  using (id = public.my_couple_id()) with check (id = public.my_couple_id());
revoke insert, update, delete on public.couples from anon, authenticated;
grant update (together_since) on public.couples to authenticated;

-- Profiles: see yourself and your partner; only your own name is editable.
-- couple_id changes go through the pairing RPCs.
create policy profiles_select on public.profiles
  for select to authenticated
  using (id = auth.uid() or couple_id = public.my_couple_id());
create policy profiles_update on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Invites: no direct access, RPC only.
revoke all on public.invites from anon, authenticated;

-- Notes and tasks: full access inside your couple.
create policy notes_select on public.notes
  for select to authenticated using (couple_id = public.my_couple_id());
create policy notes_insert on public.notes
  for insert to authenticated
  with check (couple_id = public.my_couple_id() and author_id = auth.uid());
create policy notes_update on public.notes
  for update to authenticated
  using (couple_id = public.my_couple_id()) with check (couple_id = public.my_couple_id());
create policy notes_delete on public.notes
  for delete to authenticated using (couple_id = public.my_couple_id());

create policy tasks_select on public.tasks
  for select to authenticated using (couple_id = public.my_couple_id());
create policy tasks_insert on public.tasks
  for insert to authenticated
  with check (couple_id = public.my_couple_id() and created_by = auth.uid());
create policy tasks_update on public.tasks
  for update to authenticated
  using (couple_id = public.my_couple_id()) with check (couple_id = public.my_couple_id());
create policy tasks_delete on public.tasks
  for delete to authenticated using (couple_id = public.my_couple_id());

revoke all on public.notes, public.tasks from anon;

-- ---------------------------------------------------------------- realtime

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime
      add table public.couples, public.profiles, public.notes, public.tasks;
  end if;
end;
$$;
