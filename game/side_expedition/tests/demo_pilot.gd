extends RefCounted
## Deterministic controller for tests and the recorded, real-command playthrough.
static func channels(model, strength: float = 1.0, exposed: bool = false, find_cache: bool = false, quick_return: bool = false) -> Vector2:
	if model.awaiting_neutral: return Vector2.ZERO
	if model.stage == "choice":
		var choose_a: bool = quick_return if model.first_delivery_done else not exposed
		return Vector2(strength, 0) if choose_a else Vector2(0, strength)
	if model.stage == "adapter":
		return Vector2(strength, 0) if model.ADAPTER_SEQUENCE[model.adapter_step] == &"OPEN" else Vector2(0, strength)
	if model.stage in ["salvage", "scout_salvage"]:
		if model.clamp.needs_neutral() or (model.clamp.pulse_seconds >= 0.25 and not model.clamp.neutral_seen): return Vector2.ZERO
		return Vector2(strength, 0) if model.cursor > model.target_value() else Vector2(0, strength)
	if model.stage == "power":
		if model.power.needs_neutral(): return Vector2.ZERO
		return Vector2(strength, 0) if model.power.expected_direction() == &"OPEN" else Vector2(0, strength)
	var shelter: int = model.current_shelter()
	if model.stage in ["to_scout", "return", "homebound"] and shelter >= 0:
		if model.route_choice == "exposed" and model.weather.phase != "calm": return Vector2(strength, 0)
		if find_cache and shelter == 2 and (not model.optional_note_found or (model.rare_requested and not model.rare_collected)): return Vector2(strength, 0)
	var forward: bool = model.stage in ["outbound", "to_scout"]
	var target_y := 0.5
	var walls: Array[Rect2] = model.active_walls()
	if forward:
		for wall in walls:
			if wall.end.x + model.HALF.x > model.player.x:
				target_y = wall.end.y + model.HALF.y + 0.035 if wall.position.y == 0.0 else wall.position.y - model.HALF.y - 0.035
				break
	else:
		for i in range(walls.size() - 1, -1, -1):
			var wall: Rect2 = walls[i]
			if wall.position.x - model.HALF.x < model.player.x:
				target_y = wall.end.y + model.HALF.y + 0.035 if wall.position.y == 0.0 else wall.position.y - model.HALF.y - 0.035
				break
	if model.route_choice == "exposed" and model.stage in ["to_scout", "return"]:
		if model.player.x > 0.55 and model.player.x < (0.655 if forward else 0.716): target_y = 0.32
	return Vector2(strength, 0) if model.player.y > target_y else Vector2(0, strength)
