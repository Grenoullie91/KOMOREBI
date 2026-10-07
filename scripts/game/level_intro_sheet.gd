class_name LevelIntroSheet
extends Overlay

## Kapitel-Intro vor dem Start: Nummer, Name, Ziel, Bestwert und ein Tipp.

signal begin_pressed()
signal menu_pressed()

var _stars: StarsRow
var _tip_label: Label


func build(level: Dictionary, best: int, stars_earned: int) -> void:
	var b := box()
	for child in b.get_children():
		child.queue_free()

	b.add_child(UI.caption("KAPITEL %d" % int(level["id"])))

	var title := UI.heading(String(level["name"]), 40, Palette.TEXT)
	title.custom_minimum_size = Vector2(520, 54)
	b.add_child(title)

	var sub := UI.label(String(level["sub"]), Palette.FONT_SMALL, Palette.TEXT_FAINT, HORIZONTAL_ALIGNMENT_CENTER)
	sub.custom_minimum_size = Vector2(520, 28)
	b.add_child(sub)

	b.add_child(UI.hsep(4))

	if level.has("boss"):
		_brief(b, "ZIEL", "Streue die Schatten und lösche den Boss.")
	else:
		_brief(b, "ZIEL", "%d Schatten in %.0f Sekunden." % [
			int(level["quota"]), float(level["time"])
		])

	_brief(b, "STERNE", "%s / %s / %s Punkte" % [
		_str(int((level["stars"] as Array)[0])),
		_str(int((level["stars"] as Array)[1])),
		_str(int((level["stars"] as Array)[2])),
	])

	if best > 0:
		_brief(b, "BESTWERT", "%s Punkte  -  %d Sterne" % [_str(best), stars_earned])

	# Die Umbruchhoehe wird vorab gemessen: ein spaeter umbrechender Text
	# wuerde die Karte nachtraglich wachsen lassen und die Knoepfe verschieben -
	# fuer den Spieler ein sichtbarer Sprung, fuer den Test eine tote Position.
	_tip_label = UI.wrapped(String(level.get("tip", "")), 500.0, Palette.FONT_SMALL, Palette.AMBER,
		HORIZONTAL_ALIGNMENT_CENTER)
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(_tip_label)

	b.add_child(UI.hsep(6))

	var begin := UI.button("LICHT WECKEN", "primary", 96)
	begin.custom_minimum_size = Vector2(520, 96)
	register_button("begin", begin)
	begin.pressed.connect(func() -> void: begin_pressed.emit())
	b.add_child(begin)

	var back := UI.button("ZUR UEBERSICHT", "quiet", 52)
	register_button("levels", back)
	back.pressed.connect(func() -> void: menu_pressed.emit())
	b.add_child(back)

	fit_card()


func _brief(parent: Node, caption_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var left := UI.caption(caption_text)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.custom_minimum_size = Vector2(120, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var right := UI.label(value_text, Palette.FONT_BODY - 2, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_theme_font_override("font", Fonts.SEMIBOLD)
	row.add_child(right)


static func _str(value: int) -> String:
	return Hud._format(value)