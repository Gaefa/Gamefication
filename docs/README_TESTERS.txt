Mandate Cities 0.2.0 — playtest build / тестовая сборка

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
  Send the WHOLE logs folder (Options -> "Open logs folder"), plus what you were doing:
  Windows: %APPDATA%\Godot\app_userdata\Mandate Cities\logs
  macOS:   ~/Library/Application Support/Godot/app_userdata/Mandate Cities/logs
  Пришлите ВСЮ папку logs (Настройки -> «Открыть папку логов») и что делали перед этим.

AFTER THE RUN / ПОСЛЕ ПАРТИИ
  Send: a screenshot of the ending screen ("SUMMARY" / «ИТОГИ»), the analytics folder
  (Options -> "Open folder"), and answers to the ten questions below. If "Continue" broke,
  add saves/save_0.json from the same folder.
  Пришлите: скриншот финала с «ИТОГАМИ», папку analytics (Настройки -> «Открыть папку»)
  и ответы на десять вопросов ниже. Если сломалось «Продолжить», ещё saves/save_0.json.

TEN QUESTIONS / ДЕСЯТЬ ВОПРОСОВ
  1. OS, screen resolution, OS scale, graphics card. Did it start first time; what got in the way?
     ОС, разрешение, масштаб ОС, видеокарта. Запустилась ли с первого раза, что мешало?
  2. What was the goal of the game, in your words, and on which minute did you understand it?
     Какой была цель игры по-вашему и на какой минуте вы это поняли?
  3. How did your run end and why, before reading the SUMMARY? Did the SUMMARY agree?
     Чем закончилась партия и почему, своими словами, до чтения «Итогов»? Совпало ли?
  4. The first moment of "I don't know what to do": which day, which screen?
     Первый момент «не понимаю, что делать»: день и экран.
  5. Water: did you grasp reserve vs coverage vs pressure? What helped or hindered?
     Вода: поняли ли разницу между запасом, покрытием и напором? Что помогло или мешало?
  6. The Desk: was it clear what each answer does? Was there a letter you answered wrongly?
     Стол: было ли ясно, что даёт каждый ответ? Было ли письмо, на которое ответили не так, как хотели?
  7. Which speed did you play at and why? When did it get boring or too long?
     На какой скорости играли и почему? Когда стало скучно или слишком долго?
  8. Tutorial: finished, skipped (at which step), what was missing?
     Обучение: прошли, пропустили (на каком шаге), чего не хватило?
  9. What annoyed you in the controls and the interface (small text, windows, keys)?
     Что раздражало в управлении и интерфейсе (мелкий текст, окна, клавиши)?
  10. 1–10: "I would play again differently" — and how? Plus one bug you remember.
     1–10: «сыграл бы ещё раз иначе», и как именно? Плюс один запомнившийся баг.

Guide: PLAYER_GUIDE_EN.md (English) / PLAYER_GUIDE.md (русский).
40 days take 200 minutes at ×1 or about 1 h 7 min at ×3, plus time at the Desk. Press H in game for help.

Окно: дни 1–18; Пыль: 19–29; Жара: 30–40; аудиты: 20 и 36; победа: день 40 при счастье ≥40 и не меньше 12 жителей.
40 дней — 200 минут на ×1 или около 1 ч 7 мин на ×3, плюс время за Столом. H — справка.
Window: days 1–18; Dust: 19–29; Heat: 30–40; audits: 20 and 36; win: day 40 with mood ≥40 and at least 12 residents.
