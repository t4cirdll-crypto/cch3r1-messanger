-- Фикс бага self-destruct: pg_cron sweep падал из-за того, что триггер
-- fn_messages_before_update проверяет sender_id = auth.uid(), а в cron-контексте
-- auth.uid() = NULL и любая ветка raise exception срабатывала.
--
-- Решение: даём bypass через GUC `app.bypass_message_owner_check`. SECURITY
-- DEFINER функции (sweep, админ-удаление) выставляют его в `on` для своей
-- транзакции, и триггер пропускает их без проверок.

create or replace function public.fn_messages_before_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  -- 1) Системный bypass (sweep cron, админ-RPC).
  if current_setting('app.bypass_message_owner_check', true) = 'on' then
    return NEW;
  end if;

  -- 2) Сам отправитель — без ограничений.
  if NEW.sender_id = auth.uid() then
    return NEW;
  end if;

  -- 3) Получатель может только пометить is_read.
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

-- Sweep: ставим GUC и физически удаляем (а не помечаем deleted_at) — Telegram-style.
create or replace function public.fn_sweep_expired_messages()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  perform set_config('app.bypass_message_owner_check', 'on', true);
  with deleted as (
    delete from public.messages
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

-- Сразу прогоняем sweep, чтобы накопившиеся истёкшие сообщения исчезли.
select public.fn_sweep_expired_messages();

-- REPLICA IDENTITY FULL — чтобы в Realtime DELETE-событиях OLD-record содержал
-- все колонки, иначе RLS на conversation_id не проходит и клиенты не получают
-- уведомление об удалении (нечего проверять кроме PK).
alter table public.messages replica identity full;
