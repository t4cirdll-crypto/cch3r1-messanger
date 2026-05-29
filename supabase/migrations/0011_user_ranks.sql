-- Добавляем колонку rank в profiles
alter table public.profiles
  add column if not exists rank text;

-- Обновляем функцию fn_admin_users_list, чтобы она возвращала rank
drop function if exists public.fn_admin_users_list();

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
  message_count   bigint,
  rank            text
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
         (select count(*) from public.messages m where m.sender_id = p.id) as message_count,
         p.rank
    from public.profiles p
    left join auth.users u on u.id = p.id
   order by p.created_at desc;
end;
$$;

-- Функция для изменения ранга
create or replace function public.fn_admin_set_rank(
  p_user_id uuid, p_rank text
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
  update public.profiles
     set rank = nullif(trim(p_rank), '')
   where id = p_user_id;
end;
$$;
grant execute on function public.fn_admin_set_rank(uuid, text) to authenticated;
