class_name LevelConfig
extends RefCounted
## Data-driven mission definitions and bounded difficulty adaptation for
## "Рейнджер на враждебной планете". Kept separate from scene rendering.

var level_id: String = "repair-1"
var title: String = "МИССИЯ 1 · КЛАПАН ОХЛАЖДЕНИЯ"
var hazard_subtitle: String = "Угроза: перегрев контура · Широкие заслонки"
var briefing: String = ""
var upgrade_unlocked: String = ""
var expedition_log: String = ""
var walls: Array[Rect2] = []
var hold_zone: Rect2 = Rect2(0.42, 0.12, 0.14, 0.24)
var hold_target_ms: int = 1200
var horizontal_speed: float = 0.085
var vertical_speed: float = 0.48
var count_both_as_unwanted: bool = true


static func ordered_ids() -> Array[String]:
	return ["tutorial", "repair-1", "repair-2", "repair-3"]


static func for_id(p_level_id: String, difficulty_step: int = 0) -> LevelConfig:
	var cfg := LevelConfig.new()
	var step := clampi(difficulty_step, -1, 1)
	match p_level_id:
		"tutorial":
			cfg.level_id = "tutorial"
			cfg.title = "ОБУЧЕНИЕ · КАЛИБРОВКА МАНИПУЛЯТОРА"
			cfg.hazard_subtitle = "Безопасный отсек · Робот-напарник «Маяк»"
			cfg.briefing = (
				"Проверим связь с ремонтным дроном корабля.\n"
				+ "Канал A поднимает захват (OPEN ↑), канал B опускает (CLOSE ↓).\n"
				+ "Одновременное нажатие A+B безопасно стопорит привод."
			)
			cfg.upgrade_unlocked = "Мастерская робота-напарника активирована"
			cfg.expedition_log = "Запись #0: «Аварийная посадка прошла жёстко, но робот цел. Начнём с базовых контуров»."
			cfg.walls = [
				Rect2(0.32, 0.0, 0.05, 0.52),
				Rect2(0.64, 0.48, 0.05, 0.52),
			]
			cfg.hold_zone = Rect2(0.44, 0.14, 0.16, 0.30)
			cfg.hold_target_ms = 800
			cfg.horizontal_speed = 0.095
			cfg.vertical_speed = 0.50
			cfg.count_both_as_unwanted = false
		"repair-2":
			cfg.level_id = "repair-2"
			cfg.title = "МИССИЯ 2 · ЭНЕРГОЯЧЕЙКА ГЕНЕРАТОРА"
			cfg.hazard_subtitle = "Угроза: пыльная буря · Удержание и перенос"
			cfg.briefing = (
				"Буря глушит солнечные панели. Проведите энергоячейку через "
				+ "двойной магнитный шлюз и удерживайте курс в верхнем коридоре стабилизации."
			)
			cfg.upgrade_unlocked = "Главный генератор и освещение жилого модуля включены"
			cfg.expedition_log = "Запись #2: «Прежняя экспедиция оставила резервный контур в скалах. С питанием мы сможем запустить маяк»."
			cfg.walls = [
				Rect2(0.24, 0.0, 0.055, 0.62),
				Rect2(0.48, 0.36, 0.055, 0.64),
				Rect2(0.72, 0.0, 0.055, 0.62),
			]
			cfg.hold_zone = Rect2(0.36, 0.08, 0.14, 0.24)
			cfg.hold_target_ms = 1600
			cfg.horizontal_speed = 0.085
			cfg.vertical_speed = 0.48
			cfg.count_both_as_unwanted = true
		"repair-3":
			cfg.level_id = "repair-3"
			cfg.title = "МИССИЯ 3 · ГЕРМЕТИЗАЦИЯ И МАЯК"
			cfg.hazard_subtitle = "Угроза: ядовитый воздух и шторм · Точная доводка"
			cfg.briefing = (
				"Токсичный фронт подходит к базе. Проведите пломбу через узкие переборки "
				+ "отсека жизнеобеспечения и подключите передатчик спасательного маяка."
			)
			cfg.upgrade_unlocked = "Отсек герметизирован · Корабль готов к взлёту с планеты!"
			cfg.expedition_log = "Запись #3: «Сигнал принят орбитальным катером! Двигатели выходят на тягу — мы возвращаемся домой»."
			cfg.walls = [
				Rect2(0.22, 0.0, 0.055, 0.65),
				Rect2(0.46, 0.35, 0.055, 0.65),
				Rect2(0.70, 0.0, 0.055, 0.65),
			]
			cfg.hold_zone = Rect2(0.32, 0.08, 0.12, 0.22)
			cfg.hold_target_ms = 2000
			cfg.horizontal_speed = 0.088
			cfg.vertical_speed = 0.48
			cfg.count_both_as_unwanted = true
		_:
			# Default "repair-1": preserves exact baseline geometry for deterministic smoke checks.
			cfg.level_id = "repair-1"
			cfg.title = "МИССИЯ 1 · КЛАПАН ОХЛАЖДЕНИЯ"
			cfg.hazard_subtitle = "Угроза: экстремальная жара · Крупные узлы"
			cfg.briefing = (
				"После аварийной посадки перегревается реактор базы.\n"
				+ "Проведите хладагент через три заслонки к правому шлюзу охлаждения."
			)
			cfg.upgrade_unlocked = "Контур охлаждения запущен · Температура в отсеке в норме"
			cfg.expedition_log = "Запись #1: «Термозащита держит удар. Робот-напарник открыл доступ к генераторному отсеку»."
			cfg.walls = [
				Rect2(0.27, 0.0, 0.055, 0.60),
				Rect2(0.51, 0.40, 0.055, 0.60),
				Rect2(0.75, 0.0, 0.055, 0.60),
			]
			cfg.hold_zone = Rect2(0.36, 0.10, 0.14, 0.25)
			cfg.hold_target_ms = 1200
			cfg.horizontal_speed = 0.085
			cfg.vertical_speed = 0.48
			cfg.count_both_as_unwanted = true
	if step != 0 and cfg.level_id != "tutorial":
		_apply_step_modifier(cfg, step)
	return cfg


static func _apply_step_modifier(cfg: LevelConfig, step: int) -> void:
	# Bounded, explainable adaptation: +/-10% horizontal speed and +/-0.04 wall opening.
	cfg.horizontal_speed = cfg.horizontal_speed * (1.0 + 0.10 * float(step))
	var adjusted: Array[Rect2] = []
	for wall in cfg.walls:
		var h := clampf(wall.size.y + 0.04 * float(step), 0.48, 0.68)
		if wall.position.y > 0.0:
			adjusted.append(Rect2(wall.position.x, 1.0 - h, wall.size.x, h))
		else:
			adjusted.append(Rect2(wall.position.x, 0.0, wall.size.x, h))
	cfg.walls = adjusted


## Evaluates whether difficulty should step up (+1), step down (-1), or stay unchanged
## between attempts. Never changes input thresholds or mid-attempt geometry.
static func evaluate_adaptation(
	current_step: int,
	clean_streak: int,
	struggle_streak: int,
	adaptation_enabled: bool = true
) -> Dictionary:
	var clamped_current := clampi(current_step, -1, 1)
	if not adaptation_enabled:
		return {
			"step": clamped_current,
			"changed": false,
			"explanation": "Адаптация темпа отключена в настройках: параметры уровня фиксированы.",
		}
	if clean_streak >= 2 and clamped_current < 1:
		var next_up := clamped_current + 1
		return {
			"step": next_up,
			"changed": true,
			"explanation": "Адаптация (+1): 2 уверенных ремонта подряд — темп маршрута немного выше, просвет уже.",
		}
	if struggle_streak >= 2 and clamped_current > -1:
		var next_down := clamped_current - 1
		return {
			"step": next_down,
			"changed": true,
			"explanation": "Адаптация (-1): серия сложных попыток — темп маршрута спокойнее, проход шире.",
		}
	return {
		"step": clamped_current,
		"changed": false,
		"explanation": "Параметры маршрута без изменений (уровень адаптации: %d)." % clamped_current,
	}
