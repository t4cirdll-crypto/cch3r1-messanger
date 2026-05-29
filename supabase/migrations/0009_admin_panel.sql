-- Phase 7? — административная панель.
-- Доступ привязан к Android device ID конкретного человека (KillDev). На сервере
-- проверяется auth.uid() в `app_admins`; клиент дополнительно сверяет device id
-- (хранится в той же таблице) и показывает UI только на «правильном» телефоне.

-- 1) Колонки для бана.
alter table public.profiles
  add column if not exists is_banned boolean not null default false,
  add column if not exists banned_at timestamptz,
  add column if not exists banned_reason text;

-- 2) Таблица админов.
create table if not exists public.app_admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  device_id  text not null,
  added_at   timestamptz not null default now(),
  note       text
);

alter table public.app_admins enable row level security;

drop policy if exists "admins read self" on public.app_admins;
create policy "admins read self" on public.app_admins
  for select using (auth.uid() = user_id);

-- 3) helper: проверка что caller — админ.
create or replace function public.fn_is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.app_admins where user_id = auth.uid()
  );
$$;
grant execute on function public.fn_is_admin() to authenticated;

-- 4) helper: вернуть device_id текущего админа (или null).
create or replace function public.fn_admin_self_device_id()
returns text
language sql
security definer
set search_path = public
stable
as $$
  select device_id from public.app_admins where user_id = auth.uid();
$$;
grant execute on function public.fn_admin_self_device_id() to authenticated;

-- 5) Stats: сколько юзеров / диалогов / сообщений / онлайн.
create or replace function public.fn_admin_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare v json;
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  select json_build_object(
    'users_total',         (select count(*) from public.profiles),
    'users_banned',        (select count(*) from public.profiles where is_banned = true),
    'users_online',        (select count(*) from public.profiles where is_online = true),
    'conversations_total', (select count(*) from public.conversations),
    'groups_total',        (select count(*) from public.conversations where kind = 'group'),
    'messages_total',      (select count(*) from public.messages),
    'messages_today',      (select count(*) from public.messages where created_at >= now() - interval '24 hours')
  ) into v;
  return v;
end;
$$;
grant execute on function public.fn_admin_stats() to authenticated;

-- 6) Список всех юзеров.
create or replace function public.fn_admin_users_list()
returns table (
  id              uuid,
  username        text,
  display_name    text,
  avatar_url      text,
  is_online       boolean,
  last_seen       timestamptz,
  created_at      timestamptz,
  bio             text,
  is_banned       boolean,
  banned_at       timestamptz,
  banned_reason   text,
  email           text,
  message_count   bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  return query
  select p.id, p.username, p.display_name, p.avatar_url, p.is_online,
         p.last_seen, p.created_at, p.bio, p.is_banned, p.banned_at,
         p.banned_reason,
         u.email::text,
         (select count(*) from public.messages m where m.sender_id = p.id) as message_count
    from public.profiles p
    left join auth.users u on u.id = p.id
   order by p.created_at desc;
end;
$$;
grant execute on function public.fn_admin_users_list() to authenticated;

-- 7) Список всех диалогов с участниками.
create or replace function public.fn_admin_conversations_list()
returns table (
  id              uuid,
  kind            text,
  title           text,
  created_at      timestamptz,
  updated_at      timestamptz,
  members         json,
  message_count   bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  return query
  select c.id, c.kind, c.title, c.created_at, c.updated_at,
         (select coalesce(json_agg(json_build_object(
            'user_id', cm.user_id,
            'username', p.username,
            'display_name', p.display_name,
            'role', cm.role
          )), '[]'::json)
          from (
            select user_id, role from public.conversation_members where conversation_id = c.id
            union
            select id as user_id, 'owner' as role from public.profiles where (id = c.user1_id or id = c.user2_id) and c.kind = 'dm'
            union
            select id as user_id, 'owner' as role from public.profiles where id = c.created_by and c.kind = 'saved'
          ) cm
          left join public.profiles p on p.id = cm.user_id) as members,
         (select count(*) from public.messages m where m.conversation_id = c.id) as message_count
    from public.conversations c
   order by c.updated_at desc nulls last;
end;
$$;
grant execute on function public.fn_admin_conversations_list() to authenticated;

-- 8) Сообщения произвольного диалога (read-only).
create or replace function public.fn_admin_messages(p_conv_id uuid, p_limit int default 200)
returns table (
  id              uuid,
  conversation_id uuid,
  sender_id       uuid,
  sender_username text,
  content         text,
  created_at      timestamptz,
  edited_at       timestamptz,
  deleted_at      timestamptz,
  expires_at      timestamptz,
  attachment_path text,
  attachment_kind text,
  attachment_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  return query
  select m.id, m.conversation_id, m.sender_id, p.username,
         m.content, m.created_at, m.edited_at, m.deleted_at, m.expires_at,
         m.attachment_path, m.attachment_kind, m.attachment_name
    from public.messages m
    left join public.profiles p on p.id = m.sender_id
   where m.conversation_id = p_conv_id
   order by m.created_at desc
   limit greatest(p_limit, 1);
end;
$$;
grant execute on function public.fn_admin_messages(uuid, int) to authenticated;

-- 9) Бан / разбан юзера.
create or replace function public.fn_admin_set_banned(
  p_user_id uuid, p_banned boolean, p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot ban yourself';
  end if;
  if p_banned then
    update public.profiles
       set is_banned = true,
           banned_at = now(),
           banned_reason = p_reason
     where id = p_user_id;
    -- Завершаем активные сессии, чтобы человек не висел на устройстве.
    delete from auth.sessions where user_id = p_user_id;
    delete from auth.refresh_tokens where user_id = p_user_id::text;
  else
    update public.profiles
       set is_banned = false,
           banned_at = null,
           banned_reason = null
     where id = p_user_id;
  end if;
end;
$$;
grant execute on function public.fn_admin_set_banned(uuid, boolean, text) to authenticated;

-- 10) Удаление юзера полностью (auth.users → каскадно profiles, members, messages).
create or replace function public.fn_admin_delete_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot delete yourself';
  end if;
  perform set_config('app.bypass_message_owner_check', 'on', true);
  -- Сообщения юзера: удаляем явно (на случай отсутствия CASCADE).
  delete from public.messages where sender_id = p_user_id;
  -- Профиль удалится по on delete cascade при удалении auth user.
  delete from auth.users where id = p_user_id;
end;
$$;
grant execute on function public.fn_admin_delete_user(uuid) to authenticated;

-- 11) Удаление одного сообщения админом.
create or replace function public.fn_admin_delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  perform set_config('app.bypass_message_owner_check', 'on', true);
  delete from public.messages where id = p_message_id;
end;
$$;
grant execute on function public.fn_admin_delete_message(uuid) to authenticated;

-- 12) Сброс пароля юзеру (через Auth Admin API внутри edge function — здесь
--     лишь записываем заявку в служебную таблицу, чтобы edge func его подхватил.
--     В продакшене это делается через service role key).
--
-- В рамках текущего объёма реализуем напрямую — сменим encrypted_password в
-- auth.users. Для Supabase Auth это рабочий способ. Пользователь после этого
-- сможет залогиниться с новым паролем.
create or replace function public.fn_admin_reset_password(
  p_user_id uuid, p_new_password text
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  if p_new_password is null or length(p_new_password) < 6 then
    raise exception 'password too short';
  end if;
  update auth.users
     set encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
         updated_at = now()
   where id = p_user_id;
end;
$$;
grant execute on function public.fn_admin_reset_password(uuid, text) to authenticated;

-- 13) Широковещательное сообщение от имени админа всем юзерам:
--     создаём отдельный диалог 1:1 c каждым пользователем (если нет) и пишем
--     туда сообщение от админа.
create or replace function public.fn_admin_broadcast(p_text text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_user record;
  v_conv_id uuid;
  v_count integer := 0;
begin
  if not public.fn_is_admin() then
    raise exception 'forbidden';
  end if;
  if p_text is null or length(trim(p_text)) = 0 then
    raise exception 'empty broadcast';
  end if;
  for v_user in
    select id from public.profiles where id <> v_admin_id and is_banned = false
  loop
    -- Ищем существующий 1:1 диалог.
    select c.id into v_conv_id
      from public.conversations c
     where c.kind = 'dm'
       and ((c.user1_id = v_admin_id and c.user2_id = v_user.id)
            or (c.user1_id = v_user.id and c.user2_id = v_admin_id))
     limit 1;
    if v_conv_id is null then
      insert into public.conversations (kind, user1_id, user2_id, created_by)
      values ('dm', v_admin_id, v_user.id, v_admin_id)
      returning id into v_conv_id;
      -- conversation_members заполнит триггер fn_conv_after_insert_dm.
    end if;
    insert into public.messages (conversation_id, sender_id, content)
      values (v_conv_id, v_admin_id, p_text);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
grant execute on function public.fn_admin_broadcast(text) to authenticated;

-- 14) Бан-проверка при INSERT в messages: забаненный не может писать.
create or replace function public.fn_messages_block_banned()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_banned boolean;
begin
  select is_banned into v_banned from public.profiles where id = NEW.sender_id;
  if v_banned then
    raise exception 'user is banned';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_messages_block_banned on public.messages;
create trigger trg_messages_block_banned
  before insert on public.messages
  for each row
  execute function public.fn_messages_block_banned();
