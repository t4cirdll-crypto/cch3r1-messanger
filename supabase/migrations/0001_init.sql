-- cch3r1-messanger :: initial schema
-- Таблицы: profiles / conversations / messages
-- RLS включён для всех таблиц.

create extension if not exists "pgcrypto";

--------------------------------------------------------------------------------
-- profiles
--------------------------------------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  username      text unique not null,
  display_name  text,
  avatar_url    text,
  is_online     boolean not null default false,
  last_seen     timestamptz not null default now(),
  created_at    timestamptz not null default now()
);

create index if not exists idx_profiles_username on public.profiles (lower(username));

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

drop policy if exists "profiles_insert_self" on public.profiles;
create policy "profiles_insert_self"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "profiles_update_self" on public.profiles;
create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

--------------------------------------------------------------------------------
-- conversations
--------------------------------------------------------------------------------
create table if not exists public.conversations (
  id               uuid primary key default gen_random_uuid(),
  user1_id         uuid not null,
  user2_id         uuid not null,
  last_message_id  uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  -- Пара (user1_id, user2_id) всегда хранится в порядке user1_id < user2_id,
  -- это обеспечивает уникальность диалога в обе стороны.
  constraint conversations_order check (user1_id < user2_id),
  constraint conversations_unique_pair unique (user1_id, user2_id),
  constraint conversations_user1_id_fkey
    foreign key (user1_id) references public.profiles(id) on delete cascade,
  constraint conversations_user2_id_fkey
    foreign key (user2_id) references public.profiles(id) on delete cascade
);

create index if not exists idx_conversations_user1 on public.conversations (user1_id);
create index if not exists idx_conversations_user2 on public.conversations (user2_id);
create index if not exists idx_conversations_updated_at on public.conversations (updated_at desc);

alter table public.conversations enable row level security;

drop policy if exists "conversations_select_participants" on public.conversations;
create policy "conversations_select_participants"
  on public.conversations for select
  to authenticated
  using (auth.uid() = user1_id or auth.uid() = user2_id);

drop policy if exists "conversations_insert_participants" on public.conversations;
create policy "conversations_insert_participants"
  on public.conversations for insert
  to authenticated
  with check (auth.uid() = user1_id or auth.uid() = user2_id);

drop policy if exists "conversations_update_participants" on public.conversations;
create policy "conversations_update_participants"
  on public.conversations for update
  to authenticated
  using (auth.uid() = user1_id or auth.uid() = user2_id)
  with check (auth.uid() = user1_id or auth.uid() = user2_id);

--------------------------------------------------------------------------------
-- messages
--------------------------------------------------------------------------------
create table if not exists public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null,
  sender_id        uuid not null,
  content          text not null check (char_length(content) between 1 and 4000),
  is_read          boolean not null default false,
  created_at       timestamptz not null default now(),
  constraint messages_conversation_id_fkey
    foreign key (conversation_id) references public.conversations(id) on delete cascade,
  constraint messages_sender_id_fkey
    foreign key (sender_id) references public.profiles(id) on delete cascade
);

create index if not exists idx_messages_conversation_created_at
  on public.messages (conversation_id, created_at desc);

alter table public.messages enable row level security;

-- SELECT: доступ имеют только участники диалога.
drop policy if exists "messages_select_participants" on public.messages;
create policy "messages_select_participants"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

-- INSERT: отправитель обязан быть auth.uid() и участником диалога.
drop policy if exists "messages_insert_sender_participant" on public.messages;
create policy "messages_insert_sender_participant"
  on public.messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1
      from public.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

-- UPDATE: отметить прочитанным можно ТОЛЬКО чужое сообщение в своём диалоге.
drop policy if exists "messages_update_mark_read" on public.messages;
create policy "messages_update_mark_read"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1
      from public.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  )
  with check (
    exists (
      select 1
      from public.conversations c
      where c.id = messages.conversation_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

-- FK для last_message_id (после создания обеих таблиц).
do $$ begin
  alter table public.conversations
    add constraint conversations_last_message_id_fkey
    foreign key (last_message_id) references public.messages(id) on delete set null;
exception when duplicate_object then null;
end $$;

--------------------------------------------------------------------------------
-- Триггеры
--------------------------------------------------------------------------------

-- При вставке нового сообщения: обновляем updated_at и last_message_id.
create or replace function public.fn_messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.conversations
  set updated_at = new.created_at,
      last_message_id = new.id
  where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists trg_messages_after_insert on public.messages;
create trigger trg_messages_after_insert
  after insert on public.messages
  for each row execute function public.fn_messages_after_insert();

-- При регистрации пользователя в auth.users создаём пустой профиль.
-- username берётся из user_metadata.username (мы кладём его туда на этапе signUp).
create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'username',
      lower(split_part(new.email, '@', 1))
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_auth_users_after_insert on auth.users;
create trigger trg_auth_users_after_insert
  after insert on auth.users
  for each row execute function public.fn_handle_new_user();

--------------------------------------------------------------------------------
-- Realtime: включить публикацию для таблиц messages / conversations / profiles.
--------------------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.conversations;
exception when duplicate_object then null;
end $$;

do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null;
end $$;

--------------------------------------------------------------------------------
-- Storage: bucket avatars (публичный).
--------------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists "avatars_read_all" on storage.objects;
create policy "avatars_read_all"
  on storage.objects for select
  to public
  using (bucket_id = 'avatars');

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
