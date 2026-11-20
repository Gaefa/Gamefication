Mandate Cities 0.3.5-alpha — playtest build / тестовая сборка

NEW IN 0.3.5-alpha / НОВОЕ В 0.3.5-alpha
  Chapters 2-5 now ask for what their patron sent you for. Each has a norm of its own: the
  fourth line of both inspections and of the Goals list, and a condition of the mandate's
  extension. Gorge: harvest for the League. Quarry: metal for the Union. Nyupa: fish and
  grain for the League. Old Capital: a registry office and two tenements on the register.
  A quota is hauled away by the patron's wagons on their own and paid for; click the norm's
  line in Goals to hold or release them. A settled district that missed its norm is not
  renewed (a new finale in each of the four chapters). Trust in these chapters opens at 50.
  New letters put the quota against the residents: night shifts, short rations, a neighbour's
  goods under your seal. The finale's side is now counted from your answers for the city
  against your answers for the patron.
  Главы 2-5 теперь спрашивают то, за чем вас прислал покровитель. У каждой своя норма:
  четвёртая строка обеих проверок и списка «Цели», и условие продления мандата. Ущелье:
  урожай Лиге. Карьер: металл Союзу. Нюпа: рыба и зерно Лиге. Старый Капитал: учётная
  контора и два доходных дома по реестру. Квоту покровитель вывозит вагонами сам и платит
  за неё; клик по строке нормы в «Целях» придерживает и отпускает вагоны. Район, который
  устоял, но норму не закрыл, мандат не продлевает (новый финал в каждой из четырёх глав).
  Доверие в этих главах начинается с 50. Новые письма ставят квоту против жителей: ночные
  смены, урезанный паёк, чужой товар под вашей печатью. Сторона финала теперь считается
  по вашим ответам за город и за покровителя.
  0.3.4: fixes from an overnight test pass (storm damage no longer empties a district at
  once; chapters 2-5 offer their own mandate; Kramer's smelter start; saved mood).
  0.3.3: chapter 5, the Old Capital's outer ring (permits, ruins, the road behind).
  0.3.2: chapter 4, Big Nyupa (the river, levees, stilts). 0.3.1: chapter 3, the Black Quarry.
  0.3.0: chapter 2 and inherited starts.

WINDOWS
  Run MandateCities.exe. If SmartScreen warns "Windows protected your PC":
  More info -> Run anyway (the build is not code-signed yet).
  Запустите MandateCities.exe. Если SmartScreen предупреждает: «Подробнее» -> «Выполнить в любом случае».

macOS
  Open the .dmg (or unzip the .zip) and move "Mandate Cities.app" to Applications.
  The app is not notarized yet. On macOS 15 (Sequoia) the first launch is blocked: open
  System Settings -> Privacy & Security, scroll down, press "Open Anyway", then launch again.
  On macOS 14 and older: right-click the app -> Open -> Open.
  If macOS says the app is damaged, run in Terminal:
    xattr -dr com.apple.quarantine "/Applications/Mandate Cities.app"
  Откройте .dmg (или распакуйте .zip), перенесите Mandate Cities.app в Программы. На macOS 15
  первый запуск блокируется: Системные настройки -> Конфиденциальность и безопасность ->
  внизу «Открыть всё равно», затем запустите снова. На macOS 14 и старше: правый клик -> «Открыть».

ANDROID (first look only / только посмотреть)
  Install the .apk (allow "unknown sources" when asked). Uninstall the previous build first:
  each build is signed with a new key. One finger drags the map, two fingers zoom, tap = click.
  The layout is made for a 1280x720 desktop window: usable on a tablet, small on a phone.
  No hotkeys: panels open from their buttons, pause from the clock.
  Установите .apk (разрешите «неизвестные источники»). Сначала удалите предыдущую сборку:
  у каждой своя подпись. Один палец тянет карту, два — зум, тап = клик. Раскладка рассчитана
  на окно 1280x720: на планшете терпимо, на телефоне мелко. Горячих клавиш нет: панели
  открываются кнопками, пауза — кликом по часам.

KNOWN / ИЗВЕСТНО
  Sound is a first procedural pack (volume in Options). One autosave slot, written every
  morning and every two minutes during the day, never at the Desk itself.
  Звук — первый процедурный набор (громкость в настройках). Один автосейв: каждое утро
  и каждые две минуты днём, но не за самим Столом.

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
