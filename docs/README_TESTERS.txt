Mandate Cities 0.1.8 — playtest build / тестовая сборка

WINDOWS
  Run MandateCities.exe. If SmartScreen warns "Windows protected your PC":
  More info -> Run anyway (the build is not code-signed yet).
  Запустите MandateCities.exe. Если SmartScreen предупреждает: «Подробнее» -> «Выполнить в любом случае».

macOS
  Open the .dmg (or unzip the .zip) and move "MandateCities.app" to Applications.
  The app is not notarized yet. On macOS 15 (Sequoia) the first launch is blocked: open
  System Settings -> Privacy & Security, scroll down, press "Open Anyway", then launch again.
  On macOS 14 and older: right-click the app -> Open -> Open.
  If macOS says the app is damaged, run in Terminal:
    xattr -dr com.apple.quarantine "/Applications/MandateCities.app"
  Откройте .dmg (или распакуйте .zip), перенесите MandateCities.app в Программы. На macOS 15
  первый запуск блокируется: Системные настройки -> Конфиденциальность и безопасность ->
  внизу «Открыть всё равно», затем запустите снова. На macOS 14 и старше: правый клик -> «Открыть».

KNOWN / ИЗВЕСТНО
  There is no sound yet. One autosave slot, written during the day (not at the Desk).
  Звука пока нет. Один автосейв, пишется днём (не за Столом).

LANGUAGE / ЯЗЫК
  English / Русский buttons on the main menu (also in Options, O).

CRASHED? / УПАЛА?
  Send the newest file from the logs folder next to your saves:
  Windows: %APPDATA%\Godot\app_userdata\Mandate Cities\logs
  macOS:   ~/Library/Application Support/Godot/app_userdata/Mandate Cities/logs

Guide: PLAYER_GUIDE_EN.md (English) / PLAYER_GUIDE.md (русский).
40 days take 200 minutes at ×1 or about 1 h 7 min at ×3, plus time at the Desk. Press H in game for help.

Окно: дни 1–18; Пыль: 19–29; Жара: 30–40; аудиты: 20 и 36; победа: день 40 при счастье ≥40 и не меньше 12 жителей.
40 дней — 200 минут на ×1 или около 1 ч 7 мин на ×3, плюс время за Столом. H — справка.
Window: days 1–18; Dust: 19–29; Heat: 30–40; audits: 20 and 36; win: day 40 with mood ≥40 and at least 12 residents.
