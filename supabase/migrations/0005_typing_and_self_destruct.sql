-- Phase 3: typing indicator + self-destruct (исчезающие сообщения).
-- Typing indicator реализован через Supabase Realtime broadcast и
-- не требует изменений в БД. Здесь только исчезающие сообщения.

-- 1) Колонки.
alter table public.conversations
  add column if not exists self_destruct_seconds integer not null default 0
    check (self_destruct_seconds >= 0);

alter table public.messages
  add column if not exists expires_at timestamptz;

create index if not exists idx_messages_expires_at
  on public.messages (expires_at)
  where expires_at is not null and deleted_at is null;

-- 2) Триггер: при вставке проставляем expires_at, если в чате включён таймер.
create or replace function public.fn_messages_set_expires_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_seconds integer;
begin
  if NEW.expires_at is null then
    select self_destruct_seconds into v_seconds
      from public.conversations
     where id = NEW.conversation_id;
    if v_seconds is not null and v_seconds > 0 then
      NEW.expires_at := now() + make_interval(secs => v_seconds);
    end if;
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_messages_set_expires_at on public.messages;
create trigger trg_messages_set_expires_at
  before insert on public.messages
  for each row
  execute function public.fn_messages_set_expires_at();

-- 3) Разрешим самому триггеру / отправителю менять expires_at,
--    обновим whitelist в `fn_messages_before_update`, чтобы это поле
--    не считалось «несанкционированным» изменением.
create or replace function public.fn_messages_before_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if NEW.sender_id = auth.uid() then
    return NEW;
  end if;
  if NEW.id                            = OLD.id
     and NEW.conversation_id           = OLD.conversation_id
     and NEW.sender_id                 = OLD.sender_id
     and NEW.created_at                = OLD.created_at
     and NEW.content                   is not distinct from OLD.content
     and NEW.deleted_at                is not distinct from OLD.deleted_at
     and NEW.edited_at                 is not distinct from OLD.edited_at
     and NEW.expires_at                is not distinct from OLD.expires_at
     and NEW.reply_to_id               is not distinct from OLD.reply_to_id
     and NEW.forwarded_from_message_id is not distinct from OLD.forwarded_from_message_id
     and NEW.forwarded_from_sender_id  is not distinct from OLD.forwarded_from_sender_id
     and NEW.attachment_path           is not distinct from OLD.attachment_path
     and NEW.attachment_kind           is not distinct from OLD.attachment_kind
     and NEW.attachment_name           is not distinct from OLD.attachment_name
     and NEW.attachment_mime           is not distinct from OLD.attachment_mime
     and NEW.attachment_size           is not distinct from OLD.attachment_size
     and NEW.attachment_duration_ms    is not distinct from OLD.attachment_duration_ms
     and NEW.attachment_width          is not distinct from OLD.attachment_width
     and NEW.attachment_height         is not distinct from OLD.attachment_height
  then
    return NEW;
  end if;
  raise exception 'permission denied: only sender can edit this message';
end;
$$;

-- 4) RPC: участник чата может включать/выключать self-destruct.
create or replace function public.fn_set_self_destruct(p_conv_id uuid, p_seconds integer)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'unauthorized';
  end if;
  if p_seconds is null or p_seconds < 0 then
    raise exception 'invalid seconds';
  end if;
  if not public.fn_is_conv_member(p_conv_id, v_uid) then
    raise exception 'not a member';
  end if;
  update public.conversations
     set self_destruct_seconds = p_seconds,
         updated_at            = now()
   where id = p_conv_id;
end;
$$;
grant execute on function public.fn_set_self_destruct(uuid, integer) to authenticated;

-- 5) Sweep истёкших сообщений: помечаем deleted_at = now() и стираем
--    содержимое + ссылки на вложения. Файлы в storage чистим отдельно
--    (отложенный bucket-cleanup, см. ниже).
create or replace function public.fn_sweep_expired_messages()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  with deleted as (
    update public.messages
       set deleted_at             = now(),
           content                = null,
           attachment_path        = null,
           attachment_kind        = null,
           attachment_name        = null,
           attachment_mime        = null,
           attachment_size        = null,
           attachment_duration_ms = null,
           attachment_width       = null,
           attachment_height      = null
     where expires_at is not null
       and expires_at <= now()
       and deleted_at is null
    returning 1
  )
  select count(*) into v_count from deleted;
  return v_count;
end;
$$;
grant execute on function public.fn_sweep_expired_messages() to authenticated;

-- 6) Расписание pg_cron — каждую минуту. Если расширение недоступно,
--    тихо пропускаем (клиент при открытии чата всё равно фильтрует
--    истёкшие сообщения и может вызвать `fn_sweep_expired_messages`).
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule(jobid)
      from cron.job where jobname = 'sweep_expired_messages';
    perform cron.schedule(
      'sweep_expired_messages',
      '*/1 * * * *',
      $cron$ select public.fn_sweep_expired_messages(); $cron$
    );
  end if;
end
$$;
