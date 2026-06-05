-- Отключение easter-egg бота «pyatocki».
-- Раньше на любое входящее сообщение в DM с этим ботом триггер
-- `trg_messages_pyatocki_auto_reply` вставлял ответ из 14 лапок 🦶.
-- Поведение воспринималось как «Saved Messages отвечает сам себе»:
--   - AppBar диалога рендерится как «Saved Messages» (effectiveTitle
--     для `kind='saved'` фиксирован, а бот-диалог иногда ошибочно
--     попадал в эту ветку из-за кривого `isSaved` в UI);
--   - отправитель видел «ответ на своё сообщение» с подписью бота.
-- Полностью отключаем автоответ. Системного пользователя и его профиль
-- оставляем в БД на случай ручных тестов или будущих фич.

drop trigger if exists trg_messages_pyatocki_auto_reply on public.messages;
drop function if exists public.fn_pyatocki_auto_reply();
