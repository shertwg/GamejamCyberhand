# Гайд по структуре UI-сцен и интеграции (`game/ui/`)

Документ предназначен для **Астры** (визуальное оформление, тема, типографика, иконки и анимации в Godot 4.4.1) и **Августа** (интеграция с `core`/`gameplay` и настройками проекта).

---

## 1. Соответствие запрошенных имён сцен фактическим файлам

Чтобы не плодить дублирующиеся сцены и сохранить рабочую навигацию между экранами, существующие файлы в `game/ui/` сохранены, а пады эмулятора выделены в переиспользуемую подсцену:

| Запрошенное имя в задаче | Фактический файл в проекте | Назначение |
| :--- | :--- | :--- |
| `game_view.tscn` | `res://game/ui/game_screen.tscn` (`game_screen.gd`) | Основной игровой экран: статус команды, мониторинг каналов A/B, инстанс `EmulatorPad`, кнопки паузы/выхода и модальный оверлей `WaitingResumeOverlay`. |
| `hud_overlay` | Встроен в `res://game/ui/game_screen.tscn` + `res://game/ui/pause_screen.tscn` | Секции `CommandStatusSection`, `ChannelMonitorSection`, `EventStatusLine`, `NavActionsGrid` и модальный слой `WaitingResumeOverlay` внутри `game_screen.tscn`; экран паузы — в `pause_screen.tscn`. |
| `emulator_pad.tscn` | `res://game/ui/emulator_pad.tscn` (`emulator_pad.gd`) | Выделенная сцена тач-контролов и ползунков каналов A (`OPEN`) и B (`CLOSE`) с поддержкой независимого мультитача (`InputEventScreenTouch` / `InputEventScreenDrag`) и зеркалирования под левую руку. Инстанцируется внутри `game_screen.tscn` как узел `EmulatorPad`. |
| `start_screen` | `res://game/ui/start_screen.tscn` (`start_screen.gd`) | Стартовый экран («Орбитальная мастерская») с переходом к настройкам, калибровке, обучению и демо-игре. |
| `settings_screen` | `res://game/ui/settings_screen.tscn` (`settings_screen.gd`) | Выбор ведущей руки (`right` / `left`) и этапа (`repair-1`, `repair-2`, `repair-3`). |
| `calibration_screen` | `res://game/ui/calibration_screen.tscn` (`calibration_screen.gd`) | Экран подготовки/калибровки перед запуском. |
| `tutorial_screen` | `res://game/ui/tutorial_screen.tscn` (`tutorial_screen.gd`) | Пошаговая инструкция по каналам `A → OPEN`, `B → CLOSE`, `BOTH` и безопасному режиму. |
| `pause_screen` | `res://game/ui/pause_screen.tscn` (`pause_screen.gd`) | Экран паузы: продолжить, повторить попытку, сменить руку/уровень, выйти в меню. |
| `result_screen` | `res://game/ui/result_screen.tscn` (`result_screen.gd`) | Экран итогов сессии по контракту `SessionSummary` (этап, активное время, успешные действия, удержание, медиана реакции, ко-активация, источник сигнала). |

---

## 2. Общая тема (`res://game/ui/theme/default_theme.tres`)

Все 8 `.tscn`-сцен в `game/ui/` подключены к единому ресурсу темы `res://game/ui/theme/default_theme.tres` (схема генерации и константы токенов описаны в `res://game/ui/ui_theme.gd`).

### Вариации типов (`theme_type_variation`) в `default_theme.tres`:

- **Кнопки (`Button`)**:
  - `Button` (базовый) / `ADSSubtleButton` — вторичные кнопки навигации и выбора опций (высота `>= 48 dp`).
  - `ADSPrimaryButton` — основное действие на экране (`StartButton`, `ResumeButton`, `RetryButton`, `ResumeOverlayButton`).
  - `ADSPadButton` — тач-пад канала эмулятора в состоянии покоя (`PadButtonA`, `PadButtonB`).
  - `ADSPadButtonActive` — тач-пад канала эмулятора при активном удержании или сигнале `>= 0.35` (контрастная рамка `2 px`, изменённый фон, маркеры `◆ ... ◆` и статус `[ АКТИВЕН · 0.85 ]`).
- **Панели (`PanelContainer`)**:
  - `FieldSurfacePanel` — карточка блока `EmulatorPad`.
  - `WaitingResumePanel` — модальная карточка `WaitingResumeCard` поверх затемнения при возврате в приложение.
- **Типографика (`Label`)**:
  - `PageTitle` (28 px), `SectionTitle` (15 px), `MetricLabel` (24 px), `SignalValueLabel` (16 px), `BodyText` (14 px), `SubtleLabel` (13 px), `SubtlestLabel` (12 px), `EyebrowLabel` (11 px).
  - Семантические статусы команд и событий: `InfoStateLabel` (`OPEN`/`CLOSE`), `WarningStateLabel` (`BOTH`), `DangerStateLabel` (потеря сигнала), `SuccessMessage` (успех), `DangerMessage` (промах).
- **Ползунки (`HSlider`)**:
  - Настроены стили `slider`, `grabber_area`, `grabber_area_highlight` с видимой толщиной дорожки (`content_margin_top/bottom = 4`, `border_width = 1`).

---

## 3. Дерево узлов в `.tscn` сценах

Все `.tscn`-файлы сериализованы с полной контейнерной иерархией — Астра может открывать любую сцену в 2D-редакторе Godot 4.4.1 и видеть все контейнеры, подписи и кнопки без запуска игры.

### Базовый каркас каждого экрана (`ui_base.gd`)
```text
<ScreenRoot> (Control, theme = default_theme.tres)
├── Background (ColorRect, full rect, mouse_filter = IGNORE)
└── SafeAreaMargin (MarginContainer, автоматически учитывает DisplayServer.get_display_safe_area())
    └── PageScroll (ScrollContainer, вертикальная прокрутка на узких экранах)
        └── PageCenter (CenterContainer)
            └── PageContent (VBoxContainer, адаптивная ширина до 760–880 px)
                ├── PageHeader (VBoxContainer: BrandLine, KickerLabel, PageTitleLabel, PageDescriptionLabel, HeaderDivider)
                └── ... секции конкретного экрана ...
```

### Ключевые узлы по сценам

1. **`res://game/ui/start_screen.tscn`**:
   - `IntroSection/SectionBody/IntroBodyLabel`, `IntroSection/SectionBody/IntroNoteLabel`
   - `PrimaryActionRow/StartButton` (основная кнопка старта), `PrimaryActionRow/StartNoteLabel`
   - `SecondaryNavGrid`: `HandAndLevelButton`, `CalibrationButton`, `TutorialButton`, `DemoGameButton`
2. **`res://game/ui/settings_screen.tscn`**:
   - `HandSection/SectionBody/HandButtonsGrid`: `RightHandButton`, `LeftHandButton`, `SelectedHandStatusLabel`
   - `LevelSection/SectionBody`: `LevelRepair1Button`, `LevelRepair2Button`, `LevelRepair3Button`, `SelectedLevelStatusLabel`
   - `SettingsNavGrid`: `BackToStartButton`, `ContinueToCalibrationButton`
3. **`res://game/ui/calibration_screen.tscn`**:
   - `CalibrationSection/SectionBody`: `SelectedParamsLabel`, `CalibrationRuleLabel`, `CalibrationDemoNoteLabel`
   - `CalibrationNavGrid`: `ChangeHandOrLevelButton`, `ToTutorialButton`, `SkipToGameButton`
4. **`res://game/ui/tutorial_screen.tscn`**:
   - `StepsSection/SectionBody`: `StepRow01`..`StepRow04` (`StepNumber01`..`04`, `StepTitle01`..`04`, `StepDetail01`..`04`)
   - `TutorialNavGrid`: `BackToCalibrationButton`, `StartGameButton`
5. **`res://game/ui/game_screen.tscn`**:
   - `CommandStatusSection/SectionBody/CommandGrid`: `CommandLine/CommandLabel` (`REST`/`OPEN`/`CLOSE`/`BOTH`), `CommandLine/IntensityLabel`, `HintLabel`
   - `ChannelMonitorSection/SectionBody/MonitorGrid`:
     - `MeterRowA` (`ChannelTitleA`, `ValueLabelA`, `ChannelAMeter`, `MeterScaleRow`)
     - `MeterRowB` (`ChannelTitleB`, `ValueLabelB`, `ChannelBMeter`, `MeterScaleRow`)
   - `EmulatorPad` (инстанс `res://game/ui/emulator_pad.tscn`)
   - `EventStatusLine/EventLabel` + `EventActionsGrid` (`SuccessEventButton`, `MissEventButton`, `StaleSignalButton`)
   - `NavActionsGrid` (`PauseButton`, `ExitButton`, `FinishDemoButton`)
   - `WaitingResumeOverlay` (`z_index = 100`, `process_mode = PROCESS_MODE_ALWAYS`):
     - `ResumeSafeMargin/ResumeCenter/WaitingResumeCard/ResumeCardContent`: `ResumeEyebrowLabel`, `ResumeTitleLabel`, `ResumeBodyLabel`, `ResumeOverlayButton` («Продолжить»)
6. **`res://game/ui/emulator_pad.tscn`**:
   - `SurfaceMargin/SurfaceContent/HeaderGrid`: `EmulatorEyebrow`, `EmulatorSubtitle`
   - `SurfaceMargin/SurfaceContent/PadsGrid`:
     - `ChannelAColumn`: `ChannelATitle`, `PadButtonA`, `SliderA`, `ScaleRowA` (`MinLabelA`, `ScaleNoteA`, `MaxLabelA`)
     - `ChannelBColumn`: `ChannelBTitle`, `PadButtonB`, `SliderB`, `ScaleRowB` (`MinLabelB`, `ScaleNoteB`, `MaxLabelB`)
7. **`res://game/ui/pause_screen.tscn`**:
   - `PauseActionsSection/SectionBody`: `ResumeButton`, `PauseSecondaryGrid` (`RetryButton`, `HandAndLevelButton`, `ExitToMenuButton`)
8. **`res://game/ui/result_screen.tscn`**:
   - `SummarySection/SectionBody/PrimaryMetricsGrid`: `MetricColumnStage`, `MetricColumnTime`, `MetricColumnSuccess`
   - `SummarySection/SectionBody/SecondaryMetricsGrid`: `MetricColumnHold`, `MetricColumnReaction`, `MetricColumnBoth`, `MetricColumnSource`
   - `ResultNavGrid`: `RetryButton`, `ChangeLevelButton`, `MainMenuButton`

---

## 4. Что Астре можно менять свободно, а что трогать нельзя

### Можно менять свободно:
- Цвета, скругления (`corner_radius_*`), толщину рамок (`border_width_*`), внутренние отступы (`content_margin_*`) и шрифты в `res://game/ui/theme/default_theme.tres`.
- Цвет или текстуру фона `Background` (можно заменить `ColorRect` на `TextureRect` или добавить декоративные фоновые слои с `mouse_filter = MOUSE_FILTER_IGNORE` позади `SafeAreaMargin`).
- Константы отступов контейнеров (`separation`, `h_separation`, `v_separation`) в разумных пределах, проверяя, что на `1280×720` и `1240×2772` контент не обрезается.
- Иконки кнопок (`icon` у `Button`), декоративные разделители (`HeaderDivider`, `SectionDivider`).

### Нельзя переименовывать или отключать без согласования со скриптами:
- **Имена интерактивных и связующих узлов** (скрипты ищут их по имени через `get_node_or_null` / `find_child` во избежание дублирования при загрузке `.tscn`):
  - Базовые контейнеры: `Background`, `SafeAreaMargin`, `PageScroll`, `PageCenter`, `PageContent`, `PageHeader`.
  - В `game_screen.tscn`: `CommandStatusSection`, `CommandGrid`, `CommandLine`, `CommandLabel`, `IntensityLabel`, `HintLabel`, `ChannelMonitorSection`, `MonitorGrid`, `MeterRowA`, `MeterRowB`, `ValueLabelA`, `ValueLabelB`, `ChannelAMeter`, `ChannelBMeter`, `EmulatorPad`, `EventStatusLine`, `EventLabel`, `EventActionsGrid`, `NavActionsGrid`, `PauseButton`, `ExitButton`, `FinishDemoButton`, `WaitingResumeOverlay`, `ResumeSafeMargin`, `ResumeOverlayButton`.
  - В `emulator_pad.tscn`: `SurfaceMargin`, `SurfaceContent`, `HeaderGrid`, `PadsGrid`, `ChannelAColumn`, `ChannelBColumn`, `PadButtonA`, `PadButtonB`, `SliderA`, `SliderB`, `ScaleRowA`, `ScaleRowB`, `MinLabelA`, `MaxLabelA`, `MinLabelB`, `MaxLabelB`.
- **Свойства `PadButtonA` и `PadButtonB`**:
  - `button_mask = 0` — обязательно оставить `0`, так как мультитач и мышь обрабатываются напрямую в `emulator_pad.gd:_input(event)` по индексам пальцев (`InputEventScreenTouch.index`), чтобы одновременное нажатие A и B двумя пальцами (`BOTH`) не блокировалось фокусом одной кнопки.
  - Минимальный размер тач-пада не уменьшать ниже `48×48 dp`.
- **Свойства `WaitingResumeOverlay` и `ResumeOverlayButton`**:
  - `process_mode = Node.PROCESS_MODE_ALWAYS` (должен отвечать на нажатие «Продолжить», даже когда `get_tree().paused == true`).
  - `WaitingResumeOverlay.mouse_filter = Control.MOUSE_FILTER_STOP` и `z_index = 100` (блокирует случайные касания падов под оверлеем).
- **Зеркалирование левой руки**:
  - При выборе левой руки зеркалятся **только** контролы внутри `EmulatorPad` (`ChannelBColumn` слева, `ChannelAColumn` справа, `SliderA`/`SliderB` в `RTL`). Блок мониторинга `ChannelMonitorSection` (`КАНАЛ A · OPEN` слева, `КАНАЛ B · CLOSE` справа) **не зеркалится**.

---

## 5. Как запускать и проверять UI-сцены без изменения `project.godot`

Поскольку `project.godot` и `game/main.tscn` принадлежат Августу, UI-сцены запускаются автономно:

1. **Через редактор Godot 4.4.1**:
   - Откройте любую сцену из `res://game/ui/` (например, `res://game/ui/start_screen.tscn` или `res://game/ui/game_screen.tscn`).
   - Нажмите **`F6` (Run Current Scene)**.
   - При запуске любой UI-сцены автоматически поднимается временный демо-рантайм `UIDemoRuntime` (`res://game/ui/ui_demo_runtime.gd`), позволяющий пройти весь маршрут: `start_screen` → `settings_screen` → `calibration_screen` → `tutorial_screen` → `game_screen` → `pause_screen` / `result_screen`.
2. **Через командную строку Godot 4.4.1**:
   ```powershell
   Godot_v4.4.1-stable_win64.exe --path c:\dev\yberruka res://game/ui/start_screen.tscn
   ```
3. **Проверка оверлея `WAITING_RESUME` на ПК**:
   - Откройте `res://game/ui/game_screen.tscn` (`F6`) и сверните окно игры или переключите фокус на другое окно (`Alt+Tab`).
   - При потере фокуса (`NOTIFICATION_APPLICATION_FOCUS_OUT`) рантайм автоматически сбрасывает каналы A/B в `REST` (`0.00`) и показывает модальный оверлей `WaitingResumeOverlay` с кнопкой «Продолжить».

---

## 6. Инструкция для Августа по интеграции

1. **Подключение UI в основной маршрут (`project.godot` / `game/main.tscn`)**:
   - Точка входа UI-маршрута — `res://game/ui/start_screen.tscn` (или инстанцирование нужных экранов внутри `game/main.tscn`).
   - Временный узел `UIDemoRuntime` (`res://game/ui/ui_demo_runtime.gd`) сохраняет исходные значения `root.content_scale_mode`, `root.content_scale_aspect` и `root.content_scale_size` при входе в UI-сцену и автоматически восстанавливает их при переходе на любую сцену вне `res://game/ui/` (`check_restore_window_scale()`).
2. **Замена `UIDemoRuntime` на боевой адаптер `core`**:
   - В `ui_demo_runtime.gd` задокументирован контрактный шов:
     - Методы: `start_session(level_id)`, `pause()`, `resume()`, `retry()`, `exit()`, `trigger_waiting_resume()`, `resume_from_waiting()`.
     - Сигналы: `input_frame_received(frame)`, `command_display_changed(direction, intensity, hint)`, `demo_event_changed(hint)`, `session_started(level_id)`, `session_paused`, `session_resumed`, `session_finished(summary)`, `session_exited`, `waiting_resume_changed(active)`.
3. **Рекомендация по ориентации и настройкам окна для Android (`project.godot` / `export_presets.cfg`)**:
   - UI протестирован и адаптирован как для **альбомной** (`1280×720`, `1920×1080`, `2772×1240`), так и для **портретной** (`1240×2772`) ориентации с учётом `DisplayServer.get_display_safe_area()`.
   - Для основного геймплея с двухканальным захватом и одновременным мультитачем двумя большими пальцами (`PadButtonA` + `PadButtonB`) **рекомендуется альбомная ориентация (Landscape / Sensor Landscape)** с базовым окном `1280×720`, `stretch/mode = "canvas_items"`, `stretch/aspect = "expand"`, однако при необходимости запуска в портретном или свободном режиме (`sensor`) UI автоматически перестраивает сетки в 1 колонку без обрезания кнопок и текста.
