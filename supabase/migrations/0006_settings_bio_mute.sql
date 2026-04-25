-- Phase 4: settings (bio + per-conversation mute).
--
-- 1) profiles.bio (короткая «о себе» строка, ≤ 200 символов).
-- 2) RPC fn_set_mute(p_conv_id, p_until) — управление muted_until для
--    текущего юзера в conversation_members. NULL очищает.
--
-- Темы и системные настройки клиента живут локально (shared_preferences)
-- и БД не трогают.

--------------------------------------------------------------------------------
-- 1. profiles.bio
--------------------------------------------------------------------------------
alter table public.profiles
  add column if not exists bio text;

alter table public.profiles
  drop constraint if exists profiles_bio_length_chk;
alter table public.profiles
  add constraint profiles_bio_length_chk
    check (bio is null or char_length(bio) <= 200);

--------------------------------------------------------------------------------
-- 2. RPC: fn_set_mute(p_conv_id, p_until)
--------------------------------------------------------------------------------
create or replace function public.fn_set_mute(
  p_conv_id uuid,
  p_until   timestamptz
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.conversation_members
    where conversation_id = p_conv_id and user_id = v_uid
  ) then
    raise exception 'not_a_member' using errcode = '42501';
  end if;

  update public.conversation_members
     set muted_until = p_until
   where conversation_id = p_conv_id
     and user_id = v_uid;
end;
$$;

revoke all on function public.fn_set_mute(uuid, timestamptz) from public;
grant execute on function public.fn_set_mute(uuid, timestamptz) to authenticated;
