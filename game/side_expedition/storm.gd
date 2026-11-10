extends RefCounted
## Scaled active simulation time only. REST/faults never call advance().
const CALM := 2.8
const WARNING := 2.6
const GUST := 1.3
const CYCLE := CALM + WARNING + GUST
var clock: float = 0.0
var phase: String = "calm"
var cycle: int = 0
var strength: float = 0.0

func reset() -> void:
	clock = 0.0
	phase = "calm"
	cycle = 0
	strength = 0.0

func advance(delta: float) -> void:
	clock += maxf(0, delta)
	cycle = int(clock / CYCLE)
	var local := fmod(clock, CYCLE)
	phase = "calm" if local < CALM else ("warning" if local < CALM + WARNING else "gust")
	strength = 0.15 if phase == "calm" else (0.45 if phase == "warning" else 1.0)

func cue() -> String:
	match phase:
		"warning": return "ПОРЫВ СКОРО · к навесу! В укрытии держи A, чтобы переждать."
		"gust": return "ПОРЫВ · укрытие держит. На открытом месте отбросит назад."
	return "Ветер стих. Можно идти к следующему укрытию."
