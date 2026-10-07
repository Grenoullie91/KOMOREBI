class_name Hud
extends Control

## Spiel-HUD: Kapitel, Score, Fortschritt, Restzeit, Kombo-Anzeige,
## aktive Gaben und Pause-Knopf. Alles gezeichnet bzw. aus Labels, damit das
## Layout auf jedem Hochformat-Geraet gleich bleibt.

const COMBO_VISIBLE_FROM := 3

var pause_button: Button

var _chapter_label: Label
var _score_label: Label
var _best_label: Label
var _progress: StatBar
var _time: StatBar
var _combo_box: Control
var _power_row: HBoxContainer
var _power_chips: Array = []

var _combo: int = 0
var _combo_ratio: float = 0.0
var _combo_visible: float = 0.0
var _combo_punch: float = 0.0

var _time_pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	# ---------------------------------------------------------- Kopfzeile --
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	# Rechter Rand bleibt frei: dort sitzt der Pause-Knopf.
	top.offset_right = -92.0
	top.offset_top = 20.0
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	top.add_child(row)

	_chapter_label = UI.caption("")
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_chapter_label)

	var score_block := VBoxContainer.new()
	score_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_block.add_theme_constant_override("separation", -4)
	row.add_child(score_block)

	_score_label = UI.label("0", 46, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_score_label.add_theme_font_override("font", Fonts.BOLD)
	_score_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.85))
	_score_label.add_theme_constant_override("outline_size", 6)
	score_block.add_child(_score_label)

	_best_label = UI.caption("BEST 0")
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_block.add_child(_best_label)

	var bars := HBoxContainer.new()
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_theme_constant_override("separation", 18)
	top.add_child(bars)

	_progress = StatBar.new()
	_progress.caption = "SCHATTEN"
	_progress.fill_color = Palette.MINT
	_progress.custom_minimum_size = Vector2(0, 46)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(_progress)

	_time = StatBar.new()
	_time.caption = "RESTZEIT"
	_time.fill_color = Palette.AMBER
	_time.danger = true
	_time.custom_minimum_size = Vector2(0, 46)
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(_time)

	# --------------------------------------------------------- Kombo-Chip --
	_combo_box = Control.new()
	_combo_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_combo_box.offset_top = 128.0
	_combo_box.offset_bottom = 208.0
	_combo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_box.modulate.a = 0.0
	add_child(_combo_box)

	# ------------------------------------------------------------ Gaben ---
	_power_row = HBoxContainer.new()
	_power_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_power_row.offset_left = 24.0
	_power_row.offset_right = -24.0
	_power_row.offset_top = -84.0
	_power_row.offset_bottom = -24.0
	_power_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_power_row.add_theme_constant_override("separation", 10)
	_power_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_power_row)

	# ------------------------------------------------------- Pause-Knopf --
	pause_button = UI.button("", "quiet", 56)
	pause_button.text = "II"
	pause_button.add_theme_font_size_override("font_size", 22)
	pause_button.custom_minimum_size = Vector2(56, 56)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -76.0
	pause_button.offset_top = 84.0
	pause_button.offset_right = -20.0
	pause_button.offset_bottom = 140.0
	pause_button.pivot_offset = Vector2(28, 28)
	add_child(pause_button)


# ------------------------------------------------------------------ Update --

func set_chapter(text: String) -> void:
	_chapter_label.text = text


func set_score(value: int, punch: bool = true) -> void:
	_score_label.text = str(value)
	if not punch:
		return
	_score_label.pivot_offset = _score_label.size * 0.5
	_score_label.scale = Vector2(1.22, 1.22)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func set_best(value: int) -> void:
	_best_label.text = "BEST %s" % _format(value)


func set_progress(kills: int, quota: int) -> void:
	if quota > 0:
		_progress.caption = "SCHATTEN"
		_progress.value_text = "%d / %d" % [kills, quota]
		_progress.set_fill(float(kills) / float(quota))
	else:
		_progress.caption = "SCHATTEN"
		_progress.value_text = str(kills)
		_progress.set_fill(1.0)


func set_time(left: float, total: float) -> void:
	var ratio: float = clampf(left / maxf(0.001, total), 0.0, 1.0)
	_time.value_text = "%d s" % int(ceil(maxf(0.0, left)))
	_time.set_fill(ratio)
	if ratio < 0.3:
		_time_pulse += 0.06
	else:
		_time_pulse = 0.0


func set_combo(combo: int, ratio: float) -> void:
	_combo = combo
	_combo_ratio = clampf(ratio, 0.0, 1.0)
	if combo >= COMBO_VISIBLE_FROM:
		_combo_punch = 1.0
	queue_redraw()


func tick(delta: float) -> void:
	_combo_punch = maxf(0.0, _combo_punch - delta * 3.6)
	_time_pulse += delta
	var target: float = 1.0 if _combo >= COMBO_VISIBLE_FROM else 0.0
	var current: float = _combo_box.modulate.a
	if not is_equal_approx(current, target):
		_combo_box.modulate.a = move_toward(current, target, delta * 6.0)
	queue_redraw()


# --------------------------------------------------------------- Gaben-Chips

func set_powerups(active: Array) -> void:
	# active: [{kind, color, title, left, total}]
	while _power_chips.size() > active.size():
		var chip: PanelContainer = _power_chips.pop_back()
		chip.queue_free()
	for i in active.size():
		var entry: Dictionary = active[i]
		var chip: PanelContainer
		if i < _power_chips.size():
			chip = _power_chips[i]
		else:
			chip = _make_chip()
			_power_chips.append(chip)
			_power_row.add_child(chip)
			chip.modulate.a = 0.0
			var tw := create_tween()
			tw.set_ignore_time_scale(true)
			tw.tween_property(chip, "modulate:a", 1.0, 0.18)
		_update_chip(chip, entry)


func _make_chip() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.flat(Color(0.03, 0.05, 0.09, 0.82), 16, 1, Color(1, 1, 1, 0.14), 16, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(0, 46)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var dot := Panel.new()
	dot.name = "Dot"
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var title := UI.caption("")
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(title)

	var time_label := UI.caption("")
	time_label.name = "Time"
	row.add_child(time_label)
	return panel


func _update_chip(chip: PanelContainer, entry: Dictionary) -> void:
	var color: Color = entry["color"]
	var row := chip.get_child(0) as HBoxContainer
	var dot: Panel = row.get_node("Dot")
	dot.add_theme_stylebox_override("panel", UI.flat(color, 6, 0, Color(0, 0, 0, 0), 0, 0))
	var title: Label = row.get_node("Title")
	title.text = String(entry["title"])
	title.add_theme_color_override("font_color", color)
	var time_label: Label = row.get_node("Time")
	time_label.text = "%ds" % int(ceil(float(entry["left"])))


# -------------------------------------------------------------------- Zeichnen

func _draw() -> void:
	if _combo_box.modulate.a <= 0.01 or _combo <= 0:
		return

	var center := Vector2(size.x * 0.5, _combo_box.position.y + 40.0)
	var scale_punch: float = 1.0 + 0.14 * _combo_punch
	var radius: float = 26.0 * scale_punch
	var color: Color = Palette.AMBER.lerp(Palette.CRIMSON, clampf(float(_combo - 3) / 18.0, 0.0, 1.0))

	draw_circle(center, radius + 14.0, Color(color.r, color.g, color.b, 0.10))
	draw_arc(center, radius, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.18), 5.0, true)
	if _combo_ratio > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * _combo_ratio, 32, color, 5.0, true)

	var font: Font = Fonts.BOLD
	var text: String = "x%d" % maxi(1, _combo_mult())
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var ascent: float = font.get_ascent(26)
	draw_string(font, center + Vector2(-text_width * 0.5, ascent * 0.5 - 1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.TEXT)

	var label: String = "KOMBO %d" % _combo
	var label_width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(Fonts.SEMIBOLD, center + Vector2(-label_width * 0.5, radius + 26.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.TEXT_DIM.r, Palette.TEXT_DIM.g, Palette.TEXT_DIM.b, 0.9))


func _combo_mult() -> int:
	return clampi(1 + (_combo - 1) / 4, 1, 9)


static func _format(value: int) -> String:
	var text: String = str(value)
	var out: String = ""
	var count: int = 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out