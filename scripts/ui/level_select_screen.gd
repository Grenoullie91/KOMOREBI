class_name LevelSelectScreen
extends AppScreen

## Levelauswahl: waagerechte Karten mit Nummer, Name, Sternen und Bestwert.
## Gesperrte Kapitel bleiben sichtbar - man soll sehen, worauf man hinarbeitet.

var _cards: Array = []
var _buttons: Dictionary = {}
var _stars_label: Label


func _ready() -> void:
	super._ready()
	var column := page(SAFE_TOP, SAFE_BOTTOM)

	column.add_child(UI.caption("KAMPAGNE"))

	var heading := UI.heading("LICHTUNGEN", 40, Palette.TEXT)
	heading.custom_minimum_size = Vector2(0, 54)
	column.add_child(heading)

	_stars_label = UI.label("", Palette.FONT_SMALL, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	column.add_child(_stars_label)

	column.add_child(UI.hsep(2))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)

	for level in Levels.list():
		list.add_child(_make_card(level))

	var back := UI.button("ZUR UEBERSICHT", "quiet", 56)
	register_button("back", back)
	back.pressed.connect(func() -> void: navigate.emit("title", 0))
	column.add_child(back)
	_buttons["back"] = back


func _make_card(level: Dictionary) -> Control:
	var id: int = int(level["id"])
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 116)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	UI._attach_press_punch(card)
	card.pressed.connect(func() -> void:
		if AppRoot.save.is_unlocked(id):
			navigate.emit("level", id)
	)
	register_button("lv%d" % id, card)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 116)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22.0
	row.offset_right = -22.0
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)

	var number := UI.strong("%02d" % id, 34, Palette.TEXT)
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.custom_minimum_size = Vector2(56, 0)
	row.add_child(number)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	var name_label := UI.strong(String(level["name"]), Palette.FONT_BODY, Palette.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_col.add_child(name_label)

	var goal: String = "ZIEL: %d Schatten" % int(level["quota"]) if not level.has("boss") else "ZIEL: Boss"
	var info := UI.caption("%s  -  %s" % [goal, String(level["sub"])])
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text_col.add_child(info)

	var stars := StarsRow.new()
	stars.star_size = 26.0
	stars.gap = 10.0
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stars.size_flags_horizontal = Control.SIZE_SHRINK_END
	stars.custom_minimum_size = Vector2(104, 34)
	stars.set_result(AppRoot.save.level_stars(id), false)
	row.add_child(stars)

	_cards.append({"id": id, "card": card, "stars": stars, "number": number, "name": name_label, "info": info})
	return holder


func on_enter(_arg: int = 0) -> void:
	var save: SaveData = AppRoot.save
	_stars_label.text = "%d von %d Sternen gesammelt" % [save.total_stars(), Levels.count() * SaveData.MAX_STARS]

	for entry in _cards:
		var id: int = entry["id"]
		var unlocked: bool = save.is_unlocked(id)
		var card: Button = entry["card"]
		var stars: StarsRow = entry["stars"]
		var number: Label = entry["number"]
		var name_label: Label = entry["name"]
		var info: Label = entry["info"]
		var level: Dictionary = Levels.get_level(id)

		stars.set_result(save.level_stars(id), false)

		if unlocked:
			var border: Color = Palette.MINT if save.level_stars(id) > 0 else Color(1, 1, 1, 0.10)
			card.add_theme_stylebox_override("normal", UI.flat(Color(0.05, 0.08, 0.13, 0.92), Palette.RADIUS, 2, border, 0, 0))
			card.add_theme_stylebox_override("hover", UI.flat(Color(0.08, 0.13, 0.19, 0.96), Palette.RADIUS, 2, Palette.MINT, 0, 0))
			card.add_theme_stylebox_override("pressed", UI.flat(Color(0.03, 0.06, 0.09, 0.96), Palette.RADIUS, 2, Palette.MINT, 0, 0))
			number.add_theme_color_override("font_color", Palette.TEXT)
			name_label.add_theme_color_override("font_color", Palette.TEXT)
			info.text = "%s  -  %s  -  Best %s" % [
				"Boss" if level.has("boss") else "%d Schatten" % int(level["quota"]),
				String(level["sub"]),
				Hud._format(save.level_best(id)),
			]
		else:
			card.add_theme_stylebox_override("normal", UI.flat(Color(0.04, 0.05, 0.08, 0.7), Palette.RADIUS, 2, Color(1, 1, 1, 0.05), 0, 0))
			card.add_theme_stylebox_override("hover", UI.flat(Color(0.05, 0.06, 0.09, 0.75), Palette.RADIUS, 2, Color(1, 1, 1, 0.07), 0, 0))
			card.add_theme_stylebox_override("pressed", UI.flat(Color(0.05, 0.06, 0.09, 0.75), Palette.RADIUS, 2, Color(1, 1, 1, 0.07), 0, 0))
			number.add_theme_color_override("font_color", Palette.TEXT_FAINT)
			name_label.add_theme_color_override("font_color", Palette.TEXT_FAINT)
			info.text = "gesperrt  -  Kapitel %d abschließen" % (id - 1)

	Log.line("SCREEN=LEVELS")
	for entry in _cards:
		_buttons["lv%d" % int(entry["id"])] = entry["card"]
	log_buttons(_buttons)
	slide_in(self)