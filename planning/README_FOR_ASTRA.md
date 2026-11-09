# Стартовый пакет для Astra (UI & Дизайн)

Привет, Astra! Добро пожаловать в проект **«Рейнджер на враждебной планете»** (Gamejam «Моторика: Код движения»).

Технический скелет и архитектура разделены: вся бизнес-логика, математика декодера ввода и сессионный координатор изолированы от графического интерфейса. Твоя задача — создавать и настраивать красивый, атмосферный sci-fi UI в готовых `.tscn` сценах, не беспокоясь о поломке логики ядра.

---

## 1. Референсы и визуальный стиль

В папке **[`planning/references/`](file:///d:/GamejamCyberhand/planning/references/)** лежат визуальные референсы, концепт-арты и мудборды для вдохновения (Август загрузит туда дополнительные картинки).

### Рекомендуемая цветовая палитра:
- **Глубокий космос / база (фон):** `#08111d`, `#101d30`
- **Панели, контейнеры, карточки:** `#12263a`, `#18334c`
- **Акцент манипулятора / успех / норма:** `#8af0d4`, `#237f85`, `#3caea3`
- **Препятствия и переборки отсеков:** `#df9675`
- **Предупреждения / встречный сигнал BOTH / нейтраль:** `#ffd166`
- **Отказ / ошибка / отключение:** `#ff9b9b`

---

## 2. С чего начать (Приоритеты работы)

Двигайся пошагово от базовых элементов ввода к глобальным экранам и полировке:

- **Шаг 1: Стилизовать `emulator_pad.tscn` (кнопки A/B и шкалы).**
  Главный инструмент взаимодействия. Сделай приятные тактильные сенсорные кнопки каналов A (OPEN ↑) и B (CLOSE ↓), визуальную шкалу заполнения интенсивности `0.0..1.0` и понятную маркировку `[ЭМУЛ]`. Панели должны поддерживать зеркальное отражение для левой/правой руки.
- **Шаг 2: Стилизовать `start_screen.tscn` (главное меню).**
  Атмосферный sci-fi фон посадочного модуля, карточки выбора миссий (`tutorial`, `repair-1`, `repair-2`, `repair-3`), переключатель ведущей руки («Левая» / «Правая») и кнопка «Начать миссию».
- **Шаг 3: Стилизовать `hud_overlay.tscn` (внутриигровой оверлей).**
  Информативный sci-fi HUD: плашка текущего состояния захвата, понятный таймер активного прохождения, подсветка входа в зону стабилизации и крупная кнопка барьера безопасности **«Продолжить»**.
- **Шаг 4: Стилизовать `result_screen.tscn` (экран победы и итогов).**
  Торжественный экран завершения ремонта: вердикт, карточки метрик (время, встречный сигнал, точность удержания), плашка адаптации сложности, разблокированный модуль базы и цитата из лога экспедиции. Кнопки: «Повторить» и «Следующая».
- **Шаг 5: Анимации и микродвижения.**
  Плавные появления окон, анимация нажатия кнопок, свечение активных каналов, пульсация зоны удержания при стабилизации.

---

## 3. Где лежат сцены экранов и компонентов

Все визуальные сцены находятся в каталоге `game/ui/`:

### Корневой контейнер
- [`game/ui/game_view.tscn`](file:///d:/GamejamCyberhand/game/ui/game_view.tscn) ([`game_view.gd`](file:///d:/GamejamCyberhand/game/ui/game_view.gd)) — корневой `CanvasLayer`. Управляет переключением экранов, HUD и подложкой. Открывай его в Godot 4.4.1 для сборки общего вида.

### Экраны (`game/ui/screens/`)
- [`start_screen.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/start_screen.tscn) ([`start_screen.gd`](file:///d:/GamejamCyberhand/game/ui/screens/start_screen.gd)) — стартовый экран выбора миссий и смены руки.
- [`hud_overlay.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/hud_overlay.tscn) ([`hud_overlay.gd`](file:///d:/GamejamCyberhand/game/ui/screens/hud_overlay.gd)) — игровой HUD.
- [`result_screen.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/result_screen.tscn) ([`result_screen.gd`](file:///d:/GamejamCyberhand/game/ui/screens/result_screen.gd)) — экран итогов попытки.

### Компоненты (`game/ui/components/`)
- [`emulator_pad.tscn`](file:///d:/GamejamCyberhand/game/ui/components/emulator_pad.tscn) (обёртка над [`manual_pad.gd`](file:///d:/GamejamCyberhand/game/ui/manual_pad.gd)) — сенсорная панель управления каналами A и B с маркировкой `[ЭМУЛ]`.

### Игровое поле (`game/gameplay/`)
- [`course.gd`](file:///d:/GamejamCyberhand/game/gameplay/course.gd) — отрисовка препятствий, зоны удержания и дрона-манипулятора.

---

## 4. Контракт сигналов и методов

Полное техническое описание контракта: **[`planning/astra-contract.md`](file:///d:/GamejamCyberhand/planning/astra-contract.md)**.

### Сигналы ядра к UI
Контроллер (`SessionCoordinator`) генерирует события:
- `command_updated(command)` — статус захвата (`command.direction`, `command.intensity`, `command.reason`, `command.pause_required`).
- `mission_started(level_id, config)` — начало миссии (`config.title`, `config.hazard_subtitle`, `config.briefing`).
- `mission_tick(active_seconds, in_hold_zone)` — обновление таймера и статус зоны удержания.
- `mission_completed(summary, adaptation)` — сводка попытки для экрана результатов.
- `input_barrier_changed(needs_resume, prompt_text)` — управление видимостью и текстом кнопки «Продолжить».
- `hand_side_changed(is_left)` — смена руки (для зеркалирования управления).
- `unlocked_missions_changed(unlocked_ids)` — список открытых миссий.

### Методы ядра, вызываемые из UI
UI вызывает методы координатора при действиях игрока:
- `start_current_mission()` — запуск текущей миссии.
- `select_mission(level_id)` — выбор миссии (`tutorial`, `repair-1`, `repair-2`, `repair-3`).
- `retry_mission()` — перезапуск попытки.
- `next_mission()` — переход к следующему заданию.
- `request_resume()` — подтверждение продолжения после барьера ввода.
- `toggle_hand_side()` — переключение руки.

### Тексты, конфиги и мок-данные для верстки
- Никаких захардкоженных строк в скриптах!
- Все тексты, заголовки и описания состояний берутся из [`game/content/copy_catalog.gd`](file:///d:/GamejamCyberhand/game/content/copy_catalog.gd) и исходника [`game/content/copy-ru.md`](file:///d:/GamejamCyberhand/game/content/copy-ru.md).
- Параметры миссий лежат в [`game/content/missions.json`](file:///d:/GamejamCyberhand/game/content/missions.json) и [`LevelConfig`](file:///d:/GamejamCyberhand/game/core/level_config.gd).
- В каталоге [`mock_data/`](file:///d:/GamejamCyberhand/mock_data/) лежат воспроизводимые моки для проверки верстки:
  - `missions_mock.json` — 10 миссий с разной длиной текста и параметров;
  - `profiles_mock.json` — 5 профилей игроков со списками рекордов;
  - `summary_mock.json` — образец экрана результатов.
  Генерация с другим сидом: `python tools/generate_mock_data.py --seed 42`.

> [!WARNING]
> **Работа с длинными текстами (40+ слов):**
> В `mock_data/missions_mock.json` намеренно присутствуют миссии с очень длинными подробными описаниями (40–50 слов). Обязательно настраивай лейблы так, чтобы они не разрывали сетку: используй автоперенос (`autowrap_mode`), обрезку с троеточием (Truncate / `text_overrun_behavior`) либо контейнеры со скроллом (`ScrollContainer`). Интерфейс должен выглядеть аккуратно на любых экранах!

---

## 5. Куда руками НЕ лезть (Зона ответственности Августа)

Чтобы не нарушить валидацию и не сломать тесты:
1. **`game/core/` целиком:**
   - `input_pipeline.gd`, `input_decoder.gd`, `input_validator.gd`, `input_stream_guard.gd`, `input_config.gd`, `control_command.gd`, `session_tracker.gd`, `session_summary.gd`, `local_store.gd`.
   - Здесь живёт математика гистерезиса, таймауты потока, структура сохранений и контракт.
2. **`game/gameplay/session_coordinator.gd`:**
   - Чистая сессионная логика, связывающая ядро с отображением.
3. **`qa/`:**
   - Автоматические тесты (`prototype_smoke.gd`).
4. **Конфиги проекта:**
   - `project.godot`, `export_presets.cfg`, `contracts/`.

---

## 6. Как проверить, что ничего не сломалось

Перед сдачей правок всегда выполняй две проверки:

### 1. Ручной чек-лист дизайнера (6 шагов)
Сверься с документом **[`planning/QA_CHECKLIST_FOR_ASTRA.md`](file:///d:/GamejamCyberhand/planning/QA_CHECKLIST_FOR_ASTRA.md)**:
1. Старт игры (`StartScreen`).
2. Запуск миссии по кнопке.
3. Отклик кнопок A/B и шкал.
4. Сворачивание и возврат с кнопкой «Продолжить».
5. Экран результатов на финише.
6. Переходы «Повторить» и «Следующая».

### 2. Автотесты логики (395 проверок)
Запуск из консоли проекта:
```bash
D:\Godot\Godot_v4.4.1-stable_win64_console.exe --headless --path . --script res://qa/prototype_smoke.gd --max-fps 120
```
*(Или просто `godot --headless --path . --script res://qa/prototype_smoke.gd --max-fps 120`, если godot в PATH)*.

**Ожидаемый результат:**
```
PROTOTYPE SMOKE checks=395 failures=0 route_steps=207
```
Все 395 проверок должны быть зелёными (`failures=0`).

### 3. Валидатор баланса миссий
Запуск валидатора JSON-конфига миссий:
```bash
python tools/validate_missions.py --input game/content/missions.json
```

**Ожидаемый результат:**
```
[OK] All 4 missions are valid.
```
