class_name CopyCatalog
extends RefCounted
## Centralized Russian copy catalog matching game/content/copy-ru.md.
## Allows Arina to update texts without touching UI or gameplay logic.

const HEADER_TITLE: String = "РЕЙНДЖЕР · ПРОТОКОЛ ВОЗВРАЩЕНИЯ"
const HEADER_SUBTITLE: String = "ЭМУЛЯТОР КАНАЛОВ · A — ОТКРЫТИЕ (↑) · B — ЗАКРЫТИЕ (↓)"
const EMULATOR_DISCLAIMER: String = "Эмулятор каналов, не медицинское измерение."

const TUTORIAL_HINTS: Array[String] = [
	"Шаг 1/4: Нажмите «Продолжить» при отпущенных A и B.",
	"Шаг 2/4: Удерживайте A (OPEN ↑) или B (CLOSE ↓), чтобы обойти переборку.",
	"Шаг 3/4: Проведите дрон через зелёную зону стабилизации в центре отсека.",
	"Шаг 4/4: Доведите ремонтный дрон до правого шлюза корабля.",
]


static func state_message(command) -> String:
	if command == null:
		return "Ввод ещё не запущен."
	match command.state:
		&"ACTIVE":
			if command.direction == &"OPEN":
				return "A: захват открывается (вверх). Движение и таймер идут."
			return "B: захват закрывается (вниз). Движение и таймер идут."
		&"REST":
			return "Покой: движение и таймер остановлены. Нажмите и удерживайте A или B."
		&"BOTH":
			return (
				"Обе кнопки нажаты: движение и таймер остановлены. "
				+ "Отпустите A и B, затем выберите одну кнопку."
			)
		&"WAITING_NEUTRAL":
			return (
				"Нужен нейтральный ввод: отпустите A и B. "
				+ "Движение и таймер стоят. Причина: %s."
			) % reason_text(command.reason)
		&"WAITING_RESUME":
			return (
				"Ввод готов к продолжению. Отпустите A и B "
				+ "и нажмите «Продолжить»."
			)
		&"STALE":
			return (
				"Сигнал ввода устарел (%s): движение и таймер остановлены. "
				+ "Отпустите A и B, затем нажмите «Продолжить»."
			) % reason_text(command.reason)
		&"DISCONNECTED":
			return (
				"Нет сигнала ввода: движение и таймер остановлены. "
				+ "Отпустите A и B, затем нажмите «Продолжить»."
			)
		&"INVALID":
			return (
				"Ввод отклонён как небезопасный (%s): движение и таймер остановлены. "
				+ "Отпустите A и B, затем нажмите «Продолжить»."
			) % reason_text(command.reason)
		&"SUSPENDED":
			return (
				"Игра приостановлена: движение и таймер остановлены. "
				+ "Отпустите A и B, затем нажмите «Продолжить»."
			)
		&"NOT_STARTED":
			return "Ввод ещё не запущен."
		_:
			return "Состояние ввода: %s." % command.state


static func reason_text(reason: StringName) -> String:
	match reason:
		&"opposing_channels":
			return "одновременно нажаты A и B"
		&"both_requires_neutral":
			return "нужно отпустить обе кнопки"
		&"stream_timeout":
			return "нет свежих кадров"
		&"stale_frame":
			return "кадр устарел"
		&"source_disconnected":
			return "источник отключён"
		&"external_suspend":
			return "приложение было свёрнуто"
		&"new_stream_requires_neutral":
			return "новый поток начинается с покоя"
		&"resumed_neutral":
			return "поток восстановлен"
		&"neutral":
			return "покой"
		&"channel_a":
			return "канал A"
		&"channel_b":
			return "канал B"
		_:
			return String(reason)


# Terminal interface copy; mission story remains in LevelConfig.
const START = "Начать миссию  →"
const RETRY = "Повторить маршрут"
const NEXT = "Следующий ремонт  →"
const RESUME = "Продолжить"
const SUCCESS = "КОНТУР ВОССТАНОВЛЕН"
const BRIEFING_NOTE = "Отпустите обе кнопки, чтобы отдохнуть: движение и таймер остановятся. После старта подтвердите готовность кнопкой «Продолжить»."
const CYCLE = "Сменить миссию · доступно %d"
const HAND = "Раскладка: %s рука  ⇄"
const HAND_LEFT = "левая"
const HAND_RIGHT = "правая"
const PAD_A = "A · OPEN ↑"
const PAD_B = "B · CLOSE ↓"
const EMULATOR = "[ЭМУЛ]"
const BOTH_WARNING = "A + B · ПРИВОД ЗАБЛОКИРОВАН"
const ACTIVE_TIME = "ВРЕМЯ В ДВИЖЕНИИ  %06.1f с"
const HOLD_ACTIVE = "◉  В зоне стабилизации"
const HOLD_IDLE = "○  Зона стабилизации впереди"
const LOCKED = "ЗАКРЫТО"
const AVAILABLE = "ДОСТУПНО"
const SELECTED = "ВЫБРАНО"
const METRIC_BOTH = "Встречный сигнал"
const METRIC_HOLD = "Точность удержания"
const NO_DATA = "Нет данных"
const LOG_TITLE = "ЖУРНАЛ ЭКСПЕДИЦИИ"
const RESULT_NOTE = "Показатели игры на эмуляторе, не медицинская оценка."

const MISSION_SHORT = {"tutorial": "Обучение", "repair-1": "Контур охлаждения", "repair-2": "Генератор", "repair-3": "Герметизация и маяк"}

const SHIP_TITLE = "МАЯК · ПУТЬ ДОМОЙ"
const SHIP_SUBTITLE = "Аварийная посадка. Четыре контура отделяют нас от взлёта."
const SHIP_MODULES = ["Мастерская", "Охлаждение", "Генератор", "Маяк и шлюз"]
const REPAIRED = "ВОССТАНОВЛЕНО"
const SHIP_RETURN = "Вернуться на корабль"
const COOLANT_TITLE = "КОНТУР ОХЛАЖДЕНИЯ · СЕРВИСНЫЙ ДРОН"
const COOLANT_HINT = "Доставьте хладагент через заслонки в приёмный шлюз. A — вверх, B — вниз."

const SHIP_DONE = "Готово"
const SHIP_REPAIR = "Ремонт"
const SHIP_LOCKED = "Закрыто"
