import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Languages supported by the application.
enum AppLanguage {
  ru('ru'),
  en('en'),
  de('de');

  const AppLanguage(this.code);

  final String code;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.ru,
    );
  }
}

/// Lightweight, dependency-free localization for InkFlow.
///
/// Keys are plain strings so the same bundle can be used from widgets via
/// [AppLocalizations.of] and from services via [AppLocalizations.translate].
class AppLocalizations {
  const AppLocalizations(this.language);

  final AppLanguage language;

  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
    Locale('de'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLanguage currentLanguage = AppLanguage.ru;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(currentLanguage);
  }

  /// Translates [key] for the currently selected language. Unlike [of], this
  /// can be called from services and other code without a [BuildContext].
  static String translate(
    String key, [
    Map<String, Object?> arguments = const {},
  ]) {
    return _lookup(currentLanguage, key, arguments);
  }

  String t(String key, [Map<String, Object?> arguments = const {}]) {
    return _lookup(language, key, arguments);
  }

  static String _lookup(
    AppLanguage language,
    String key,
    Map<String, Object?> arguments,
  ) {
    var value =
        _translations[language]?[key] ??
        _translations[AppLanguage.ru]?[key] ??
        key;

    for (final entry in arguments.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value}');
    }

    return value;
  }
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture(
      AppLocalizations(AppLanguage.fromCode(locale.languageCode)),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<AppLanguage, Map<String, String>> _translations = {
  AppLanguage.ru: {
    // Common
    'common.cancel': 'Отмена',
    'common.save': 'Сохранить',
    'common.choose': 'Выбрать',
    'common.reset': 'Сбросить',
    'common.delete': 'Удалить',
    'common.edit': 'Редактировать',
    'common.open': 'Открыть',
    'common.rename': 'Переименовать',
    'common.restore': 'Восстановить',
    'common.later': 'Позже',
    'common.create': 'Создать',
    'common.selectColor': 'Выбрать цвет',
    // Navigation
    'nav.home': 'Главная',
    'nav.settings': 'Настройки',
    'nav.archive': 'Архив',
    'nav.trash': 'Корзина',
    'nav.menu': 'Меню',
    // Notes
    'notes.empty': 'У вас пока нет заметок',
    'notes.create': 'Создать заметку',
    'notes.audioAndFiles': 'Аудио и файлы',
    'notes.audio': 'Аудиозаметка',
    'notes.files': 'Файлы',
    'notes.untitled': 'Без названия',
    'notes.noText': 'Без текста',
    'notes.options': 'Выберите вариант',
    'notes.archive': 'Архивировать',
    'notes.archived': 'Заметка перемещена в архив',
    'notes.moveToDesktop': 'Переместить на рабочий стол',
    'notes.movedToDesktop': 'Заметка перемещена на рабочий стол',
    'notes.movedToTrash': 'Заметка перемещена в корзину',
    // Folders
    'folder.create': 'Создать папку',
    'folder.title': 'Папка: {title}',
    'folder.empty': 'В этой папке ничего нет',
    'folder.options': 'Выберите вариант',
    'folder.rename': 'Переименовать',
    'folder.movedToTrash': 'Папка перемещена в корзину',
    'folder.noFolders': 'У вас пока нет папок',
    'folder.colorDialog': 'Выберите цвет для выбранного дня',
    'folder.tagColor': 'Выбрать цвет тега',
    'folder.name': 'Название',
    'folder.nameHint': 'Введите название папки',
    'folder.nameRequired': 'Введите название папки!',
    'folder.saveChanges': 'Сохранить изменения',
    'folder.movedTo': 'Заметка перемещена в папку {title}',
    'folder.moveTo': 'Переместить в папку',
    'folder.addTo': 'Добавить в папку',
    'folder.removeFrom': 'Убрать из папки (на рабочий стол)',
    'folder.savedWithout': 'Заметка будет сохранена без папки',
    'folder.selected': 'Папка выбрана. Сохраните заметку',
    'folder.none': 'Без папки (на рабочий стол)',
    // Note editor
    'note.statusSaving': 'Сохранение…',
    'note.statusSavedAt': 'Сохранено в {time}',
    'note.statusUnsaved': 'Есть несохранённые изменения',
    'note.statusError': 'Ошибка сохранения',
    'note.createdAt': 'Создано: {date}',
    'note.retrySave': 'Повторить попытку',
    'note.newNote': 'Новая заметка',
    'note.unsavedTitle': 'Вы изменили заметку!',
    'note.unsavedQuestion': 'Хотите ли вы сохранить текущие изменения?',
    'note.saveAndExit': 'Сохранить и выйти',
    'note.emptyCannotSave': 'Пустую заметку сохранить нельзя',
    'note.saved': 'Заметка сохранена',
    'note.saveFailed': 'Не удалось сохранить заметку: {error}',
    'note.micPermission': 'Нет разрешения на использование микрофона',
    'note.recordStartFailed': 'Не удалось начать запись: {error}',
    'note.recordStopFailed': 'Не удалось остановить запись: {error}',
    'note.audioNote': 'Аудио заметка',
    'note.addFilesTitle': 'Добавить файлы к заметке',
    'note.addFilesFailed': 'Не удалось добавить файлы: {error}',
    'note.openFileFailed': 'Не удалось открыть файл: {error}',
    'note.file': 'Файл',
    'note.options': 'Дополнительные опции',
    'note.copyText': 'Копировать текст',
    'note.copyTextSubtitle': 'Название и содержимое заметки',
    'note.exportTxt': 'Экспортировать в .txt',
    'note.exportTxtSubtitle': 'Сохранить заметку как текстовый файл',
    'note.moveToFolderSubtitle': 'Выбрать папку для заметки',
    'note.noTextInNote': 'В заметке нет текста',
    'note.textCopied': 'Текст скопирован',
    'note.exportDialogTitle': 'Экспортировать заметку',
    'note.exported': 'Заметка экспортирована',
    'note.exportFailed': 'Не удалось экспортировать заметку: {error}',
    'note.restoreBackgroundQuestion':
        'Вы точно хотите вернуть задний фон по умолчанию?',
    'note.backgroundColorTitle': 'Выберите цвет для заднего фона',
    'note.textColorTitle': 'Выберите цвет для текста',
    'note.titleHint': 'Введи название :>',
    'note.contentHint': 'Введи заметку ^_^',
    'note.bgColorTooltip': 'Цвет фона',
    'note.textColorTooltip': 'Цвет текста',
    'note.bgImageTooltip': 'Фоновое изображение',
    'note.resetBgTooltip': 'Сбросить фон',
    'note.stopRecording': 'Остановить запись',
    'note.recordAudio': 'Записать аудио',
    'note.addFilesTooltip': 'Добавить файлы',
    // Audio
    'audio.play': 'Воспроизвести',
    'audio.pause': 'Пауза',
    'audio.renameTitle': 'Переименовать аудио заметку',
    'audio.name': 'Название',
    'audio.nameHint': 'Введите название',
    'audio.title': 'Аудио заметка',
    // Settings
    'settings.theme': 'Тема',
    'settings.light': 'Светлая',
    'settings.lightSubtitle': 'Обычная светлая тема',
    'settings.dark': 'Тёмная',
    'settings.darkSubtitle': 'Тёмный интерфейс',
    'settings.oledSubtitle': 'Полностью чёрный фон',
    'settings.interface': 'Интерфейс',
    'settings.primaryColor': 'Цвет интерфейса',
    'settings.primaryColorSubtitle': 'Основной цвет приложения',
    'settings.primaryColorTitle': 'Основной цвет приложения',
    'settings.font': 'Шрифт',
    'settings.fontSubtitle': 'Шрифт интерфейса и заметок',
    'settings.fontPreview': 'Пример текста',
    'settings.bold': 'Жирный шрифт',
    'settings.boldSubtitle':
        'Использовать жирное начертание во всём приложении',
    'settings.language': 'Язык',
    'settings.languageSubtitle': 'Язык интерфейса',
    'settings.languageRu': 'Русский',
    'settings.languageEn': 'Английский',
    'settings.languageDe': 'Немецкий',
    // Archive
    'archive.empty': 'Архив пустой',
    'archive.restored': 'Заметка восстановлена',
    'archive.movedToTrash': 'Заметка перемещена в корзину',
    // Trash
    'trash.notes': 'Заметки',
    'trash.folders': 'Папки',
    'trash.noNotes': 'Заметок в корзине нет',
    'trash.noFolders': 'Папок в корзине нет',
    'trash.restored': 'Заметка восстановлена',
    'trash.deleteForever': 'Удалить навсегда',
    'trash.confirmDeleteNote':
        'Вы действительно хотите удалить заметку навсегда?',
    'trash.confirmDeleteFolder':
        'Вы действительно хотите удалить папку навсегда?',
    'trash.noteDeletedForever': 'Заметка удалена навсегда',
    'trash.folderDeletedForever': 'Папка удалена навсегда',
    // Updates
    'update.title': 'Обновления',
    'update.checkFailed': 'Не удалось проверить обновления: {error}',
    'update.upToDate': 'У вас установлена последняя версия InkFlow',
    'update.checking': 'Проверка обновлений…',
    'update.available': 'Доступна версия {version}. Нажмите, чтобы скачать.',
    'update.currentVersion': 'Текущая версия',
    'update.currentVersionWith': 'Текущая версия: {version}',
    'update.availableTitle': 'Доступна версия {version}',
    'update.installed': 'Установлена версия {version}',
    'update.description':
        'Вы можете скачать новую версию с GitHub Releases и установить её поверх текущей.',
    'update.whatsNew': 'Что нового:',
    'update.openGithub': 'Открыть на GitHub',
    'update.download': 'Скачать обновление',
    'update.openFailed': 'Не удалось открыть ссылку: {error}',
    'update.downloadTooltip': 'Скачать обновление',
    'update.checkTooltip': 'Проверить обновления',
    'update.errorStatus': 'GitHub вернул код {code}. Попробуйте позже.',
    'update.errorEmptyLink': 'Пустая ссылка',
    'update.errorUnsupported':
        'Открытие ссылок не поддерживается на этой платформе',
    // Editor toolbar
    'editor.bold': 'Жирный',
    'editor.italic': 'Курсив',
    'editor.underline': 'Подчёркнутый',
    'editor.strikethrough': 'Зачёркнутый',
    'editor.bulletList': 'Маркированный список',
    'editor.numberedList': 'Нумерованный список',
    'editor.checklist': 'Список задач',
    'editor.undo': 'Отменить',
    'editor.redo': 'Повторить',
    'editor.clear': 'Удалить форматирование',
    // Note list & backup
    'settings.groupByDate': 'Разделять заметки по датам',
    'settings.groupByDateSubtitle':
        'Показывать заметки группами по дате создания',
    'common.done': 'Готово',
    'backup.section': 'Резервное копирование',
    'backup.export': 'Экспортировать все заметки',
    'backup.exportSubtitle':
        'Сохранить ZIP-архив со всеми заметками и вложениями',
    'backup.import': 'Импортировать заметки',
    'backup.importSubtitle': 'Восстановить заметки из ZIP-архива',
    'backup.exporting': 'Создание резервной копии…',
    'backup.exportDialogTitle': 'Сохранить резервную копию',
    'backup.exportCancelled': 'Экспорт отменён — файл не сохранён',
    'backup.exported':
        'Экспортировано заметок: {count}. Вложений: {attachments}.',
    'backup.exportFailed': 'Не удалось экспортировать заметки: {error}',
    'backup.exportWarningsTitle': 'Некоторые вложения не включены',
    'backup.warningAttachmentSkipped':
        'Вложение «{name}» недоступно и было пропущено',
    'backup.importDialogTitle': 'Выберите резервную копию',
    'backup.validating': 'Проверка резервной копии…',
    'backup.importing': 'Импорт заметок…',
    'backup.previewTitle': 'Импорт резервной копии',
    'backup.foundNotes': 'Найдено заметок: {count}',
    'backup.backupDate': 'Дата резервной копии: {date}',
    'backup.archiveDetails':
        'Папок: {folders} · Вложений: {attachments} · Версия приложения: {version}',
    'backup.conflictWarning':
        'Найдено совпадений ID: {count}. Существующие заметки не будут перезаписаны — конфликты получат новые ID.',
    'backup.conflictWarningDup':
        'Совпадений ID: {count}, из них точных дубликатов: {duplicates}. Дубликаты будут пропущены, остальные получат новые ID.',
    'backup.chooseMode': 'Выберите способ импорта',
    'backup.modeMerge': 'Объединить с существующими заметками',
    'backup.modeMergeSubtitle':
        'Безопасный режим: существующие заметки не удаляются',
    'backup.modeReplace': 'Заменить существующие заметки',
    'backup.modeReplaceSubtitle':
        'Все текущие заметки будут заменены данными из архива',
    'backup.continue': 'Продолжить',
    'backup.replaceTitle': 'Заменить все заметки?',
    'backup.replaceWarning':
        'Будут удалены заметки: {existing}, и восстановлены из архива: {imported}. При ошибке приложение попытается вернуть прежнее состояние.',
    'backup.replaceConfirm': 'Заменить',
    'backup.importComplete': 'Импорт завершён',
    'backup.importedCount': 'Импортировано заметок: {count}',
    'backup.skippedDuplicates': 'Пропущено точных дубликатов: {count}',
    'backup.reassignedIds': 'Новых ID из-за конфликтов: {count}',
    'backup.restoredAttachments': 'Восстановлено вложений: {count}',
    'backup.importFailed': 'Не удалось импортировать заметки: {error}',
    'backup.errorCorrupt': 'Архив повреждён или не является ZIP-архивом',
    'backup.errorTooLarge': 'Архив слишком большой',
    'backup.errorTooMany': 'В архиве слишком много файлов',
    'backup.errorSchema':
        'Версия схемы архива не поддерживается этой версией приложения',
    'backup.errorMissingAttachment':
        'В архиве отсутствует вложение, на которое ссылается заметка',
    'backup.errorUnsafe':
        'Архив содержит небезопасные имена или дублирующиеся файлы',
    'backup.errorZipBomb':
        'Архив отклонён: подозрительно большая распаковка (защита от ZIP bomb)',
    'backup.errorInvalid': 'Структура архива некорректна',
    'backup.errorGeneric': 'Не удалось проверить архив (код: {code})',
    'backup.errorImportFailed': 'Ошибка импорта: {error}',
    'backup.warningRollbackFailed':
        'Не удалось полностью восстановить прежнее состояние: {error}',
    'update.errorCurrentVersion':
        'Не удалось определить текущую версию: {version}',
    'update.errorCurrentVersionUnknown':
        'Не удалось определить текущую версию: {error}',
    'update.errorTimeout':
        'Не удалось проверить обновления: истекло время ожидания',
    'update.errorNetwork': 'Не удалось проверить обновления: {error}',
    'update.errorInvalidRelease': 'GitHub вернул релиз с некорректной версией',
    'update.errorGeneric': 'Не удалось проверить обновления: {error}',
  },
  AppLanguage.en: {
    // Common
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.choose': 'Choose',
    'common.reset': 'Reset',
    'common.delete': 'Delete',
    'common.edit': 'Edit',
    'common.open': 'Open',
    'common.rename': 'Rename',
    'common.restore': 'Restore',
    'common.later': 'Later',
    'common.create': 'Create',
    'common.selectColor': 'Choose color',
    // Navigation
    'nav.home': 'Home',
    'nav.settings': 'Settings',
    'nav.archive': 'Archive',
    'nav.trash': 'Trash',
    'nav.menu': 'Menu',
    // Notes
    'notes.empty': 'You have no notes yet',
    'notes.create': 'Create note',
    'notes.audioAndFiles': 'Audio and files',
    'notes.audio': 'Audio note',
    'notes.files': 'Files',
    'notes.untitled': 'Untitled',
    'notes.noText': 'No text',
    'notes.options': 'Choose an option',
    'notes.archive': 'Archive',
    'notes.archived': 'Note moved to archive',
    'notes.moveToDesktop': 'Move to desktop',
    'notes.movedToDesktop': 'Note moved to desktop',
    'notes.movedToTrash': 'Note moved to trash',
    // Folders
    'folder.create': 'Create folder',
    'folder.title': 'Folder: {title}',
    'folder.empty': 'This folder is empty',
    'folder.options': 'Choose an option',
    'folder.rename': 'Rename',
    'folder.movedToTrash': 'Folder moved to trash',
    'folder.noFolders': 'You have no folders yet',
    'folder.colorDialog': 'Choose a color for the selected day',
    'folder.tagColor': 'Choose tag color',
    'folder.name': 'Name',
    'folder.nameHint': 'Enter folder name',
    'folder.nameRequired': 'Enter a folder name!',
    'folder.saveChanges': 'Save changes',
    'folder.movedTo': 'Note moved to folder {title}',
    'folder.moveTo': 'Move to folder',
    'folder.addTo': 'Add to folder',
    'folder.removeFrom': 'Remove from folder (to desktop)',
    'folder.savedWithout': 'The note will be saved without a folder',
    'folder.selected': 'Folder selected. Save the note',
    'folder.none': 'No folder (to desktop)',
    // Note editor
    'note.statusSaving': 'Saving…',
    'note.statusSavedAt': 'Saved at {time}',
    'note.statusUnsaved': 'Unsaved changes',
    'note.statusError': 'Save error',
    'note.createdAt': 'Created: {date}',
    'note.retrySave': 'Retry save',
    'note.newNote': 'New note',
    'note.unsavedTitle': 'You changed the note!',
    'note.unsavedQuestion': 'Do you want to save the current changes?',
    'note.saveAndExit': 'Save and exit',
    'note.emptyCannotSave': 'An empty note cannot be saved',
    'note.saved': 'Note saved',
    'note.saveFailed': 'Could not save the note: {error}',
    'note.micPermission': 'No microphone permission',
    'note.recordStartFailed': 'Could not start recording: {error}',
    'note.recordStopFailed': 'Could not stop recording: {error}',
    'note.audioNote': 'Audio note',
    'note.addFilesTitle': 'Add files to the note',
    'note.addFilesFailed': 'Could not add files: {error}',
    'note.openFileFailed': 'Could not open file: {error}',
    'note.file': 'File',
    'note.options': 'Additional options',
    'note.copyText': 'Copy text',
    'note.copyTextSubtitle': 'Note title and content',
    'note.exportTxt': 'Export to .txt',
    'note.exportTxtSubtitle': 'Save the note as a text file',
    'note.moveToFolderSubtitle': 'Choose a folder for the note',
    'note.noTextInNote': 'The note has no text',
    'note.textCopied': 'Text copied',
    'note.exportDialogTitle': 'Export note',
    'note.exported': 'Note exported',
    'note.exportFailed': 'Could not export the note: {error}',
    'note.restoreBackgroundQuestion':
        'Are you sure you want to restore the default background?',
    'note.backgroundColorTitle': 'Choose a background color',
    'note.textColorTitle': 'Choose a text color',
    'note.titleHint': 'Enter a title :>',
    'note.contentHint': 'Enter a note ^_^',
    'note.bgColorTooltip': 'Background color',
    'note.textColorTooltip': 'Text color',
    'note.bgImageTooltip': 'Background image',
    'note.resetBgTooltip': 'Reset background',
    'note.stopRecording': 'Stop recording',
    'note.recordAudio': 'Record audio',
    'note.addFilesTooltip': 'Add files',
    // Audio
    'audio.play': 'Play',
    'audio.pause': 'Pause',
    'audio.renameTitle': 'Rename audio note',
    'audio.name': 'Name',
    'audio.nameHint': 'Enter a name',
    'audio.title': 'Audio note',
    // Settings
    'settings.theme': 'Theme',
    'settings.light': 'Light',
    'settings.lightSubtitle': 'Standard light theme',
    'settings.dark': 'Dark',
    'settings.darkSubtitle': 'Dark interface',
    'settings.oledSubtitle': 'Fully black background',
    'settings.interface': 'Interface',
    'settings.primaryColor': 'Interface color',
    'settings.primaryColorSubtitle': 'Main app color',
    'settings.primaryColorTitle': 'Main app color',
    'settings.font': 'Font',
    'settings.fontSubtitle': 'Interface and notes font',
    'settings.fontPreview': 'Sample text',
    'settings.bold': 'Bold text',
    'settings.boldSubtitle': 'Use bold text throughout the app',
    'settings.language': 'Language',
    'settings.languageSubtitle': 'Interface language',
    'settings.languageRu': 'Russian',
    'settings.languageEn': 'English',
    'settings.languageDe': 'German',
    // Archive
    'archive.empty': 'The archive is empty',
    'archive.restored': 'Note restored',
    'archive.movedToTrash': 'Note moved to trash',
    // Trash
    'trash.notes': 'Notes',
    'trash.folders': 'Folders',
    'trash.noNotes': 'There are no notes in the trash',
    'trash.noFolders': 'There are no folders in the trash',
    'trash.restored': 'Note restored',
    'trash.deleteForever': 'Delete forever',
    'trash.confirmDeleteNote':
        'Are you sure you want to delete the note forever?',
    'trash.confirmDeleteFolder':
        'Are you sure you want to delete the folder forever?',
    'trash.noteDeletedForever': 'Note deleted forever',
    'trash.folderDeletedForever': 'Folder deleted forever',
    // Updates
    'update.title': 'Updates',
    'update.checkFailed': 'Could not check for updates: {error}',
    'update.upToDate': 'You have the latest version of InkFlow',
    'update.checking': 'Checking for updates…',
    'update.available': 'Version {version} is available. Tap to download.',
    'update.currentVersion': 'Current version',
    'update.currentVersionWith': 'Current version: {version}',
    'update.availableTitle': 'Version {version} available',
    'update.installed': 'Installed version {version}',
    'update.description':
        'You can download the new version from GitHub Releases and install it over the current one.',
    'update.whatsNew': "What's new:",
    'update.openGithub': 'Open on GitHub',
    'update.download': 'Download update',
    'update.openFailed': 'Could not open the link: {error}',
    'update.downloadTooltip': 'Download update',
    'update.checkTooltip': 'Check for updates',
    'update.errorStatus': 'GitHub returned code {code}. Try again later.',
    'update.errorEmptyLink': 'Empty link',
    'update.errorUnsupported':
        'Opening links is not supported on this platform',
    // Editor toolbar
    'editor.bold': 'Bold',
    'editor.italic': 'Italic',
    'editor.underline': 'Underline',
    'editor.strikethrough': 'Strikethrough',
    'editor.bulletList': 'Bulleted list',
    'editor.numberedList': 'Numbered list',
    'editor.checklist': 'Checklist',
    'editor.undo': 'Undo',
    'editor.redo': 'Redo',
    'editor.clear': 'Clear formatting',
    // Note list & backup
    'settings.groupByDate': 'Group notes by date',
    'settings.groupByDateSubtitle':
        'Show notes in groups by their creation date',
    'common.done': 'Done',
    'backup.section': 'Backup',
    'backup.export': 'Export all notes',
    'backup.exportSubtitle':
        'Save a ZIP archive with all notes and attachments',
    'backup.import': 'Import notes',
    'backup.importSubtitle': 'Restore notes from a ZIP archive',
    'backup.exporting': 'Creating backup…',
    'backup.exportDialogTitle': 'Save backup',
    'backup.exportCancelled': 'Export cancelled — the file was not saved',
    'backup.exported': 'Exported notes: {count}. Attachments: {attachments}.',
    'backup.exportFailed': 'Could not export notes: {error}',
    'backup.exportWarningsTitle': 'Some attachments were not included',
    'backup.warningAttachmentSkipped':
        'Attachment "{name}" is unavailable and was skipped',
    'backup.importDialogTitle': 'Choose a backup',
    'backup.validating': 'Validating backup…',
    'backup.importing': 'Importing notes…',
    'backup.previewTitle': 'Import backup',
    'backup.foundNotes': 'Notes found: {count}',
    'backup.backupDate': 'Backup date: {date}',
    'backup.archiveDetails':
        'Folders: {folders} · Attachments: {attachments} · App version: {version}',
    'backup.conflictWarning':
        'ID conflicts: {count}. Existing notes will not be overwritten — conflicts receive new IDs.',
    'backup.conflictWarningDup':
        'ID conflicts: {count}, including exact duplicates: {duplicates}. Duplicates will be skipped, the rest receive new IDs.',
    'backup.chooseMode': 'Choose an import mode',
    'backup.modeMerge': 'Merge with existing notes',
    'backup.modeMergeSubtitle': 'Safe mode: existing notes are never deleted',
    'backup.modeReplace': 'Replace existing notes',
    'backup.modeReplaceSubtitle':
        'All current notes will be replaced with archive data',
    'backup.continue': 'Continue',
    'backup.replaceTitle': 'Replace all notes?',
    'backup.replaceWarning':
        'Notes to delete: {existing}; notes to restore: {imported}. If something fails, the app will try to restore the previous state.',
    'backup.replaceConfirm': 'Replace',
    'backup.importComplete': 'Import complete',
    'backup.importedCount': 'Imported notes: {count}',
    'backup.skippedDuplicates': 'Skipped exact duplicates: {count}',
    'backup.reassignedIds': 'New IDs due to conflicts: {count}',
    'backup.restoredAttachments': 'Restored attachments: {count}',
    'backup.importFailed': 'Could not import notes: {error}',
    'backup.errorCorrupt': 'The archive is corrupted or is not a ZIP archive',
    'backup.errorTooLarge': 'The archive is too large',
    'backup.errorTooMany': 'The archive contains too many files',
    'backup.errorSchema':
        'This archive schema version is not supported by this app version',
    'backup.errorMissingAttachment':
        'An attachment referenced by a note is missing from the archive',
    'backup.errorUnsafe':
        'The archive contains unsafe paths or duplicate files',
    'backup.errorZipBomb':
        'The archive was rejected: suspiciously large expansion (ZIP bomb protection)',
    'backup.errorInvalid': 'The archive structure is invalid',
    'backup.errorGeneric': 'Could not validate the archive (code: {code})',
    'backup.errorImportFailed': 'Import failed: {error}',
    'backup.warningRollbackFailed':
        'The previous state could not be fully restored: {error}',
    'update.errorCurrentVersion':
        'Could not determine the current version: {version}',
    'update.errorCurrentVersionUnknown':
        'Could not determine the current version: {error}',
    'update.errorTimeout': 'Could not check for updates: request timed out',
    'update.errorNetwork': 'Could not check for updates: {error}',
    'update.errorInvalidRelease':
        'GitHub returned a release with an invalid version',
    'update.errorGeneric': 'Could not check for updates: {error}',
  },
  AppLanguage.de: {
    // Common
    'common.cancel': 'Abbrechen',
    'common.save': 'Speichern',
    'common.choose': 'Auswählen',
    'common.reset': 'Zurücksetzen',
    'common.delete': 'Löschen',
    'common.edit': 'Bearbeiten',
    'common.open': 'Öffnen',
    'common.rename': 'Umbenennen',
    'common.restore': 'Wiederherstellen',
    'common.later': 'Später',
    'common.create': 'Erstellen',
    'common.selectColor': 'Farbe wählen',
    // Navigation
    'nav.home': 'Start',
    'nav.settings': 'Einstellungen',
    'nav.archive': 'Archiv',
    'nav.trash': 'Papierkorb',
    'nav.menu': 'Menü',
    // Notes
    'notes.empty': 'Sie haben noch keine Notizen',
    'notes.create': 'Notiz erstellen',
    'notes.audioAndFiles': 'Audio und Dateien',
    'notes.audio': 'Audio-Notiz',
    'notes.files': 'Dateien',
    'notes.untitled': 'Unbenannt',
    'notes.noText': 'Kein Text',
    'notes.options': 'Wählen Sie eine Option',
    'notes.archive': 'Archivieren',
    'notes.archived': 'Notiz ins Archiv verschoben',
    'notes.moveToDesktop': 'Auf den Desktop verschieben',
    'notes.movedToDesktop': 'Notiz auf den Desktop verschoben',
    'notes.movedToTrash': 'Notiz in den Papierkorb verschoben',
    // Folders
    'folder.create': 'Ordner erstellen',
    'folder.title': 'Ordner: {title}',
    'folder.empty': 'Dieser Ordner ist leer',
    'folder.options': 'Wählen Sie eine Option',
    'folder.rename': 'Umbenennen',
    'folder.movedToTrash': 'Ordner in den Papierkorb verschoben',
    'folder.noFolders': 'Sie haben noch keine Ordner',
    'folder.colorDialog': 'Wählen Sie eine Farbe für den ausgewählten Tag',
    'folder.tagColor': 'Tag-Farbe wählen',
    'folder.name': 'Name',
    'folder.nameHint': 'Ordnernamen eingeben',
    'folder.nameRequired': 'Geben Sie einen Ordnernamen ein!',
    'folder.saveChanges': 'Änderungen speichern',
    'folder.movedTo': 'Notiz in Ordner {title} verschoben',
    'folder.moveTo': 'In Ordner verschieben',
    'folder.addTo': 'Zu Ordner hinzufügen',
    'folder.removeFrom': 'Aus Ordner entfernen (auf den Desktop)',
    'folder.savedWithout': 'Die Notiz wird ohne Ordner gespeichert',
    'folder.selected': 'Ordner ausgewählt. Speichern Sie die Notiz',
    'folder.none': 'Kein Ordner (auf den Desktop)',
    // Note editor
    'note.statusSaving': 'Wird gespeichert…',
    'note.statusSavedAt': 'Gespeichert um {time}',
    'note.statusUnsaved': 'Ungespeicherte Änderungen',
    'note.statusError': 'Fehler beim Speichern',
    'note.createdAt': 'Erstellt: {date}',
    'note.retrySave': 'Speichern wiederholen',
    'note.newNote': 'Neue Notiz',
    'note.unsavedTitle': 'Sie haben die Notiz geändert!',
    'note.unsavedQuestion': 'Möchten Sie die aktuellen Änderungen speichern?',
    'note.saveAndExit': 'Speichern und beenden',
    'note.emptyCannotSave': 'Eine leere Notiz kann nicht gespeichert werden',
    'note.saved': 'Notiz gespeichert',
    'note.saveFailed': 'Notiz konnte nicht gespeichert werden: {error}',
    'note.micPermission': 'Keine Mikrofonberechtigung',
    'note.recordStartFailed': 'Aufnahme konnte nicht gestartet werden: {error}',
    'note.recordStopFailed': 'Aufnahme konnte nicht beendet werden: {error}',
    'note.audioNote': 'Audio-Notiz',
    'note.addFilesTitle': 'Dateien zur Notiz hinzufügen',
    'note.addFilesFailed': 'Dateien konnten nicht hinzugefügt werden: {error}',
    'note.openFileFailed': 'Datei konnte nicht geöffnet werden: {error}',
    'note.file': 'Datei',
    'note.options': 'Weitere Optionen',
    'note.copyText': 'Text kopieren',
    'note.copyTextSubtitle': 'Titel und Inhalt der Notiz',
    'note.exportTxt': 'Als .txt exportieren',
    'note.exportTxtSubtitle': 'Notiz als Textdatei speichern',
    'note.moveToFolderSubtitle': 'Ordner für die Notiz auswählen',
    'note.noTextInNote': 'Die Notiz enthält keinen Text',
    'note.textCopied': 'Text kopiert',
    'note.exportDialogTitle': 'Notiz exportieren',
    'note.exported': 'Notiz exportiert',
    'note.exportFailed': 'Notiz konnte nicht exportiert werden: {error}',
    'note.restoreBackgroundQuestion':
        'Möchten Sie den Standardhintergrund wirklich wiederherstellen?',
    'note.backgroundColorTitle': 'Wählen Sie eine Hintergrundfarbe',
    'note.textColorTitle': 'Wählen Sie eine Textfarbe',
    'note.titleHint': 'Titel eingeben :>',
    'note.contentHint': 'Notiz eingeben ^_^',
    'note.bgColorTooltip': 'Hintergrundfarbe',
    'note.textColorTooltip': 'Textfarbe',
    'note.bgImageTooltip': 'Hintergrundbild',
    'note.resetBgTooltip': 'Hintergrund zurücksetzen',
    'note.stopRecording': 'Aufnahme stoppen',
    'note.recordAudio': 'Audio aufnehmen',
    'note.addFilesTooltip': 'Dateien hinzufügen',
    // Audio
    'audio.play': 'Abspielen',
    'audio.pause': 'Pause',
    'audio.renameTitle': 'Audio-Notiz umbenennen',
    'audio.name': 'Name',
    'audio.nameHint': 'Namen eingeben',
    'audio.title': 'Audio-Notiz',
    // Settings
    'settings.theme': 'Design',
    'settings.light': 'Hell',
    'settings.lightSubtitle': 'Standard-Helles Design',
    'settings.dark': 'Dunkel',
    'settings.darkSubtitle': 'Dunkle Oberfläche',
    'settings.oledSubtitle': 'Vollständig schwarzer Hintergrund',
    'settings.interface': 'Oberfläche',
    'settings.primaryColor': 'Oberflächenfarbe',
    'settings.primaryColorSubtitle': 'Hauptfarbe der App',
    'settings.primaryColorTitle': 'Hauptfarbe der App',
    'settings.font': 'Schriftart',
    'settings.fontSubtitle': 'Schrift für Oberfläche und Notizen',
    'settings.fontPreview': 'Beispieltext',
    'settings.bold': 'Fette Schrift',
    'settings.boldSubtitle': 'Fette Schrift in der gesamten App verwenden',
    'settings.language': 'Sprache',
    'settings.languageSubtitle': 'Sprache der Oberfläche',
    'settings.languageRu': 'Russisch',
    'settings.languageEn': 'Englisch',
    'settings.languageDe': 'Deutsch',
    // Archive
    'archive.empty': 'Das Archiv ist leer',
    'archive.restored': 'Notiz wiederhergestellt',
    'archive.movedToTrash': 'Notiz in den Papierkorb verschoben',
    // Trash
    'trash.notes': 'Notizen',
    'trash.folders': 'Ordner',
    'trash.noNotes': 'Keine Notizen im Papierkorb',
    'trash.noFolders': 'Keine Ordner im Papierkorb',
    'trash.restored': 'Notiz wiederhergestellt',
    'trash.deleteForever': 'Endgültig löschen',
    'trash.confirmDeleteNote':
        'Möchten Sie die Notiz wirklich endgültig löschen?',
    'trash.confirmDeleteFolder':
        'Möchten Sie den Ordner wirklich endgültig löschen?',
    'trash.noteDeletedForever': 'Notiz endgültig gelöscht',
    'trash.folderDeletedForever': 'Ordner endgültig gelöscht',
    // Updates
    'update.title': 'Updates',
    'update.checkFailed': 'Updates konnten nicht geprüft werden: {error}',
    'update.upToDate': 'Sie haben die neueste Version von InkFlow',
    'update.checking': 'Suche nach Updates…',
    'update.available':
        'Version {version} ist verfügbar. Zum Herunterladen tippen.',
    'update.currentVersion': 'Aktuelle Version',
    'update.currentVersionWith': 'Aktuelle Version: {version}',
    'update.availableTitle': 'Version {version} verfügbar',
    'update.installed': 'Installierte Version {version}',
    'update.description':
        'Sie können die neue Version von GitHub Releases herunterladen und über die aktuelle installieren.',
    'update.whatsNew': 'Was ist neu:',
    'update.openGithub': 'Auf GitHub öffnen',
    'update.download': 'Update herunterladen',
    'update.openFailed': 'Link konnte nicht geöffnet werden: {error}',
    'update.downloadTooltip': 'Update herunterladen',
    'update.checkTooltip': 'Nach Updates suchen',
    'update.errorStatus':
        'GitHub hat den Code {code} zurückgegeben. Versuchen Sie es später erneut.',
    'update.errorEmptyLink': 'Leerer Link',
    'update.errorUnsupported':
        'Das Öffnen von Links wird auf dieser Plattform nicht unterstützt',
    // Editor toolbar
    'editor.bold': 'Fett',
    'editor.italic': 'Kursiv',
    'editor.underline': 'Unterstrichen',
    'editor.strikethrough': 'Durchgestrichen',
    'editor.bulletList': 'Aufzählungsliste',
    'editor.numberedList': 'Nummerierte Liste',
    'editor.checklist': 'Checkliste',
    'editor.undo': 'Rückgängig',
    'editor.redo': 'Wiederholen',
    'editor.clear': 'Formatierung entfernen',
    // Notizliste & Backup
    'settings.groupByDate': 'Notizen nach Datum gruppieren',
    'settings.groupByDateSubtitle':
        'Notizen nach ihrem Erstellungsdatum gruppieren',
    'common.done': 'Fertig',
    'backup.section': 'Sicherung',
    'backup.export': 'Alle Notizen exportieren',
    'backup.exportSubtitle':
        'ZIP-Archiv mit allen Notizen und Anhängen speichern',
    'backup.import': 'Notizen importieren',
    'backup.importSubtitle': 'Notizen aus einem ZIP-Archiv wiederherstellen',
    'backup.exporting': 'Sicherung wird erstellt…',
    'backup.exportDialogTitle': 'Sicherung speichern',
    'backup.exportCancelled':
        'Export abgebrochen — die Datei wurde nicht gespeichert',
    'backup.exported': 'Exportierte Notizen: {count}. Anhänge: {attachments}.',
    'backup.exportFailed': 'Notizen konnten nicht exportiert werden: {error}',
    'backup.exportWarningsTitle': 'Einige Anhänge wurden nicht einbezogen',
    'backup.warningAttachmentSkipped':
        'Anhang „{name}“ ist nicht verfügbar und wurde übersprungen',
    'backup.importDialogTitle': 'Sicherung auswählen',
    'backup.validating': 'Sicherung wird geprüft…',
    'backup.importing': 'Notizen werden importiert…',
    'backup.previewTitle': 'Sicherung importieren',
    'backup.foundNotes': 'Gefundene Notizen: {count}',
    'backup.backupDate': 'Datum der Sicherung: {date}',
    'backup.archiveDetails':
        'Ordner: {folders} · Anhänge: {attachments} · App-Version: {version}',
    'backup.conflictWarning':
        'ID-Konflikte: {count}. Vorhandene Notizen werden nicht überschrieben — Konflikte erhalten neue IDs.',
    'backup.conflictWarningDup':
        'ID-Konflikte: {count}, davon exakte Duplikate: {duplicates}. Duplikate werden übersprungen, der Rest erhält neue IDs.',
    'backup.chooseMode': 'Importmodus wählen',
    'backup.modeMerge': 'Mit vorhandenen Notizen zusammenführen',
    'backup.modeMergeSubtitle':
        'Sicherer Modus: vorhandene Notizen werden nicht gelöscht',
    'backup.modeReplace': 'Vorhandene Notizen ersetzen',
    'backup.modeReplaceSubtitle':
        'Alle aktuellen Notizen werden durch die Archivdaten ersetzt',
    'backup.continue': 'Weiter',
    'backup.replaceTitle': 'Alle Notizen ersetzen?',
    'backup.replaceWarning':
        'Zu löschende Notizen: {existing}; wiederherzustellende Notizen: {imported}. Bei einem Fehler versucht die App, den vorherigen Zustand wiederherzustellen.',
    'backup.replaceConfirm': 'Ersetzen',
    'backup.importComplete': 'Import abgeschlossen',
    'backup.importedCount': 'Importierte Notizen: {count}',
    'backup.skippedDuplicates': 'Übersprungene exakte Duplikate: {count}',
    'backup.reassignedIds': 'Neue IDs wegen Konflikten: {count}',
    'backup.restoredAttachments': 'Wiederhergestellte Anhänge: {count}',
    'backup.importFailed': 'Notizen konnten nicht importiert werden: {error}',
    'backup.errorCorrupt': 'Das Archiv ist beschädigt oder kein ZIP-Archiv',
    'backup.errorTooLarge': 'Das Archiv ist zu groß',
    'backup.errorTooMany': 'Das Archiv enthält zu viele Dateien',
    'backup.errorSchema':
        'Diese Schemaversion des Archivs wird von dieser App-Version nicht unterstützt',
    'backup.errorMissingAttachment':
        'Ein von einer Notiz referenzierter Anhang fehlt im Archiv',
    'backup.errorUnsafe':
        'Das Archiv enthält unsichere Pfade oder doppelte Dateien',
    'backup.errorZipBomb':
        'Das Archiv wurde abgelehnt: verdächtig große Entpackung (ZIP-Bomben-Schutz)',
    'backup.errorInvalid': 'Die Archivstruktur ist ungültig',
    'backup.errorGeneric': 'Archiv konnte nicht geprüft werden (Code: {code})',
    'backup.errorImportFailed': 'Import fehlgeschlagen: {error}',
    'backup.warningRollbackFailed':
        'Der vorherige Zustand konnte nicht vollständig wiederhergestellt werden: {error}',
    'update.errorCurrentVersion':
        'Aktuelle Version konnte nicht ermittelt werden: {version}',
    'update.errorCurrentVersionUnknown':
        'Aktuelle Version konnte nicht ermittelt werden: {error}',
    'update.errorTimeout':
        'Updates konnten nicht geprüft werden: Zeitüberschreitung',
    'update.errorNetwork': 'Updates konnten nicht geprüft werden: {error}',
    'update.errorInvalidRelease':
        'GitHub hat ein Release mit ungültiger Version zurückgegeben',
    'update.errorGeneric': 'Updates konnten nicht geprüft werden: {error}',
  },
};
