class_name AppScreen
extends Control

## Basis jeder Bildschirmseite (Titel, Levelauswahl, How-to, Spiel).
## Seiten bauen ihre Oberflaeche im Code; das hennt Typografie, Abstaende und
## Farben an einer Stelle zusammen und macht Seiten mit testbaren Buttons.

signal navigate(target: String, arg: int)

const SAFE_TOP := 34.0
const SAFE_BOTTOM := 26.0
const GUTTER := 30.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Wird aufgerufen, sobald die Seite sichtbar wird.
func on_enter(_arg: int = 0) -> void:
	pass


## Wird aufgerufen, bevor die Seite verschwindet.
func on_exit() -> void:
	pass


## Nicht von UI verbrauchte Tipp-Ereignisse. Gibt true zurueck, wenn der
## Tipp verbraucht wurde.
func handle_tap(_global_point: Vector2) -> bool:
	return false


# --------------------------------------------------------------- Bausteine --

## Vertikale Seite mit sicheren Raendern.
func page(margin_top: float = SAFE_TOP, margin_bottom: float = SAFE_BOTTOM) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(GUTTER))
	margin.add_theme_constant_override("margin_right", int(GUTTER))
	margin.add_theme_constant_override("margin_top", int(margin_top))
	margin.add_theme_constant_override("margin_bottom", int(margin_bottom))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	return column


## Knopf mit Test-Haken registrieren (ID + Pixelposition im Logcat).
func register_button(id: String, button: Button) -> Button:
	button.pressed.connect(func() -> void: Log.line("BTN id=%s pressed=1" % id))
	return button


## Nach dem ersten Layout die Pixelpositionen der Knöpfe ausgeben. Mehrere
## Frames warten, damit Container ihre Kinder sortiert haben - sonst meldet
## der Test eine Position, die schon nicht mehr stimmt.
func log_buttons(buttons: Dictionary) -> void:
	for _i in 4:
		await get_tree().process_frame
	_report_buttons(buttons)
	await get_tree().create_timer(0.4).timeout
	for _i in 4:
		await get_tree().process_frame
	_report_buttons(buttons)


func _report_buttons(buttons: Dictionary) -> void:
	for key in buttons:
		var node: Node = buttons[key]
		if is_instance_valid(node) and node is Control:
			Log.button(String(key), node)


## Weiches Einblenden mit kleinem Aufwackeln. Verwendet `scale` statt
## `position`, weil Container-Kinder ihre Position selbst setzen.
func slide_in(node: Control, delay: float = 0.0) -> void:
	node.modulate.a = 0.0
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.96, 0.96)
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.30).set_delay(delay)
	tw.tween_property(node, "scale", Vector2.ONE, 0.45).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)