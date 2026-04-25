-- Поддержка вложений в сообщениях.
-- Приватный bucket `chat-attachments` + RLS по участникам диалога.
-- Расширение `public.messages` полями про attachment.

alter table public.messages
  add column if not exists attachment_path text,
  add column if not exists attachment_kind text,
  add column if not exists attachment_name text,
  add column if not exists attachment_mime text,
  add column if not exists attachment_size bigint,
  add column if not exists attachment_duration_ms integer,
  add column if not exists attachment_width integer,
  add column if not exists attachment_height integer;

alter table public.messages
  alter column content drop not null;

do $do$ begin
  alter table public.messages
    add constraint messages_attachment_kind_check
    check (attachment_kind is null or attachment_kind in ('image','video','file','voice'));
exception when duplicate_object then null;
end $do$;

-- Старый CHECK по длине content создавался автоматически, удалим если сохранился.
do $do$ begin
  alter table public.messages drop constraint if exists messages_content_check;
exception when undefined_object then null;
end $do$;

-- Сообщение должно содержать или текст, или вложение (или и то и другое).
do $do$ begin
  alter table public.messages
    add constraint messages_payload_present
    check (
      (content is not null and char_length(content) between 1 and 4000)
      or attachment_path is not null
    );
exception when duplicate_object then null;
end $do$;

do $do$ begin
  alter table public.messages
    add constraint messages_attachment_consistent
    check (
      (attachment_path is null and attachment_kind is null)
      or (attachment_path is not null and attachment_kind is not null)
    );
exception when duplicate_object then null;
end $do$;

--------------------------------------------------------------------------------
-- Storage: приватный bucket `chat-attachments`.
-- Путь к файлу всегда `{conversation_id}/{message_id}.{ext}` — это позволяет
-- проверять права доступа по `(storage.foldername(name))[1]`.
--------------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;

drop policy if exists "chat_attachments_select_participants" on storage.objects;
create policy "chat_attachments_select_participants"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.conversations c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

drop policy if exists "chat_attachments_insert_participants" on storage.objects;
create policy "chat_attachments_insert_participants"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.conversations c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );

drop policy if exists "chat_attachments_delete_participants" on storage.objects;
create policy "chat_attachments_delete_participants"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and exists (
      select 1 from public.conversations c
      where c.id::text = (storage.foldername(name))[1]
        and (auth.uid() = c.user1_id or auth.uid() = c.user2_id)
    )
  );
