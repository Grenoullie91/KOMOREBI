class_name HowToScreen
extends AppScreen

## Kurzanleitung: Gegnertypen, Regeln und Gaben als eine Karte.

## Textbreite der Karten. Bestimmt, wo Labels umbrechen.
const CARD_TEXT_WIDTH := 552.0

var _list: VBoxContainer
var _buttons: Dictionary = {}


func _ready() -> void:
	super._ready()
	var column := page(SAFE_TOP, SAFE_BOTTOM)

	column.add_child(UI.caption("KURZANLEITUNG"))

	var heading := UI.heading("SO WIRD GESPIELT", 36, Palette.TEXT)
	heading.custom_minimum_size = Vector2(0, 50)
	column.add_child(heading)

	column.add_child(UI.hsep(2))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)

	_list.add_child(_rule("ZIEL", "Tippe jeden Schatten, bevor die Zeit abläuft. Erreiche die Soll-Zahl, um das Kapitel abzuschließen."))
	_list.add_child(_entry("SCHATTEN", Palette.SHADE_RIM, "Der Standard. Ein Tipp, und er zerfällt."))
	_list.add_child(_entry("FUNKENGLEITER", Palette.WISP_RIM, "Schnell und zickig - der Moment zählt."))
	_list.add_child(_entry("SPLITTER", Palette.SPLIT_RIM, "Zerfällt beim Tod in drei Scherben. Jede zählt."))
	_list.add_child(_entry("PANZERSCHATTEN", Palette.ARMOR_RIM, "Drei Treffer. Beim Tod sprengt er alle Nachbarn mit - reine Kettenreaktion."))
	_list.add_child(_entry("GROSSER SCHATTEN", Palette.BOSS_RIM, "Kapitel-Boss. Jede erlöschte Kerze schwächt ihn."))
	_list.add_child(UI.spacer(4))
	_list.add_child(_rule("KOMBO", "Jeder Treffer ohne Fehlgriff erhöht die Kombo. Ab vier Treffern steigt der Multiplikator bis x9. Ein Fehlgriff setzt sie zurück."))
	_list.add_child(_rule("KRITISCH", "Mit wachsender Kombo werden Treffer häufiger kritisch: doppelte Punkte, weißer Blitz, kurze Zeitlupe."))
	_list.add_child(_mehrfach())
	_list.add_child(_entry("SONNENSTICH", Palette.AMBER, "Fünf Sekunden doppelte Punkte.", "GABE"))
	_list.add_child(_entry("REIF", Palette.CYAN, "Alle Gegner fliegen deutlich langsamer.", "GABE"))
	_list.add_child(_entry("KETTE", Palette.MINT, "Die nächsten sechs Töte zünden durch und reißen Nachbarn mit.", "GABE"))
	_list.add_child(_rule("STERNE", "Jedes Kapitel vergibt bis zu drei Sterne: je höher die Punktzahl, desto mehr Licht."))

	var back := UI.button("VERSTANDEN", "primary", 88)
	back.custom_minimum_size = Vector2(0, 88)
	register_button("back", back)
	back.pressed.connect(func() -> void: navigate.emit("title", 0))
	column.add_child(back)
	_buttons["back"] = back


func _mehrfach() -> Control:
	return _rule("MEHRFACH", "Zerstörst du mehrere Schatten binnen einer halben Sekunde, gibt es Bonus und ein sichtbares Zeichen.")


func _rule(title_text: String, body: String) -> Control:
	var panel := UI.card_panel(20, Color(0.04, 0.06, 0.11, 0.6))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var title := UI.strong(title_text, Palette.FONT_BODY, Palette.AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(title)

	col.add_child(UI.wrapped(body, CARD_TEXT_WIDTH))
	return panel


func _entry(title_text: String, color: Color, body: String, tag: String = "") -> Control:
	var panel := UI.card_panel(20, Color(0.04, 0.06, 0.11, 0.6))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", UI.flat(color, 7, 0, Color(0, 0, 0, 0), 0, 0))
	row.add_child(dot)

	var title := UI.strong(title_text, Palette.FONT_BODY, Palette.TEXT)
	row.add_child(title)

	if tag != "":
		var push := UI.spacer()
		push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(push)
		var tag_label := UI.caption(tag)
		tag_label.add_theme_color_override("font_color", color)
		row.add_child(tag_label)

	col.add_child(row)

	col.add_child(UI.wrapped(body, CARD_TEXT_WIDTH))
	return panel


func on_enter(_arg: int = 0) -> void:
	AppRoot.save.howto_seen = true
	AppRoot.save.save_to_disk()
	Log.line("SCREEN=HOWTO")
	log_buttons(_buttons)
	slide_in(self)