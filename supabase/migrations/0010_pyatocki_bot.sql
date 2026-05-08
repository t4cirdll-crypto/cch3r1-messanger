-- Easter-egg бот «pyatocki».
-- В поиске вводишь `pyatocki` → находишь аккаунт с котом → пишешь любое
-- сообщение → бот отвечает 14× 🦶 в тот же диалог.

--------------------------------------------------------------------------------
-- 1. Системный пользователь в auth.users.
--    Аккаунт без пароля и без email-confirmation: логин невозможен,
--    но в `profiles` он отображается и индексируется поиском.
--------------------------------------------------------------------------------
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  created_at,
  updated_at,
  is_sso_user,
  is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000',
  'a0000000-0000-4000-a000-000000000001',
  'authenticated',
  'authenticated',
  'pyatocki@bot.internal',
  '',
  now(),
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"username": "pyatocki"}'::jsonb,
  false,
  now(),
  now(),
  false,
  false
)
on conflict (id) do nothing;

-- Профиль (на всякий случай UPSERT — на случай отсутствия trg_auth_users_after_insert).
insert into public.profiles (id, username, display_name, avatar_url)
values (
  'a0000000-0000-4000-a000-000000000001',
  'pyatocki',
  'Пятокчи',
  'https://eorpxscbzetqezctdeqg.supabase.co/storage/v1/object/public/avatars/a0000000-0000-4000-a000-000000000001/cat.jpg'
)
on conflict (id) do update
set username     = excluded.username,
    display_name = excluded.display_name,
    avatar_url   = excluded.avatar_url;

--------------------------------------------------------------------------------
-- 2. Триггер: на любое входящее сообщение в диалог с pyatocki —
--    вставляем ответ 🦶×14 от его имени.
--    Защита от рекурсии: сам бот не отвечает на свои же вставки.
--------------------------------------------------------------------------------
create or replace function public.fn_pyatocki_auto_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bot_id constant uuid := 'a0000000-0000-4000-a000-000000000001';
  conv   public.conversations%rowtype;
begin
  -- Не отвечаем на собственные вставки и на удалённые сообщения.
  if new.sender_id = bot_id then
    return new;
  end if;
  if new.deleted_at is not null then
    return new;
  end if;

  select * into conv
  from public.conversations
  where id = new.conversation_id;

  if not found then
    return new;
  end if;

  -- Триггерим только если бот один из участников диалога.
  if conv.user1_id <> bot_id and conv.user2_id <> bot_id then
    return new;
  end if;

  insert into public.messages (
    conversation_id,
    sender_id,
    content,
    reply_to_id
  ) values (
    new.conversation_id,
    bot_id,
    '🦶🦶🦶🦶🦶🦶🦶🦶🦶🦶🦶🦶🦶🦶',
    new.id
  );

  return new;
end;
$$;

drop trigger if exists trg_messages_pyatocki_auto_reply on public.messages;
create trigger trg_messages_pyatocki_auto_reply
  after insert on public.messages
  for each row execute function public.fn_pyatocki_auto_reply();
