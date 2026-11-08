# Стартовый пакет для Astra (UI & Дизайн)

Привет, Astra! Добро пожаловать в проект **«Рейнджер на враждебной планете»** (Gamejam «Моторика: Код движения»).

Технический скелет и архитектура разделены: вся бизнес-логика, математика декодера ввода и сессионный координатор изолированы от графического интерфейса. Твоя задача — создавать и настраивать красивый, атмосферный sci-fi UI в готовых `.tscn` сценах, не беспокоясь о поломке логики ядра.

---

## 1. С чего начать

1. Открой проект в **Godot 4.4.1** (строго эта версия движка).
2. Главная сцена интерфейса: [`game/ui/game_view.tscn`](file:///d:/GamejamCyberhand/game/ui/game_view.tscn).
   - Корневой узел — `CanvasLayer` со скриптом [`game_view.gd`](file:///d:/GamejamCyberhand/game/ui/game_view.gd).
   - Внутри находятся контейнеры для экранов, HUD и игрового поля.
   - В инспекторе Godot ты увидишь готовую иерархию нод с привязанными сценами экранов.

---

## 2. Где лежат сцены экранов и компонентов

Все визуальные сцены находятся в каталоге `game/ui/`:

### Экраны (`game/ui/screens/`)
- [`start_screen.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/start_screen.tscn) ([`start_screen.gd`](file:///d:/GamejamCyberhand/game/ui/screens/start_screen.gd)) — стартовый экран:
  - заголовок и подзаголовок экспедиции;
  - карточки/кнопки выбора миссий (`tutorial`, `repair-1`, `repair-2`, `repair-3`);
  - переключатель руки (Левая / Правая);
  - кнопка старта выбранной миссии.
- [`hud_overlay.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/hud_overlay.tscn) ([`hud_overlay.gd`](file:///d:/GamejamCyberhand/game/ui/screens/hud_overlay.gd)) — внутриигровой HUD:
  - статус манипулятора (`OPEN ↑`, `CLOSE ↓`, `REST`, `BOTH` и др.);
  - подсказка для игрока (почему движение остановлено / как продолжить);
  - таймер активной попытки;
  - индикатор зоны стабилизации (удержание курса);
  - кнопка барьера **«Продолжить»** (появляется при потере/восстановлении сигнала `WAITING_RESUME`).
- [`result_screen.tscn`](file:///d:/GamejamCyberhand/game/ui/screens/result_screen.tscn) ([`result_screen.gd`](file:///d:/GamejamCyberhand/game/ui/screens/result_screen.gd)) — экран итогов попытки:
  - вердикт (Успех / Нужна доводка);
  - метрики попытки (время, встречный сигнал BOTH, точность удержания);
  - блок адаптации темпа (объяснение от игры);
  - разблокированный апгрейд базы корабля;
  - сюжетный фрагмент лога экспедиции;
  - кнопки: «Повторить миссию» и «Следующая миссия».

### Компоненты (`game/ui/components/`)
- [`emulator_pad.tscn`](file:///d:/GamejamCyberhand/game/ui/components/emulator_pad.tscn) (обёртка над [`manual_pad.gd`](file:///d:/GamejamCyberhand/game/ui/manual_pad.gd)) — сенсорная панель управления каналами A и B с маркировкой `[ЭМУЛ]`.

### Игровое поле (`game/gameplay/`)
- [`course.gd`](file:///d:/GamejamCyberhand/game/gameplay/course.gd) — отрисовка препятствий, зоны удержания и дрона-манипулятора.

---

## 3. Контракт сигналов и методов

Полное техническое описание контракта: **[`planning/astra-contract.md`](file:///d:/GamejamCyberhand/planning/astra-contract.md)**.

### Сигналы ядра к UI
Контроллер (`SessionCoordinator`) генерирует события:
- `command_updated(command)` — текущий статус захвата (`command.direction`, `command.intensity`, `command.reason`, `command.pause_required`).
- `mission_started(level_id, config)` — начало миссии (`config.title`, `config.hazard_subtitle`, `config.briefing`).
- `mission_tick(active_seconds, in_hold_zone)` — обновление таймера и статус зоны удержания.
- `mission_completed(summary, adaptation)` — сводка попытки для экрана результатов.
- `input_barrier_changed(needs_resume, prompt_text)` — управление видимостью и текстом кнопки «Продолжить».
- `hand_side_changed(is_left)` — уведомление о смене руки (для зеркалирования управления).
- `unlocked_missions_changed(unlocked_ids)` — список открытых миссий.

### Методы ядра, вызываемые из UI
UI дёргает методы координатора при нажатиях игрока:
- `start_current_mission()` — запустить выбранную миссию.
- `select_mission(level_id)` — выбрать миссию (`tutorial`, `repair-1`, `repair-2`, `repair-3`).
- `retry_mission()` — перезапуск попытки.
- `next_mission()` — переход к следующему заданию.
- `request_resume()` — подтверждение продолжения после барьера ввода.
- `toggle_hand_side()` — смена руки.

### Тексты, конфиги и мок-данные для UI
- Никаких захардкоженных строк в скриптах!
- Все тексты, заголовки и описания состояний берутся из [`game/content/copy_catalog.gd`](file:///d:/GamejamCyberhand/game/content/copy_catalog.gd) и исходника [`game/content/copy-ru.md`](file:///d:/GamejamCyberhand/game/content/copy-ru.md).
- Параметры миссий лежат в [`game/content/missions.json`](file:///d:/GamejamCyberhand/game/content/missions.json) и [`LevelConfig`](file:///d:/GamejamCyberhand/game/core/level_config.gd).
- В каталоге [`mock_data/`](file:///d:/GamejamCyberhand/mock_data/) лежат сгенерированные моки для проверки верстки:
  - `missions_mock.json` — 10 миссий с разной длиной текста и параметров;
  - `profiles_mock.json` — 5 профилей игроков со списками рекордов (для проверки прокрутки);
  - `summary_mock.json` — образец экрана результатов.
  Сгенерировать заново с другим сидом можно через `python tools/generate_mock_data.py --seed 42`.

---

## 4. Куда руками НЕ лезть (Зона ответственности Августа)

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

## 5. Как проверить, что ничего не сломалось

Перед отправкой изменений запусти две проверки:

### 1. Автотесты логики (395 проверок)
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

### 2. Валидатор баланса миссий
Запуск валидатора JSON-конфига миссий:
```bash
python tools/validate_missions.py --input game/content/missions.json
```

**Ожидаемый результат:**
```
[OK] All 4 missions are valid.
```
