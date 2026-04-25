-- Phase 1: edit / delete / reply / forward / pin / reactions.
-- Расширяет схему `messages` и добавляет таблицу `message_reactions`.

alter table public.messages
  add column if not exists edited_at                 timestamptz,
  add column if not exists deleted_at                timestamptz,
  add column if not exists reply_to_id               uuid references public.messages(id) on delete set null,
  add column if not exists forwarded_from_message_id uuid references public.messages(id) on delete set null,
  add column if not exists forwarded_from_sender_id  uuid references public.profiles(id) on delete set null,
  add column if not exists pinned_at                 timestamptz;

create index if not exists idx_messages_pinned
  on public.messages (conversation_id, pinned_at desc)
  where pinned_at is not null;

create index if not exists idx_messages_reply_to on public.messages (reply_to_id);

-- Field-level enforcement: только отправитель может менять содержимое
-- сообщения (RLS UPDATE-полиси разрешает is_read и pinned_at для участников).
create or replace function public.fn_messages_before_update()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.sender_id = auth.uid() then
    return new;
  end if;
  if new.id                            = old.id
     and new.conversation_id           = old.conversation_id
     and new.sender_id                 = old.sender_id
     and new.created_at                = old.created_at
     and new.content                   is not distinct from old.content
     and new.deleted_at                is not distinct from old.deleted_at
     and new.edited_at                 is not distinct from old.edited_at
     and new.reply_to_id               is not distinct from old.reply_to_id
     and new.forwarded_from_message_id is not distinct from old.forwarded_from_message_id
     and new.forwarded_from_sender_id  is not distinct from old.forwarded_from_sender_id
     and new.attachment_path           is not distinct from old.attachment_path
     and new.attachment_kind           is not distinct from old.attachment_kind
     and new.attachment_name           is not distinct from old.attachment_name
     and new.attachment_mime           is not distinct from old.attachment_mime
     and new.attachment_size           is not distinct from old.attachment_size
     and new.attachment_duration_ms    is not distinct from old.attachment_duration_ms
     and new.attachment_width          is not distinct from old.attachment_width
     and new.attachment_height         is not distinct from old.attachment_height
  then
    return new;
  end if;
  raise exception 'permission denied: only sender can edit this message';
end;
$$;

drop trigger if exists trg_messages_before_update on public.messages;
create trigger trg_messages_before_update
  before update on public.messages
  for each row execute function public.fn_messages_before_update();

create table if not exists public.message_reactions (
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid not null references auth.users(id)      on delete cascade,
  emoji      text not null check (char_length(emoji) between 1 and 16),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id, emoji)
);

create index if not exists idx_reactions_message on public.message_reactions (message_id);

alter table public.message_reactions enable row level security;

drop policy if exists "reactions_select_participants" on public.message_reactions;
create policy "reactions_select_participants"
  on public.message_reactions for select
  to authenticated
  using (
    exists (
      select 1
      from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = message_reactions.message_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

drop policy if exists "reactions_insert_own" on public.message_reactions;
create policy "reactions_insert_own"
  on public.message_reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1
      from public.messages m
      join public.conversations c on c.id = m.conversation_id
      where m.id = message_reactions.message_id
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

drop policy if exists "reactions_delete_own" on public.message_reactions;
create policy "reactions_delete_own"
  on public.message_reactions for delete
  to authenticated
  using (user_id = auth.uid());

alter publication supabase_realtime add table public.message_reactions;

-- RPC: удалить «у всех» (только отправитель). Очищает контент/вложение.
create or replace function public.fn_message_delete_for_all(p_message_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update public.messages
     set content                = null,
         attachment_path        = null,
         attachment_kind        = null,
         attachment_name        = null,
         attachment_mime        = null,
         attachment_size        = null,
         attachment_duration_ms = null,
         attachment_width       = null,
         attachment_height      = null,
         deleted_at             = now(),
         edited_at              = null
   where id = p_message_id
     and sender_id = auth.uid();
  if not found then
    raise exception 'permission denied or message not found';
  end if;
end;
$$;

grant execute on function public.fn_message_delete_for_all(uuid) to authenticated;

-- RPC: редактирование (sender, до 48 ч, не удалённое).
create or replace function public.fn_message_edit(p_message_id uuid, p_content text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if p_content is null or char_length(trim(p_content)) = 0 then
    raise exception 'content cannot be empty';
  end if;
  update public.messages
     set content   = trim(p_content),
         edited_at = now()
   where id = p_message_id
     and sender_id = auth.uid()
     and deleted_at is null
     and created_at > now() - interval '48 hours';
  if not found then
    raise exception 'permission denied, message deleted or older than 48h';
  end if;
end;
$$;

grant execute on function public.fn_message_edit(uuid, text) to authenticated;

-- RPC: pin/unpin (любой участник диалога).
create or replace function public.fn_message_set_pin(p_message_id uuid, p_pinned boolean)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_conv uuid;
begin
  select conversation_id into v_conv
    from public.messages
   where id = p_message_id;
  if v_conv is null then
    raise exception 'message not found';
  end if;
  if not exists (
    select 1 from public.conversations c
     where c.id = v_conv
       and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
  ) then
    raise exception 'permission denied';
  end if;
  update public.messages
     set pinned_at = case when p_pinned then now() else null end
   where id = p_message_id;
end;
$$;

grant execute on function public.fn_message_set_pin(uuid, boolean) to authenticated;
