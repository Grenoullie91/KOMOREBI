class_name AppRoot
extends Control

## Wurzel des Spiels: haelt Hintergrund, Seitenwechsel, Persistenz und Audio
## und leitet Tipps an die aktive Seite weiter.

static var save: SaveData
static var sfx: Sfx
## Wurzelknoten als statischer Zugriff, damit Unterseiten (Spiel, Karten)
## die globale Eingabesperre aufrufen koennen.
static var root: AppRoot

const FADE_TIME := 0.16

var backdrop: Backdrop
var _host: Control
var _fade: ColorRect
var _current: AppScreen
var _switching: bool = false


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	root = self
	save = SaveData.new()
	save.load_from_disk()

	sfx = Sfx.new()
	sfx.name = "Sfx"
	sfx.enabled = save.sfx
	add_child(sfx)

	backdrop = Backdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_host = Control.new()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)

	_fade = ColorRect.new()
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.01, 0.015, 0.03, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	Log.line("BOOT name=KOMOREBI version=%s renderer=%s screen=%s" % [
		ProjectSettings.get_setting("application/config/version", "1.0.0"),
		RenderingServer.get_video_adapter_name(),
		str(Vector2i(DisplayServer.window_get_size())),
	])

	# Die Autoplay-Hilfe ist reine Entwicklung: sie wird weder im Release
	# ausgefuehrt noch mitexportiert (siehe exclude_filter im Preset). Das
	# Skript wird deshalb dynamisch geladen - ein harter Verweis wuerde im
	# Release-Build einen Parse-Fehler ausloesen.
	if OS.is_debug_build():
		_start_autoplay()

	await get_tree().process_frame
	await goto_screen("title", 0)
	_log_fade()


## Haengt die Entwicklungshilfe an, wenn sie angefordert wurde.
func _start_autoplay() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--autoplay"):
			continue
		# Ohne Typannotation: `Autoplay` ist im Release-Build nicht
		# vorhanden, eine Annotation wuerde dort den Parse-Fehler bringen.
		var autoplay: Node = load("res://scripts/core/autoplay.gd").new()
		autoplay.set("app", self)
		add_child(autoplay)
		return


func _log_fade() -> void:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_fade, "color", Color(0.01, 0.015, 0.03, 0.0), 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- Navigation -

func goto_screen(target: String, arg: int = 0) -> void:
	if _switching:
		return
	_switching = true

	await _fade_to(1.0)
	if is_instance_valid(_current):
		_current.on_exit()
		_current.queue_free()
		_current = null

	_current = _create_screen(target, arg)
	_apply_mood(target, arg)
	_host.add_child(_current)
	guard_input(0.5)
	_current.navigate.connect(goto_screen)
	_current.on_enter(arg)
	_current.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_current, "modulate:a", 1.0, 0.20)
	_log_fade()
	_switching = false


func _fade_to(alpha: float) -> void:
	if _fade.color.a >= alpha:
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_fade, "color", Color(0.01, 0.015, 0.03, alpha), FADE_TIME)
	await tw.finished


func _create_screen(target: String, arg: int) -> AppScreen:
	match target:
		"levels":
			var screen := LevelSelectScreen.new()
			return screen
		"howto":
			return HowToScreen.new()
		"level":
			var game := GameScreen.new()
			game.request_screen.connect(goto_screen)
			game.level = Levels.get_level(maxi(1, arg))
			return game
		"endless":
			var endless := GameScreen.new()
			endless.request_screen.connect(goto_screen)
			endless.level = Levels.endless_level()
			endless.endless = true
			return endless
		_:
			return TitleScreen.new()


## Kurze Eingabesperre nach einem Bildschirmwechsel.
##
## Godot erzeugt aus einem Touch zusaetzlich ein emuliertes Maus-Ereignis. Der
## Tipp, der den letzten Schatten vernichtet, wuerde dadurch im selben Moment
## auch den gerade erschienenen Knopf ausloesen - ein ungewollter Doppel-
## ausloeser, der beim Spieler wie ein Geisterfinger wirkt. Der Schild liegt
## unsichtbar ueber der Seite und faengt genau diese Nachlaufereignisse ab.
func guard_input(seconds: float = 0.3) -> void:
	if not is_instance_valid(_current):
		return
	var shield := Control.new()
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	shield.modulate.a = 0.0
	_current.add_child(shield)
	shield.move_to_front()
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(seconds)
	tw.tween_callback(_release_shield.bind(shield))


func _release_shield(shield: Control) -> void:
	if is_instance_valid(shield):
		shield.queue_free()


func _apply_mood(target: String, arg: int) -> void:
	var mood: float = 0.18
	match target:
		"level":
			mood = float(Levels.get_level(maxi(1, arg)).get("mood", 0.2))
		"endless":
			mood = 0.5
	backdrop.set_mood(mood)


# --------------------------------------------------------------------- Input -

## Godot erzeugt aus jedem Touch zusaetzlich ein emuliertes Maus-Ereignis
## (`emulate_mouse_from_touch`). Ohne Entprellung wuerde derselbe Tipp zweimal
## verarbeitet: einmal als Treffer, direkt danach als Fehlgriff - und damit
## jede Kombo sofort zuruecksetzen. Die Reihenfolge der beiden Ereignisse ist
## nicht garantiert, deshalb filtert der Test nicht nach Typ, sondern nach
## Ort und Zeit: zwei Tipp-Ereignisse binnen 140 ms an derselben Stelle sind
## mit hoher Wahrscheinlichkeit derselbe Tipp.
const DOUBLE_TAP_MS := 140
const DOUBLE_TAP_DISTANCE := 14.0

var _last_tap_point: Vector2 = Vector2.INF
var _last_tap_ms: int = -100000


func _unhandled_input(event: InputEvent) -> void:
	# Waehrend eines Seitenwechsels wird der Tipp nicht blockiert: die Seiten
	# selbst entscheiden, ob sie ihn annehmen. Ein Sperren wuerde Eingaben
	# verschlucken, die kurz nach dem Wechsel fallen.
	var point: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		point = touch.position
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		point = click.position
	else:
		return

	var now: int = Time.get_ticks_msec()
	if now - _last_tap_ms < DOUBLE_TAP_MS and point.distance_to(_last_tap_point) < DOUBLE_TAP_DISTANCE:
		return
	_last_tap_ms = now
	_last_tap_point = point

	if is_instance_valid(_current):
		_current.handle_tap(point)


func _process(_delta: float) -> void:
	pass