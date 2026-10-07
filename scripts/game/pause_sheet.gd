class_name PauseSheet
extends Overlay

## Pause-Dialog mit Fortsetzen, Neustart und zur Uebersicht.

signal resume_pressed()
signal restart_pressed()
signal menu_pressed()
signal sound_toggled(enabled: bool)

var _sound_button: Button
var _sound_enabled: bool = true


func build() -> void:
	var b := box()
	for child in b.get_children():
		child.queue_free()

	b.add_child(UI.caption("LICHT BRENNT WEITER"))

	var title := UI.heading("PAUSE", 46, Palette.TEXT)
	title.custom_minimum_size = Vector2(460, 62)
	b.add_child(title)

	b.add_child(UI.hsep(8))

	var resume := UI.button("WEITER", "primary", 96)
	resume.custom_minimum_size = Vector2(460, 96)
	register_button("resume", resume)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	b.add_child(resume)

	var restart := UI.button("NEU STARTEN", "ghost", 80)
	restart.custom_minimum_size = Vector2(460, 80)
	register_button("restart", restart)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	b.add_child(restart)

	_sound_button = UI.button("", "ghost", 68)
	_sound_button.custom_minimum_size = Vector2(460, 68)
	_sound_button.pressed.connect(_on_sound_toggled)
	_sound_button.name = "Sound"
	b.add_child(_sound_button)

	var menu := UI.button("ZUR UEBERSICHT", "quiet", 52)
	register_button("menu", menu)
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	b.add_child(menu)

	set_sound_enabled(_sound_enabled)
	fit_card()


func set_sound_enabled(value: bool) -> void:
	_sound_enabled = value
	if is_instance_valid(_sound_button):
		_sound_button.text = "KLANG: AN" if value else "KLANG: AUS"


func _on_sound_toggled() -> void:
	_sound_enabled = not _sound_enabled
	set_sound_enabled(_sound_enabled)
	sound_toggled.emit(_sound_enabled)