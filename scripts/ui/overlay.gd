class_name Overlay
extends Control

## Basis fuer alle modalen Karten (Pause, Levelintro, Ergebnis).
## Dimmt das Spiel, legt eine zentrierte Karte dar und blendet sich weich ein.

signal dismissed()

var dim_color: Color = Color(0.015, 0.02, 0.04, 0.76)
var card_background: Color = Palette.GLASS
var padding: int = 32

var _dim: ColorRect
var _card: PanelContainer
var _box: VBoxContainer
var _enter_offset: float = 26.0
var _registered: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = dim_color
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_card = PanelContainer.new()
	# Kein Ankersatz: die Position wird in _center_card() gesetzt, nachdem die
	# Karte ihre echte Groesse kennt. Mit PRESET_CENTER klebt die Karte nach
	# einem reset_size() an der Mitte und laeuft ueber den Bildrand hinaus.
	_card.position = Vector2.ZERO
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", UI.card(card_background, Palette.RADIUS_LG))
	add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", padding)
	margin.add_theme_constant_override("margin_right", padding)
	margin.add_theme_constant_override("margin_top", padding)
	margin.add_theme_constant_override("margin_bottom", padding)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_box)


func box() -> VBoxContainer:
	return _box


func card() -> PanelContainer:
	return _card


## Karte einblenden.
##
## Waehrend der Einblendung liegt ein unsichtbarer Schild ueber der Karte:
## Knöpfe, die noch aufploppen, reagieren nicht. Das ist nicht nur sauberer
## fuer die Spielerin - es faengt auch das emulierte Mausereignis ab, das
## Godot zusaetzlich zu einem Touch erzeugt. Ohne diesen Schild wuerde der
## Tipp, der den letzten Schatten trifft, sofort den gerade erschienenen
## Knopf ausloesen.
func show_overlay(animate: bool = true) -> void:
	visible = true
	var shield := Control.new()
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.modulate.a = 0.0
	add_child(shield)
	shield.move_to_front()
	_log_registered_buttons()

	if not animate:
		_center_card()
		modulate.a = 1.0
		_release_shield(shield)
		return
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.94, 0.94)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.20)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.finished.connect(_release_shield.bind(shield))


func _release_shield(shield: Control) -> void:
	if is_instance_valid(shield):
		shield.queue_free()


## Knopf anmelden: Logcat-Zeile beim Tipp plus Pixelposition fuer den Test.
func register_button(id: String, button: Button) -> Button:
	button.pressed.connect(func() -> void: Log.line("BTN id=%s pressed=1" % id))
	_registered.append([id, button])
	return button


## Buttonpositionen erst melden, wenn das Layout wirklich steht. Die Karte
## wird nach `build()` noch einmal neu vermessen und der VBox sortiert die
## Kinder erst im Folgetakt - eine Meldung nach einem einzigen Frame kann
## deshalb eine Position liefern, die ein Tipp nicht mehr trifft.
func _log_registered_buttons() -> void:
	for _i in 4:
		await get_tree().process_frame
	_card.reset_size()
	for _i in 4:
		await get_tree().process_frame
	_report_buttons()
	# Zweite Meldung, nachdem die Einblendung der Karte abgeschlossen ist:
	# waehrend des Tweens liegen die Globalrechtecke noch skaliert vor, und ein
	# Tipp auf eine zu frueh gemeldete Position verfehlt den Knopf.
	await get_tree().create_timer(0.5).timeout
	for _i in 4:
		await get_tree().process_frame
	_report_buttons()


func _report_buttons() -> void:
	for entry in _registered:
		var button: Button = entry[1]
		if is_instance_valid(button):
			Log.button(String(entry[0]), button)


func hide_overlay(animate: bool = true) -> void:
	if not animate:
		visible = false
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(func() -> void: visible = false)


## Karte auf die Bildschirmbreite begrenzen - aber die Hoehe dem Inhalt
## ueberlassen. Eine geklemmte Hoehe zwingt den VBox, seine Kinder danach
## neu zu verteilen: die Knoepfe springen dann sichtbar nach unten, und eine
## zuvor gemeldete Position trifft sie nicht mehr.
func fit_card(max_width_ratio: float = 0.88) -> void:
	await get_tree().process_frame
	var available := Vector2(size.x * max_width_ratio, size.y * 0.88)
	var content := _box.get_combined_minimum_size()
	_card.custom_minimum_size = Vector2(minf(available.x, maxf(300.0, content.x)), 0.0)
	for _i in 2:
		await get_tree().process_frame
	_card.reset_size()
	_center_card()


## Karte exakt in der Mitte des Overlays ablegen.
##
## `reset_size()` setzt die Groesse direkt und laesst die Anker-Position
## unangetastet - die Karte klebt dann mit der linken Oberkante am
## Mittelpunkt des Bildes und ragt rechts hinaus. Der Mittelpunkt wird
## deshalb hier von Hand gesetzt.
func _center_card() -> void:
	_card.position = ((size - _card.size) * 0.5).round()
