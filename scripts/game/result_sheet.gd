class_name ResultSheet
extends Overlay

## Ergebnis-Karte: Sieg oder Niederlage, Sterne, Kennzahlen, Auswahl.
## Wird fuer Kampagnenlevel und Endlos-Modus verwendet.

signal primary_pressed()
signal secondary_pressed()
signal menu_pressed()

var _stars: StarsRow
var _score_label: Label
var _stats_box: VBoxContainer
var _primary: Button
var _secondary: Button


func build(
	victory: bool,
	headline: String,
	subline: String,
	score: int,
	stars_earned: int,
	stats: Array,
	primary_text: String,
	secondary_text: String,
	show_stars: bool
) -> void:
	var b := box()
	for child in b.get_children():
		child.queue_free()

	var accent: Color = Palette.AMBER if victory else Palette.CRIMSON

	b.add_child(UI.caption(subline))

	var title := UI.heading(headline, 44, Palette.TEXT)
	title.color_end = accent
	title.color = Palette.TEXT
	title.custom_minimum_size = Vector2(520, 60)
	b.add_child(title)

	if show_stars:
		b.add_child(UI.hsep(2))
		# StarsRow bestimmt Groesse und Zentrierung selbst.
		_stars = StarsRow.new()
		_stars.star_size = 62.0
		_stars.gap = 18.0
		_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_child(_stars)

	b.add_child(UI.hsep(6))

	_score_label = UI.label(_format(score), 62, Palette.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_score_label.add_theme_font_override("font", Fonts.BOLD)
	_score_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.85))
	_score_label.add_theme_constant_override("outline_size", 7)
	b.add_child(_score_label)
	b.add_child(UI.caption("PUNKTE"))

	b.add_child(UI.hsep(2))

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	_stats_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(_stats_box)
	for entry in stats:
		_stats_box.add_child(_stat_row(String(entry[0]), String(entry[1])))

	b.add_child(UI.hsep(8))

	_primary = UI.button(primary_text, "primary", 92)
	_primary.custom_minimum_size = Vector2(520, 92)
	register_button("primary", _primary)
	_primary.pressed.connect(func() -> void: primary_pressed.emit())
	b.add_child(_primary)

	if secondary_text != "":
		_secondary = UI.button(secondary_text, "ghost", 76)
		_secondary.custom_minimum_size = Vector2(520, 76)
		register_button("secondary", _secondary)
		_secondary.pressed.connect(func() -> void: secondary_pressed.emit())
		b.add_child(_secondary)

	var menu := UI.button("ZUR UEBERSICHT", "quiet", 52)
	register_button("menu", menu)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	b.add_child(menu)

	fit_card()

	if show_stars and _stars:
		_stars.set_result(stars_earned, true)


func _stat_row(caption_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := UI.label(caption_text, Palette.FONT_SMALL, Palette.TEXT_DIM)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := UI.label(value_text, Palette.FONT_SMALL, Palette.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_theme_font_override("font", Fonts.SEMIBOLD)
	row.add_child(right)
	return row


static func _format(value: int) -> String:
	return Hud._format(value)