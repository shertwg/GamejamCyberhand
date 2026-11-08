# Контракт взаимодействия: Архитектурное ядро и UI/Дизайн (Astra)

> **Документ:** `planning/astra-contract.md`  
> **Версия:** 1.0 (08.11.2026)  
> **Стороны:**  
> - **Ядро / Логика:** Август (`game/core/`, координатор игры, тесты, экспорт)  
> - **UI / Визуал:** Astra (`game/ui/`, визуальное оформление игрового поля, темы, шрифты, анимации)

---

## 1. Главные принципы разделения

1. **Односторонний поток данных:**  
   `UI (Astra)` **не принимает решений** о физике, порогах, валидации сигналов, начислении очков или разблокировке уровней.  
   UI только:
   - отображает текущее состояние, приходящее из ядра;
   - передаёт сырые действия пользователя (нажатие кнопок навигации, касание панелей эмулятора) через публичные методы контроллера.
2. **Никакого прямого управления механикой:**  
   Кнопки UI не двигают дрон напрямую. Сенсорный эмулятор передаёт нормализованные значения каналов `0.0..1.0` в `InputPipeline`.
3. **Безопасность автотестов:**  
   Все тесты в `qa/prototype_smoke.gd` проверяют логические состояния и инварианты безопасности (395+ проверок). Изменение визуальных нод не должно ломать логические интерфейсы.

---

## 2. Сигналы ядра, на которые подписывается UI (Astra)

UI-компоненты слушают следующие события контроллера/ядра:

| Сигнал | Аргументы | Назначение / Что отображать |
|---|---|---|
| `command_updated` | `command: ControlCommand` | Текущее состояние ввода. Содержит:<br>• `command.state` (`ACTIVE`, `REST`, `BOTH`, `WAITING_NEUTRAL`, `WAITING_RESUME`, `STALE`, `DISCONNECTED`, `INVALID`, `SUSPENDED`)<br>• `command.direction` (`OPEN`, `CLOSE`, `REST`, `BOTH`)<br>• `command.intensity` (`float 0.0..1.0`)<br>• `command.reason` (причина для подсказки)<br>• `command.pause_required` (`bool`) |
| `mission_started` | `level_id: String, config: LevelConfig` | Старт миссии. UI обновляет заголовок, текст угрозы, подложку и переходит в экран игры. |
| `mission_tick` | `active_seconds: float, in_hold_zone: bool` | Обновление активного таймера в секундах и подсветка нахождения в зоне стабилизации. |
| `mission_completed` | `summary: SessionSummary, adaptation: Dictionary` | Финиш миссии. UI показывает экран результатов:<br>• `summary.active_ms`<br>• `summary.unwanted_both_ratio()` (доля встречного сигнала)<br>• `summary.hold_accuracy_ratio()` (% удержания)<br>• `adaptation.explanation` (почему изменился темп)<br>• `config.upgrade_unlocked` (апгрейд базы)<br>• `config.expedition_log` (сюжетная запись) |
| `input_barrier_changed` | `needs_resume: bool, prompt_text: String` | Показывает или скрывает кнопку **«Продолжить»** (активна только при `WAITING_RESUME`). |
| `hand_side_changed` | `is_left: bool` | Уведомление о смене руки для зеркального отражения панелей A/B. |
| `unlocked_missions_changed` | `unlocked_ids: Array[String]` | Список доступных миссий для экрана выбора. |

---

## 3. Публичные методы, которые вызывает UI (Astra)

UI вызывает эти методы контроллера при действиях игрока:

### Навигация и игровой цикл
- `start_current_mission()` — запустить текущую выбранную миссию.
- `select_mission(level_id: String)` — выбрать миссию (`tutorial`, `repair-1`, `repair-2`, `repair-3`). Заблокированные миссии игнорируются ядром.
- `retry_mission()` — сбросить попытку и перезапустить текущую миссию с нуля.
- `next_mission()` — переключиться на следующую открытую миссию.
- `request_resume()` — вызывается по нажатию кнопки **«Продолжить»**. Снимает барьер ввода только если кадр нейтрален и свеж.

### Настройки
- `toggle_hand_side()` — переключить раскладку левая/правая рука (сохраняется автоматически).
- `set_hand_side(is_left: bool)` — явно задать сторону руки.

### Эмулятор ввода (Сенсорная панель `manual_pad`)
- `set_channel_values(a: float, b: float)` — передать сырые значения каналов `0.0..1.0` при таче/драге.
- `clear_channel_values()` — сбросить каналы в `0.0` при отпускании всех пальцев.

---

## 4. Где лежат данные для UI

Astra **не зашивает тексты и параметры в код**. Все данные берутся из готовых структур:

1. **Тексты и подсказки:**
   - Markdown-источник: [game/content/copy-ru.md](file:///d:/GamejamCyberhand/game/content/copy-ru.md)
   - Класс доступа в коде: [CopyCatalog](file:///d:/GamejamCyberhand/game/content/copy_catalog.gd)
     - `CopyCatalog.HEADER_TITLE`
     - `CopyCatalog.HEADER_SUBTITLE`
     - `CopyCatalog.EMULATOR_DISCLAIMER`
     - `CopyCatalog.TUTORIAL_HINTS`
     - `CopyCatalog.state_message(command)`
     - `CopyCatalog.reason_text(reason)`
2. **Конфигурации миссий и сюжет:**
   - Класс: [LevelConfig](file:///d:/GamejamCyberhand/game/core/level_config.gd)
     - `LevelConfig.ordered_ids()` — список ID миссий (`["tutorial", "repair-1", "repair-2", "repair-3"]`).
     - `LevelConfig.for_id(level_id, difficulty_step)`:
       - `title` — название миссии.
       - `hazard_subtitle` — тип угрозы (жара, буря, токсины).
       - `briefing` — текст брифинга.
       - `upgrade_unlocked` — разблокированный модуль базы.
       - `expedition_log` — фрагмент лога прежней экспедиции.
       - `walls` — массив препятствий `Rect2` (в нормализованных координатах `0..1`).
       - `hold_zone` — зона стабилизации `Rect2`.
3. **Локальное сохранение (только чтение для UI):**
   - Класс: [LocalStore](file:///d:/GamejamCyberhand/game/core/local_store.gd)
   - Поля профиля: `hand_side`, `unlocked_levels`, `completed_levels`, `difficulty_steps`, `last_summary`.
4. **Цветовая палитра проекта (рекомендация для стиля):**
   - Фон космоса/базы: `#08111d`, `#101d30`
   - Панели и карточки: `#12263a`, `#18334c`
   - Акцент манипулятора / успех: `#8af0d4`, `#237f85`, `#3caea3`
   - Переборки / препятствия: `#df9675`
   - Предупреждения / BOTH / нейтраль: `#ffd166`
   - Ошибки / отключение: `#ff9b9b`

---

## 5. Что Astra НЕ ДОЛЖНА трогать

Следующие компоненты находятся в исключительной зоне ответственности Августа:

1. **Каталог `game/core/` целиком:**
   - `input_pipeline.gd`, `input_decoder.gd`, `input_validator.gd`, `input_stream_guard.gd`, `manual_input_source.gd`, `input_config.gd`, `input_frame.gd`, `control_command.gd`, `replay_input_source.gd`.
   - Нельзя менять формулу интенсивности, значения порогов по умолчанию (`0.55 / 0.40`), время таймаута (`250 ms`) или логику гистерезиса.
2. **Логика прогрессии и сохранения:**
   - `session_tracker.gd`, `session_summary.gd`, `local_store.gd`.
   - Нельзя напрямую записывать в файл сохранения или менять формат JSON без версионирования.
3. **Коллизии и физика маршрута:**
   - Логика функции `advance()` и метод `_collides()` в `game/gameplay/course.gd`.
4. **Конфигурационные файлы проекта:**
   - `project.godot`, `export_presets.cfg`, `contracts/`, `qa/prototype_smoke.gd`.
