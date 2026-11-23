Mandate Cities 0.4.1-alpha — playtest build / тестовая сборка

NEW IN 0.4.1-alpha / НОВОЕ В 0.4.1-alpha
  The playtest build. "Pack a report" (Options, and on the finale screen) puts everything we
  ask you to send into one archive on the Desktop. Three new hints: the chapter's norm on its
  first day, the "» evening" button from day two, the treasury once it has money to spend.
  Сборка для плейтеста. «Собрать отчёт» (в настройках и на экране финала) кладёт всё, что мы
  просим прислать, одним архивом на рабочий стол. Три новые подсказки: норма главы в первый
  день, кнопка «» вечер» со второго дня, казна, когда в ней есть что тратить.

FROM 0.4.0-alpha / ИЗ 0.4.0-alpha
  Five chapters with teeth: this is the build to play as a campaign.
  "To the evening": the "» evening" button by the clock (key 4) runs the rest of the day in a
  second once you have done what you wanted; an urgent letter stops it.
  The treasury has something to buy. The City button opens the neighbours' market (stone, wood,
  tools, metal where there is metal; each lot of the same good in a day is a quarter dearer)
  and a quarter's feast (mood +6 for two days). A Village buys a fifth cheaper.
  Sixteen new letters in chapters 2-5: the patron's visit, the settlement's feast, a neighbour's
  goods, each with three answers and a real price for each.
  From 0.3.5: every chapter after the first has a norm of its own (harvest, metal, fish and
  grain, the register) asked at both inspections and at the end of the term; the patron's
  wagons take the quota on their own, click the norm's line in Goals to hold them; a new
  finale for a district that missed its norm; trust in chapters 2-5 opens at 50.
  Пять глав с зубами: это сборка, которую стоит играть как кампанию.
  «До вечера»: кнопка «» вечер» у часов (клавиша 4) прогоняет остаток дня за секунду, когда
  вы сделали всё, что хотели; срочное письмо её останавливает.
  Казне есть на что тратиться. Кнопка «Город» открывает закупку у соседей (камень, дерево,
  инструменты, металл там, где он есть; каждая партия того же товара за день на четверть
  дороже) и праздник квартала (счастье +6 на два дня). Деревня покупает на пятую часть дешевле.
  Шестнадцать новых писем в главах 2-5: визит покровителя, праздник посёлка, чужой товар,
  у каждого три ответа и у каждого ответа настоящая цена.
  Из 0.3.5: у каждой главы после первой своя норма (урожай, металл, рыба и зерно, реестр),
  её спрашивают на обеих проверках и в конце срока; квоту покровитель вывозит вагонами сам,
  клик по строке нормы в «Целях» их придерживает; новый финал для района, не закрывшего
  норму; доверие в главах 2-5 начинается с 50.
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
  Start the game again, Options -> "Pack a report": one archive lands on the Desktop with the
  engine's logs inside. Send it, plus what you were doing. If the game does not start at all,
  send the WHOLE logs folder:
  Windows: %APPDATA%\Godot\app_userdata\Mandate Cities\logs
  macOS:   ~/Library/Application Support/Godot/app_userdata/Mandate Cities/logs
  Запустите игру снова, Настройки -> «Собрать отчёт»: на рабочем столе появится один архив,
  логи движка внутри. Пришлите его и напишите, что делали перед падением. Если игра не
  запускается совсем, пришлите ВСЮ папку logs.

AFTER THE RUN / ПОСЛЕ ПАРТИИ
  Send three things: a screenshot of the ending screen ("SUMMARY" / «ИТОГИ»), the report
  archive (Options -> "Pack a report": one zip on the Desktop with your play logs, the engine's
  logs and a line about your machine; nothing is sent anywhere by the game), and answers to
  the questions below. If "Continue" broke, add saves/save_0.json (Options -> "Open folder",
  one level up).
  Пришлите три вещи: скриншот финала с «ИТОГАМИ», архив отчёта (Настройки -> «Собрать отчёт»:
  один zip на рабочем столе с журналом партий, логами движка и строкой о вашем компьютере;
  сама игра никуда ничего не отправляет) и ответы на вопросы ниже. Если сломалось
  «Продолжить», ещё saves/save_0.json (Настройки -> «Открыть папку», уровнем выше).

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
  7. Which speed did you play at, and did you use "» evening" (key 4)? When did it get boring or too long?
     На какой скорости играли и пользовались ли «» вечер» (клавиша 4)? Когда стало скучно или слишком долго?
  8. Tutorial: finished, skipped (at which step), what was missing?
     Обучение: прошли, пропустили (на каком шаге), чего не хватило?
  9. What annoyed you in the controls and the interface (small text, windows, keys)?
     Что раздражало в управлении и интерфейсе (мелкий текст, окна, клавиши)?
  10. 1–10: "I would play again differently" — and how? Plus one bug you remember.
     1–10: «сыграл бы ещё раз иначе», и как именно? Плюс один запомнившийся баг.

IF YOU PLAYED CHAPTER 2 OR LATER / ЕСЛИ ИГРАЛИ ГЛАВУ 2 И ДАЛЬШЕ
  11. What did the patron send you for in that chapter, in your words? When did you notice the norm?
      За чем вас прислал покровитель в этой главе, своими словами? Когда вы заметили норму?
  12. Did you hold the wagons, buy at the market or hold a feast? Why, or why not?
      Придерживали ли вагоны, покупали ли у соседей, устраивали ли праздник? Почему да или нет?
  13. Was there a letter where you sided with the residents against the patron (or the other way)? What did it cost?
      Было ли письмо, где вы встали на сторону жителей против покровителя (или наоборот)? Чего это стоило?

Guide: PLAYER_GUIDE_EN.md (English) / PLAYER_GUIDE.md (русский).
40 days take 200 minutes at ×1 or about 1 h 7 min at ×3, plus time at the Desk. Press H in game for help.

Окно: дни 1–18; Пыль: 19–29; Жара: 30–40; аудиты: 20 и 36; победа: день 40 при счастье ≥40 и не меньше 12 жителей.
40 дней — 200 минут на ×1 или около 1 ч 7 мин на ×3, плюс время за Столом. H — справка.
Window: days 1–18; Dust: 19–29; Heat: 30–40; audits: 20 and 36; win: day 40 with mood ≥40 and at least 12 residents.
