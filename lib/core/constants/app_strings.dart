/// Все пользовательские строки собраны в одном месте. Русский — по умолчанию.
class AppStrings {
  const AppStrings._();

  static const String appName = 'CCHR Messanger';

  // Общие
  static const String retry = 'Повторить';
  static const String cancel = 'Отмена';
  static const String save = 'Сохранить';
  static const String ok = 'OK';
  static const String loading = 'Загрузка…';
  static const String offlineMode = 'Офлайн-режим';
  static const String noInternet = 'Нет подключения к интернету';
  static const String somethingWentWrong = 'Что-то пошло не так';

  // Аутентификация
  static const String signInTitle = 'Вход';
  static const String signUpTitle = 'Создать аккаунт';
  static const String usernameLabel = 'Ник';
  static const String usernameHint = 'например, alex_01';
  static const String passwordLabel = 'Пароль';
  static const String passwordRepeatLabel = 'Повторите пароль';
  static const String signInButton = 'Войти';
  static const String signUpButton = 'Создать';
  static const String goToSignIn = 'Уже есть аккаунт? Войти';
  static const String goToSignUp = 'Нет аккаунта? Создать';
  static const String signOut = 'Выйти';

  static const String errorInvalidCredentials = 'Неверный ник или пароль';
  static const String errorUsernameTaken = 'Этот ник уже занят';
  static const String errorUsernameFormat =
      'Ник: 3–20 символов, латиница, цифры, подчёркивание';
  static const String errorPasswordShort = 'Пароль должен быть не короче 6 символов';
  static const String errorPasswordsMismatch = 'Пароли не совпадают';
  static const String errorUsernameRequired = 'Укажите ник';
  static const String errorPasswordRequired = 'Укажите пароль';

  static const String usernameAvailable = 'Ник свободен';
  static const String usernameCheck = 'Проверить уникальность';

  // Список чатов
  static const String chatsTitle = 'Чаты';
  static const String chatsEmpty = 'Нет диалогов. Начните переписку через поиск 🔍';
  static const String newChat = 'Новый чат';

  // Поиск
  static const String searchTitle = 'Поиск пользователей';
  static const String searchHint = 'Введите ник…';
  static const String searchEmpty = 'Никого не нашли';
  static const String startChat = 'Начать диалог';

  // Чат
  static const String messageHint = 'Сообщение…';
  static const String messageSend = 'Отправить';
  static const String messageRead = 'Прочитано';
  static const String messageDelivered = 'Доставлено';
  static const String messageEdited = 'изменено';
  static const String messageDeleted = 'Сообщение удалено';
  static const String messageForwarded = 'Пересланное сообщение';
  static const String messagePinned = 'Закреплено';
  static const String online = 'в сети';
  static String lastSeen(String ago) => 'был(а) $ago';

  // Действия с сообщением
  static const String actionReply = 'Ответить';
  static const String actionEdit = 'Редактировать';
  static const String actionCopy = 'Копировать';
  static const String actionForward = 'Переслать';
  static const String actionPin = 'Закрепить';
  static const String actionUnpin = 'Открепить';
  static const String actionDelete = 'Удалить';
  static const String actionDeleteForMe = 'Удалить у себя';
  static const String actionDeleteForAll = 'Удалить у всех';
  static const String actionReact = 'Реакция';

  // Поиск в чате
  static const String searchInChat = 'Поиск в чате';
  static const String searchInChatHint = 'Текст сообщения…';
  static const String searchNoResults = 'Ничего не найдено';

  // Forward picker
  static const String forwardTitle = 'Кому переслать?';

  // Edit
  static const String editTitle = 'Редактирование';
  static const String editHint = 'Новый текст…';
  static const String editTooOld =
      'Сообщение нельзя редактировать (старше 48 часов)';
  static const String replyTo = 'Ответ на';

  // Профиль
  static const String profileTitle = 'Профиль';
  static const String displayNameLabel = 'Отображаемое имя';
  static const String bioLabel = 'О себе';
  static const String bioHint = 'Расскажите о себе (до 200 символов)';
  static const String editAvatar = 'Сменить аватарку';
  static const String avatarUpdated = 'Аватарка обновлена';
  static const String profileSaved = 'Профиль сохранён';

  // Настройки
  static const String settingsTheme = 'Тема оформления';
  static const String themeSystem = 'Как в системе';
  static const String themeLight = 'Светлая';
  static const String themeDark = 'Тёмная';
  static const String muteTitle = 'Уведомления';
  static const String muteOn = 'Отключить уведомления';
  static const String muteOff = 'Включить уведомления';
  static const String muteFor1Hour = 'На 1 час';
  static const String muteFor8Hours = 'На 8 часов';
  static const String muteFor1Day = 'На 24 часа';
  static const String muteFor1Week = 'На неделю';
  static const String muteForever = 'Навсегда';
  static const String muteCleared = 'Уведомления включены';
  static const String muteSet = 'Уведомления отключены';
}
