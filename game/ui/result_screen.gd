extends "res://game/ui/ui_base.gd"

var metrics: GridContainer
var summary_meta_label: Label


func _ready() -> void:
	super._ready()
	_heading("АРХИВ / СВОДКА", "Смена завершена", "Демонстрационные данные · пример SessionSummary из контракта.")
	var summary: Dictionary = runtime.last_summary.duplicate(true)
	if summary.is_empty():
		summary = runtime.EXAMPLE_SUMMARY.duplicate(true)
		summary["level_id"] = runtime.level_id
	summary_meta_label = page_content.get_node_or_null("SummaryMetaLabel") as Label
	if summary_meta_label == null:
		summary_meta_label = _label("УРОВЕНЬ %s · ИСТОЧНИК %s" % [summary.level_id, summary.source.to_upper()], "EyebrowLabel", "SummaryMetaLabel")
		page_content.add_child(summary_meta_label)
	else:
		summary_meta_label.text = "УРОВЕНЬ %s · ИСТОЧНИК %s" % [summary.level_id, summary.source.to_upper()]
	if page_content.get_node_or_null("SummaryDisclaimerLabel") == null:
		page_content.add_child(_label("Это пример структуры данных, а не запись сыгранного уровня.", "SubtleLabel", "SummaryDisclaimerLabel"))
	var results := _section(page_content, "СВОДКА", "", "SummarySection")
	metrics = results.get_node_or_null("MetricsGrid") as GridContainer
	if metrics == null:
		metrics = GridContainer.new()
		metrics.name = "MetricsGrid"
		metrics.columns = 2 if get_viewport_rect().size.x >= 640.0 else 1
		metrics.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		metrics.add_theme_constant_override("h_separation", DesignTheme.SPACE_300)
		metrics.add_theme_constant_override("v_separation", DesignTheme.SPACE_100)
		results.add_child(metrics)
	_set_or_add_metric(metrics, "ActiveTimeMetric", "Активное время", _format_duration(summary.active_ms))
	_set_or_add_metric(metrics, "SuccessRateMetric", "Успешность", _ratio(summary.successes, summary.attempts), "SuccessStateLabel")
	_set_or_add_metric(metrics, "AttemptsMetric", "Попытки · успехи · промахи", "%d · %d · %d" % [summary.attempts, summary.successes, summary.attempts - summary.successes])
	_set_or_add_metric(metrics, "BothSignalMetric", "Встречный сигнал", _ratio(summary.unwanted_both_ms, summary.scored_window_ms), "WarningStateLabel")
	_set_or_add_metric(metrics, "ReactionMetric", "Медиана реакции", _format_reaction(summary.median_reaction_ms))
	_set_or_add_metric(metrics, "HoldTargetMetric", "Удержание в цели", _ratio(summary.hold_in_target_ms, summary.hold_target_ms))
	var actions := page_content.get_node_or_null("ActionsRow") as HBoxContainer
	if actions == null:
		actions = HBoxContainer.new()
		actions.name = "ActionsRow"
		actions.add_theme_constant_override("separation", DesignTheme.SPACE_100)
		page_content.add_child(actions)
	_button(actions, "В меню", _exit, false, "MenuButton")
	_button(actions, "Повторить", _retry, true, "RetryButton")


func _on_viewport_resized(viewport_size: Vector2) -> void:
	if metrics != null:
		metrics.columns = 2 if viewport_size.x >= 640.0 else 1


func _set_or_add_metric(parent: Container, metric_name: String, title: String, value: String, value_role: String = "MetricLabel") -> void:
	var column := parent.get_node_or_null(metric_name) as VBoxContainer
	if column == null:
		column = VBoxContainer.new()
		column.name = metric_name
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", DesignTheme.SPACE_050)
		parent.add_child(column)
		column.add_child(_label(title, "SubtleLabel", "MetricTitle"))
		column.add_child(_label(value, value_role, "MetricValue"))
	else:
		var val_lbl := column.get_node_or_null("MetricValue") as Label
		if val_lbl != null:
			val_lbl.text = value
			val_lbl.theme_type_variation = value_role


func _ratio(numerator: int, denominator: int) -> String:
	if denominator <= 0:
		return "—"
	return "%.0f%% (%d / %d)" % [float(numerator) * 100.0 / float(denominator), numerator, denominator]


func _format_duration(milliseconds: int) -> String:
	return "%d:%02d" % [milliseconds / 60000, (milliseconds / 1000) % 60]


func _format_reaction(milliseconds: Variant) -> String:
	if milliseconds == null:
		return "нет данных"
	return "%d мс" % int(milliseconds)


func _retry() -> void:
	runtime.retry()
	_go("res://game/ui/game_screen.tscn")


func _exit() -> void:
	runtime.exit()
	_go("res://game/ui/start_screen.tscn")
