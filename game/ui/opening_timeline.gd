extends RefCounted
## Times are shared with tools/compose_opening.py. Shot IDs are independent
## from the later chapter and takeoff frames.
const TIMECODES := [0.0, 5.0, 9.5, 13.2, 17.4, 21.3, 26.2, 33.0]
const SHOTS := [0, 9, 10, 1, 11, 2, 12]
const DIALOGUE_CUES := [
	[1.05, 4.70, "orbit", "Рейнджер: Вон она, Керна. Ещё виток — и домой."],
	[5.60, 9.20, "steady", "Маяк: Курс держу. Тяга в норме."],
	[10.20, 12.95, "failure", "Маяк: Тяги нет. Мы падаем."],
	[13.65, 17.15, "manual", "Рейнджер: Беру штурвал. Куда садиться?"],
	[17.75, 21.15, "ridge", "Маяк: Левее. Видишь светлый склон? За ним плато."],
	[26.65, 29.00, "alive", "Рейнджер: Маяк… ты меня слышишь?"],
	[29.20, 32.95, "pressure", "Маяк: Слышу. Уходит воздух. Закрой заслонку."]
]
const DURATION := 33.0

static func frame_at(seconds: float) -> int:
	for index in range(SHOTS.size() - 1, 0, -1):
		if seconds >= TIMECODES[index]: return index
	return 0
