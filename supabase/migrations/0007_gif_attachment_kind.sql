-- Phase 6a — расширяем allowed values для attachment_kind, добавляя 'gif'.
-- attachment_path для gif хранит полный URL Giphy (не путь в bucket).

alter table public.messages
  drop constraint if exists messages_attachment_kind_check;

alter table public.messages
  add constraint messages_attachment_kind_check
  check (
    attachment_kind is null
    or attachment_kind in ('image','video','file','voice','gif')
  );
