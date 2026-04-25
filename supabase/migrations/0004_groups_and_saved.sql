-- Phase 2: групповые чаты + Saved Messages.
--
-- Вводим таблицу `conversation_members` как авторитетный источник членства,
-- расширяем `conversations` (kind/title/avatar_path/created_by) и
-- переписываем RLS, использующее (user1_id, user2_id), на проверку через
-- `conversation_members`.

--------------------------------------------------------------------------------
-- 1. Members table (авторитетная)
--------------------------------------------------------------------------------
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references public.profiles(id)      on delete cascade,
  role            text not null default 'member'
                       check (role in ('owner','admin','member')),
  joined_at       timestamptz not null default now(),
  last_read_at    timestamptz not null default now(),
  muted_until     timestamptz,
  primary key (conversation_id, user_id)
);

create index if not exists idx_conv_members_user
  on public.conversation_members (user_id);

alter table public.conversation_members enable row level security;

--------------------------------------------------------------------------------
-- 2. Расширяем conversations
--------------------------------------------------------------------------------
alter table public.conversations
  add column if not exists kind         text not null default 'dm'
                                check (kind in ('dm','group','saved')),
  add column if not exists title        text,
  add column if not exists avatar_path  text,
  add column if not exists created_by   uuid references public.profiles(id)
                                on delete set null;

-- Снимаем строгий ордер user1<user2 и unique-pair, чтобы можно было создавать
-- группы и Saved Messages (где user1/user2 NULL).
alter table public.conversations drop constraint if exists conversations_order;
alter table public.conversations drop constraint if exists conversations_unique_pair;
alter table public.conversations alter column user1_id drop not null;
alter table public.conversations alter column user2_id drop not null;

-- Уникальность DM-пары как partial index.
create unique index if not exists conversations_unique_dm_pair
  on public.conversations (user1_id, user2_id)
  where kind = 'dm' and user1_id is not null and user2_id is not null;

--------------------------------------------------------------------------------
-- 3. Backfill: для каждого существующего диалога заносим участников
--------------------------------------------------------------------------------
insert into public.conversation_members (conversation_id, user_id, role, last_read_at)
  select id, user1_id, 'owner', updated_at
  from public.conversations
  where user1_id is not null
  on conflict do nothing;

insert into public.conversation_members (conversation_id, user_id, role, last_read_at)
  select id, user2_id, 'owner', updated_at
  from public.conversations
  where user2_id is not null
  on conflict do nothing;

-- created_by для существующих DM ставим в user1_id
update public.conversations
   set created_by = user1_id
 where created_by is null
   and user1_id is not null;

--------------------------------------------------------------------------------
-- 4. Триггер: при INSERT нового DM автоматически создаём членства
-- (для корректной работы fn_create_dm и обычного `insert into conversations`).
--------------------------------------------------------------------------------
create or replace function public.fn_conv_after_insert_dm()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kind = 'dm' then
    if new.user1_id is not null then
      insert into public.conversation_members (conversation_id, user_id, role)
        values (new.id, new.user1_id, 'owner') on conflict do nothing;
    end if;
    if new.user2_id is not null then
      insert into public.conversation_members (conversation_id, user_id, role)
        values (new.id, new.user2_id, 'owner') on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_conv_after_insert_dm on public.conversations;
create trigger trg_conv_after_insert_dm
  after insert on public.conversations
  for each row execute function public.fn_conv_after_insert_dm();

--------------------------------------------------------------------------------
-- 5. Перепишем RLS на conversations / messages / message_reactions / storage
--    через conversation_members.
--    Используем helper-функцию, чтобы избежать рекурсии RLS на members.
--------------------------------------------------------------------------------
create or replace function public.fn_is_conv_member(p_conv_id uuid, p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
     where conversation_id = p_conv_id and user_id = p_user_id
  );
$$;
grant execute on function public.fn_is_conv_member(uuid, uuid) to authenticated;

-- conversations
drop policy if exists "conversations_select_participants" on public.conversations;
drop policy if exists "conversations_select_members"      on public.conversations;
create policy "conversations_select_members"
  on public.conversations for select to authenticated
  using (public.fn_is_conv_member(id, auth.uid()));

drop policy if exists "conversations_insert_participants" on public.conversations;
drop policy if exists "conversations_insert_dm"           on public.conversations;
-- Только DM можно создавать напрямую (триггер добавит обоих участников).
-- Группы и Saved — через RPC (security definer).
create policy "conversations_insert_dm"
  on public.conversations for insert to authenticated
  with check (
    kind = 'dm'
    and user1_id is not null and user2_id is not null
    and (auth.uid() = user1_id or auth.uid() = user2_id)
  );

drop policy if exists "conversations_update_participants" on public.conversations;
drop policy if exists "conversations_update_admins"       on public.conversations;
create policy "conversations_update_admins"
  on public.conversations for update to authenticated
  using (
    exists (select 1 from public.conversation_members m
             where m.conversation_id = conversations.id
               and m.user_id = auth.uid()
               and (m.role in ('owner','admin') or conversations.kind = 'dm'))
  );
-- DM участники могут менять updated_at/last_message_id (триггер), а
-- также avatar/title для совместимости (не используется UI).

-- messages
drop policy if exists "messages_select_participants" on public.messages;
drop policy if exists "messages_select_members"      on public.messages;
create policy "messages_select_members"
  on public.messages for select to authenticated
  using (public.fn_is_conv_member(conversation_id, auth.uid()));

drop policy if exists "messages_insert_sender_participant" on public.messages;
drop policy if exists "messages_insert_sender_member"      on public.messages;
create policy "messages_insert_sender_member"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.fn_is_conv_member(conversation_id, auth.uid())
  );

drop policy if exists "messages_update_mark_read" on public.messages;
drop policy if exists "messages_update_member"    on public.messages;
create policy "messages_update_member"
  on public.messages for update to authenticated
  using (public.fn_is_conv_member(conversation_id, auth.uid()))
  with check (public.fn_is_conv_member(conversation_id, auth.uid()));
-- Field-level — триггер trg_messages_before_update.

-- message_reactions
drop policy if exists "reactions_select_participants" on public.message_reactions;
drop policy if exists "reactions_select_members"      on public.message_reactions;
create policy "reactions_select_members"
  on public.message_reactions for select to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_reactions.message_id
        and public.fn_is_conv_member(m.conversation_id, auth.uid())
    )
  );

drop policy if exists "reactions_insert_own"     on public.message_reactions;
drop policy if exists "reactions_insert_member"  on public.message_reactions;
create policy "reactions_insert_member"
  on public.message_reactions for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.messages m
      where m.id = message_reactions.message_id
        and public.fn_is_conv_member(m.conversation_id, auth.uid())
    )
  );

-- storage: chat-attachments
drop policy if exists "chat_attachments_select_participants" on storage.objects;
drop policy if exists "chat_attachments_insert_participants" on storage.objects;
drop policy if exists "chat_attachments_delete_participants" on storage.objects;
drop policy if exists "chat_attachments_select_members"      on storage.objects;
drop policy if exists "chat_attachments_insert_members"      on storage.objects;
drop policy if exists "chat_attachments_delete_members"      on storage.objects;

create policy "chat_attachments_select_members"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and public.fn_is_conv_member(
      ((storage.foldername(name))[1])::uuid, auth.uid())
  );

create policy "chat_attachments_insert_members"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and public.fn_is_conv_member(
      ((storage.foldername(name))[1])::uuid, auth.uid())
  );

create policy "chat_attachments_delete_members"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and public.fn_is_conv_member(
      ((storage.foldername(name))[1])::uuid, auth.uid())
  );

-- conversation_members RLS
drop policy if exists "members_select_same_conv" on public.conversation_members;
create policy "members_select_same_conv"
  on public.conversation_members for select to authenticated
  using (public.fn_is_conv_member(conversation_id, auth.uid()));

drop policy if exists "members_update_self" on public.conversation_members;
create policy "members_update_self"
  on public.conversation_members for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "members_delete_self" on public.conversation_members;
create policy "members_delete_self"
  on public.conversation_members for delete to authenticated
  using (user_id = auth.uid());
-- INSERT для members — только через RPC (security definer).

--------------------------------------------------------------------------------
-- 6. Обновим fn_message_set_pin: проверка через members
--------------------------------------------------------------------------------
create or replace function public.fn_message_set_pin(
  p_message_id uuid,
  p_pinned boolean
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_conv uuid;
begin
  select conversation_id into v_conv from public.messages where id = p_message_id;
  if v_conv is null then raise exception 'message not found'; end if;
  if not public.fn_is_conv_member(v_conv, auth.uid()) then
    raise exception 'permission denied';
  end if;
  update public.messages
     set pinned_at = case when p_pinned then now() else null end
   where id = p_message_id;
end;
$$;

--------------------------------------------------------------------------------
-- 7. RPC: создание группы / Saved / управление участниками / тайтлом
--------------------------------------------------------------------------------
create or replace function public.fn_create_group(
  p_title       text,
  p_member_ids  uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id     uuid;
  v_uid    uuid := auth.uid();
  v_member uuid;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception 'title required';
  end if;

  insert into public.conversations (kind, title, created_by)
    values ('group', trim(p_title), v_uid)
    returning id into v_id;

  insert into public.conversation_members (conversation_id, user_id, role)
    values (v_id, v_uid, 'owner')
    on conflict do nothing;

  if p_member_ids is not null then
    foreach v_member in array p_member_ids loop
      if v_member is not null and v_member <> v_uid then
        insert into public.conversation_members (conversation_id, user_id, role)
          values (v_id, v_member, 'member')
          on conflict do nothing;
      end if;
    end loop;
  end if;

  return v_id;
end;
$$;
grant execute on function public.fn_create_group(text, uuid[]) to authenticated;

create or replace function public.fn_create_saved()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id  uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select c.id into v_id
    from public.conversations c
    join public.conversation_members m on m.conversation_id = c.id
   where c.kind = 'saved' and m.user_id = v_uid
   limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.conversations (kind, title, created_by)
    values ('saved', 'Saved Messages', v_uid)
    returning id into v_id;
  insert into public.conversation_members (conversation_id, user_id, role)
    values (v_id, v_uid, 'owner');
  return v_id;
end;
$$;
grant execute on function public.fn_create_saved() to authenticated;

create or replace function public.fn_add_member(
  p_conv_id uuid,
  p_user_id uuid,
  p_role    text default 'member'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := auth.uid();
  v_role   text;
  v_kind   text;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select c.kind into v_kind from public.conversations c where c.id = p_conv_id;
  if v_kind is null then raise exception 'conversation not found'; end if;
  if v_kind <> 'group' then raise exception 'only groups support adding members'; end if;

  select role into v_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid;
  if v_role not in ('owner','admin') then raise exception 'permission denied'; end if;

  if p_role not in ('owner','admin','member') then
    raise exception 'invalid role';
  end if;
  if p_role <> 'member' and v_role <> 'owner' then
    raise exception 'permission denied: only owner can grant role %', p_role;
  end if;

  insert into public.conversation_members (conversation_id, user_id, role)
    values (p_conv_id, p_user_id, p_role)
    on conflict (conversation_id, user_id) do update set role = excluded.role;
end;
$$;
grant execute on function public.fn_add_member(uuid, uuid, text) to authenticated;

create or replace function public.fn_remove_member(
  p_conv_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid         uuid := auth.uid();
  v_my_role     text;
  v_target_role text;
  v_kind        text;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select c.kind into v_kind from public.conversations c where c.id = p_conv_id;
  if v_kind is null then raise exception 'conversation not found'; end if;

  select role into v_my_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid;
  if v_my_role is null then raise exception 'permission denied'; end if;

  -- Самостоятельный выход
  if p_user_id = v_uid then
    if v_my_role = 'owner' and v_kind = 'group' and exists (
        select 1 from public.conversation_members
        where conversation_id = p_conv_id and user_id <> v_uid
    ) then
      raise exception 'owner cannot leave a group with other members; transfer ownership first';
    end if;
    delete from public.conversation_members
      where conversation_id = p_conv_id and user_id = p_user_id;
    -- если последний — удаляем сам диалог (Saved сюда не попадает: всегда owner единственный, выход = удаление)
    if not exists (select 1 from public.conversation_members where conversation_id = p_conv_id) then
      delete from public.conversations where id = p_conv_id;
    end if;
    return;
  end if;

  if v_my_role not in ('owner','admin') then raise exception 'permission denied'; end if;
  select role into v_target_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = p_user_id;
  if v_target_role is null then return; end if;
  if v_target_role = 'owner' then raise exception 'cannot remove owner'; end if;
  if v_target_role = 'admin' and v_my_role <> 'owner' then
    raise exception 'only owner can remove admin';
  end if;
  delete from public.conversation_members
    where conversation_id = p_conv_id and user_id = p_user_id;
end;
$$;
grant execute on function public.fn_remove_member(uuid, uuid) to authenticated;

create or replace function public.fn_change_role(
  p_conv_id uuid,
  p_user_id uuid,
  p_role    text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_my_role text;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select role into v_my_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid;
  if v_my_role <> 'owner' then raise exception 'only owner can change roles'; end if;
  if p_role not in ('owner','admin','member') then raise exception 'invalid role'; end if;
  if p_user_id = v_uid then raise exception 'use ownership transfer instead'; end if;
  update public.conversation_members
    set role = p_role
    where conversation_id = p_conv_id and user_id = p_user_id;
end;
$$;
grant execute on function public.fn_change_role(uuid, uuid, text) to authenticated;

create or replace function public.fn_set_group_title(
  p_conv_id uuid,
  p_title   text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  if p_title is null or char_length(trim(p_title)) = 0 then
    raise exception 'title required';
  end if;
  select role into v_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid;
  if v_role not in ('owner','admin') then raise exception 'permission denied'; end if;
  update public.conversations
    set title = trim(p_title)
    where id = p_conv_id and kind = 'group';
end;
$$;
grant execute on function public.fn_set_group_title(uuid, text) to authenticated;

create or replace function public.fn_set_group_avatar(
  p_conv_id uuid,
  p_path    text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid  uuid := auth.uid();
  v_role text;
begin
  if v_uid is null then raise exception 'unauthenticated'; end if;
  select role into v_role from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid;
  if v_role not in ('owner','admin') then raise exception 'permission denied'; end if;
  update public.conversations
    set avatar_path = p_path
    where id = p_conv_id and kind = 'group';
end;
$$;
grant execute on function public.fn_set_group_avatar(uuid, text) to authenticated;

--------------------------------------------------------------------------------
-- 8. RPC: помечать прочитанным (для unread в группах)
--------------------------------------------------------------------------------
create or replace function public.fn_mark_conv_read(p_conv_id uuid)
returns void
language sql
security invoker
set search_path = public
as $$
  update public.conversation_members
    set last_read_at = now()
    where conversation_id = p_conv_id and user_id = auth.uid();
$$;
grant execute on function public.fn_mark_conv_read(uuid) to authenticated;

--------------------------------------------------------------------------------
-- 9. Auto-create Saved Messages при регистрации + backfill
--------------------------------------------------------------------------------
create or replace function public.fn_handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_username text;
  v_id       uuid;
begin
  v_username := coalesce(new.raw_user_meta_data->>'username', null);
  if v_username is null then
    return new;
  end if;
  insert into public.profiles (id, username) values (new.id, v_username)
    on conflict do nothing;

  insert into public.conversations (kind, title, created_by)
    values ('saved', 'Saved Messages', new.id)
    returning id into v_id;
  insert into public.conversation_members (conversation_id, user_id, role)
    values (v_id, new.id, 'owner');
  return new;
end;
$$;

-- Backfill saved conversations для существующих пользователей.
do $$
declare
  r record;
  v_id uuid;
begin
  for r in select id from public.profiles loop
    if not exists (
      select 1 from public.conversations c
      join public.conversation_members m on m.conversation_id = c.id
      where c.kind = 'saved' and m.user_id = r.id
    ) then
      insert into public.conversations (kind, title, created_by)
        values ('saved', 'Saved Messages', r.id) returning id into v_id;
      insert into public.conversation_members (conversation_id, user_id, role)
        values (v_id, r.id, 'owner');
    end if;
  end loop;
end $$;

--------------------------------------------------------------------------------
-- 10. Realtime: добавить conversation_members
--------------------------------------------------------------------------------
do $$ begin
  alter publication supabase_realtime add table public.conversation_members;
exception when others then null;
end $$;
