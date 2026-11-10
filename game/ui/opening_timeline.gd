extends RefCounted
## Times are shared with tools/compose_opening.py. Shot IDs are independent
## from the later chapter and takeoff frames.
const TIMECODES := [0.0, 5.0, 9.5, 13.2, 17.4, 21.3, 26.2, 33.0]
const SHOTS := [0, 9, 10, 1, 11, 2, 12]
const VOICE_CUES := [
	[1.05, 4.70, "orbit", "Рейнджер: Керна внизу. Ещё виток, и домой."],
	[5.60, 9.20, "steady", "Маяк: курс подтверждён. Тяга стабильна."],
	[10.20, 12.95, "failure", "Маяк: сбой питания. Тяга пропала."],
	[13.65, 17.15, "manual", "Рейнджер: перехожу на ручное. Держу курс."],
	[17.75, 21.15, "ridge", "Маяк: впереди скалы. Левее — плато."],
	[26.65, 29.00, "alive", "Рейнджер: Маяк… ты здесь?"],
	[29.20, 32.95, "pressure", "Маяк: здесь. Давление падает. Закрой заслонку."]
]
const DURATION := 33.0

static func frame_at(seconds: float) -> int:
	for index in range(SHOTS.size() - 1, 0, -1):
		if seconds >= TIMECODES[index]: return index
	return 0

static func subtitle_at(seconds: float) -> String:
	for line in VOICE_CUES:
		if seconds >= line[0] and seconds < line[1]:
			return line[3]
	return ""
