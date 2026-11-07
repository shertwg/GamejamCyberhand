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
