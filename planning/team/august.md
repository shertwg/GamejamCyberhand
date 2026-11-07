# Август — карточка капитана shertwg

**Ветка:** `feat/avgust-core` (и рабочая интеграционная `feat/avgust-core-night`)  
**Роль:** тимлид, ядро (`game/core/`), интеграция, экспорт Android APK и сдача.

Перед началом прочитай `AGENTS.md`, `planning/AI_PROJECT_CONTEXT.md` и `planning/foundation.md`.

## Что уже собрано в фундаменте (`585d9cc`)

1. **Безопасный пайплайн ввода (`game/core/input_*.gd`, `manual_input_source.gd`, `control_command.gd`):** пороги `on=0.55 / off=0.40`, гистерезис, пропорциональная интенсивность, `REST / OPEN / CLOSE / BOTH`, watchdog 250 ms, барьер нейтрали + `WAITING_RESUME`.
2. **События и метрики (`game/core/game_event.gd`, `session_tracker.gd`, `session_summary.gd`):** дедупликация по `event_id`, подсчёт активного времени, `unwanted_both_ms`, удержания в зоне стабилизации и медианы реакции; защита от деления на ноль (`null`).
3. **Локальное хранилище (`game/core/local_store.gd`):** сохранение профиля, руки (`right`/`left`), открытых/пройденных миссий рейнджера и шагов адаптации в `user://ranger_profile_v1.json` с безопасным восстановлением при повреждении файла (`corrupted_recovered`).
4. **Воспроизводимые трассы (`game/core/replay_input_source.gd`):** 6 эталонных трасс (`clean_a`, `clean_b`, `rest`, `opposing_both`, `threshold_jitter`, `disconnect_recovery`).
5. **Каталог миссий рейнджера (`game/core/level_config.gd`):** `tutorial`, `repair-1` (клапан охлаждения), `repair-2` (энергоячейка генератора), `repair-3` (герметизация и маяк) + ограниченная адаптация `-1 / 0 / +1`.

## Текущие задачи капитана

1. **Требования и сверка ТЗ (P0).** Сверить концепцию «Рейнджер на враждебной планете» и метрики с полным ТЗ организаторов, когда оно доступно.
2. **Интеграция модулей команды (P0).** Принимать сцены UI от Антона (`game/ui/`), доработки геймплея от Димы (`game/gameplay/`) и правки текстов от Арины (`game/content/copy-ru.md` → `copy_catalog.gd`), сохраняя 0 ошибок в `res://qa/prototype_smoke.gd`.
3. **Подключение `ReplayInputSource` для демонстрации и QA (P1).** Дать возможность прогонять эталонные трассы на экране без ручного касания.
4. **Сборка APK и финальный пакет сдачи (P0).** Экспортировать `builds/android/shertwg-debug.apk` через пресет `Android Debug APK`, проверять на `Medium_Phone_D_API37` и реальном телефоне, вести `evidence/ai-log.csv` и `evidence/test-runs.csv`.

## Файлы

Основные: `project.godot`, `export_presets.cfg`, `game/main.tscn`, `game/main.gd`, `game/core/*`, `game/content/copy_catalog.gd`, `contracts/*`, `planning/*`. Все `git commit / push / merge` выполняет Август.
