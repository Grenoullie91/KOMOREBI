class_name TitleScreen
extends AppScreen

## Titelbildschirm: Logo, Kontinentzahl, Bestwerte, Hauptmenue.

var _star_caption: Label
var _endless_caption: Label
var _campaign_caption: Label
var _buttons: Dictionary = {}


func _ready() -> void:
	super._ready()
	var column := page(SAFE_TOP + 8.0, SAFE_BOTTOM)

	# ---------------------------------------------------------- Kopfteil --
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)

	var eyebrow := UI.caption("TAP-TAP ARCADE")
	header.add_child(eyebrow)

	var logo := TitleText.new()
	logo.text = "KOMOREBI"
	logo.font = Fonts.DISPLAY
	logo.font_size = 74
	logo.tracking = 7.0
	logo.color = Palette.GOLD
	logo.color_end = Palette.AMBER_DEEP
	logo.glow = Palette.AMBER
	logo.custom_minimum_size = Vector2(0, 104)
	header.add_child(logo)

	header.add_child(UI.wrapped("Zerstöre die Schatten, bevor das Licht erlischt.",
		560.0, Palette.FONT_BODY - 2, Palette.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	var showcase_holder := Control.new()
	showcase_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	showcase_holder.custom_minimum_size = Vector2(0, 240)
	showcase_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	showcase_holder.clip_contents = true
	column.add_child(showcase_holder)

	var showcase := TitleShowcase.new()
	showcase.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	showcase_holder.add_child(showcase)

	# -------------------------------------------------- Fortschrittszeile --
	var progress_card := UI.card_panel(20, Color(0.04, 0.06, 0.11, 0.55))
	var progress_col := VBoxContainer.new()
	progress_col.add_theme_constant_override("separation", 6)
	progress_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_card.add_child(progress_col)

	_star_caption = UI.caption("")
	_star_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	progress_col.add_child(_star_caption)

	_campaign_caption = UI.label("", Palette.FONT_SMALL, Palette.TEXT_FAINT, HORIZONTAL_ALIGNMENT_LEFT)
	progress_col.add_child(_campaign_caption)

	_endless_caption = UI.label("", Palette.FONT_SMALL, Palette.TEXT_FAINT, HORIZONTAL_ALIGNMENT_LEFT)
	progress_col.add_child(_endless_caption)

	column.add_child(progress_card)

	# ------------------------------------------------------- Hauptmenue --
	var play := UI.button("KAMPAGNE", "primary", 104)
	play.custom_minimum_size = Vector2(0, 104)
	register_button("campaign", play)
	play.pressed.connect(func() -> void: navigate.emit("levels", 0))
	column.add_child(play)
	_buttons["campaign"] = play

	var endless := UI.button("ENDLOS", "ghost", 84)
	endless.custom_minimum_size = Vector2(0, 84)
	register_button("endless", endless)
	endless.pressed.connect(func() -> void: navigate.emit("endless", 0))
	column.add_child(endless)
	_buttons["endless"] = endless

	var howto := UI.button("SO WIRD GESPIELT", "quiet", 56)
	register_button("howto", howto)
	howto.pressed.connect(func() -> void: navigate.emit("howto", 0))
	column.add_child(howto)

	var licenses := UI.button("LIZENZEN & CREDITS", "quiet", 48)
	register_button("licenses", licenses)
	licenses.pressed.connect(func() -> void: navigate.emit("licenses", 0))
	column.add_child(licenses)
	_buttons["licenses"] = licenses

	column.add_child(UI.caption("v1.0  -  ein kleines Premium-Spiel"))
	_buttons["howto"] = howto


func on_enter(_arg: int = 0) -> void:
	var save: SaveData = AppRoot.save
	_star_caption.text = "KAMPAGNE  %d / %d STERNE" % [save.total_stars(), Levels.count() * SaveData.MAX_STARS]

	var next_level: int = mini(save.unlocked, Levels.count())
	var level: Dictionary = Levels.get_level(next_level)
	var stars: int = save.level_stars(next_level)
	var progress: String = "bisher: %d Sterne" % stars
	if stars >= SaveData.MAX_STARS:
		progress = "vollständig"
	_campaign_caption.text = "weiter: Kapitel %d  %s  -  %s" % [
		next_level, String(level["name"]), progress
	]
	_endless_caption.text = "Endlos-Bestwert: %s" % Hud._format(save.endless_best)

	Log.line("SCREEN=TITLE")
	log_buttons(_buttons)
	slide_in(self, 0.0)