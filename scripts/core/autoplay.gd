class_name Autoplay
extends Node

## Entwicklungshilfe: spielt das Spiel ohne Bildschirmeingabe durch.
##
## Wird ausschliesslich aktiviert, wenn das Spiel mit `-- --autoplay` gestartet
## wird. Im normalen Betrieb ist der Knoten inaktiv. Er existiert, damit sich
## Logik, Persistenz und Levelwechsel headless pruefen lassen, ohne jedes Mal
## ein APK bauen und den Emulator bedienen zu muessen.

const MAX_TAPS := 400
const MAX_SCREENS := 6

var app: Node
var max_taps: int = MAX_TAPS

var _phase: String = "wait"
var _timer: float = 0.5
var _taps: int = 0
var _screens: int = 0
var _pause_done: bool = false
var _result_seen: bool = false
var _endless_seen: bool = false
var _elapsed: float = 0.0
var max_seconds: float = 30.0

## Startpunkt: Zahl = Kapitel, "endless" = Endlos-Modus, 0 = Titelbildschirm.
var start: int = 0
var start_endless: bool = false
var no_taps: bool = false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autoplay="):
			var value: String = arg.split("=")[1]
			if value == "endless":
				start_endless = true
			else:
				start = int(value)
		elif arg == "--autoplay":
			start = 0
		elif arg == "--notap":
			no_taps = true
		elif arg.begins_with("--speed="):
			Engine.time_scale = maxf(0.1, float(arg.split("=")[1]))
		elif arg.begins_with("--maxsec="):
			max_seconds = maxf(1.0, float(arg.split("=")[1]))
	Log.line("AUTOPLAY on start=%s" % ("endless" if start_endless else str(start)))


func _process(delta: float) -> void:
	if app == null:
		return
	_elapsed += delta
	if _elapsed > max_seconds:
		Log.line("AUTOPLAY done taps=%d screens=%d" % [_taps, _screens])
		app.get_tree().quit()
		return
	_timer -= delta
	if _timer > 0.0:
		return

	var screen: AppScreen = app.get("_current")
	if screen == null:
		_timer = 0.2
		return

	if _screens == 0 and _phase == "wait" and screen is TitleScreen:
		_screens = 1
		_timer = 0.5
		if start_endless:
			screen.navigate.emit("endless", 0)
		elif start > 1:
			screen.navigate.emit("level", start)
		else:
			screen.navigate.emit("levels", 0)
		return

	if screen is TitleScreen:
		_phase = "title"
	elif screen is LevelSelectScreen:
		_phase = "levels"
	elif screen is GameScreen:
		_phase = "game"
	else:
		_phase = "other"

	match _phase:
		"title":
			if _screens > 0:
				_timer = 1.0
				return
			_screens += 1
			_timer = 0.7
			_phase = "campaign"
			screen.navigate.emit("levels", 0)
		"levels":
			_screens += 1
			_timer = 0.7
			_phase = "lv1"
			screen.navigate.emit("level", 1)
		"game":
			_tick_game(screen as GameScreen)
		_:
			_timer = 0.4


func _tick_game(game: GameScreen) -> void:
	var arena: Arena = game.get("_arena")
	var result: ResultSheet = game.get("_result")
	var pause: PauseSheet = game.get("_pause")
	var intro: LevelIntroSheet = game.get("_intro")

	# Kapitel-Intro bestaetigen.
	if intro != null and intro.visible:
		_timer = 1.0
		intro.begin_pressed.emit()
		return

	# Ergebnis-Karte: einmal bestaetigen und weiter zum naechsten Kapitel.
	if result != null and result.visible:
		if _result_seen:
			_timer = 3.0
			return
		_result_seen = true
		_timer = 1.6
		if not game.endless:
			var next_id: int = Levels.next_id(int(game.level.get("id", 1)))
			if next_id > 0:
				game.request_screen.emit("level", next_id)
				return
			if not _endless_seen:
				_endless_seen = true
				game.request_screen.emit("endless", 0)
				return
			game.request_screen.emit("title", 0)
		else:
			game.request_screen.emit("title", 0)
		return

	# Pause einmal ausloesen, damit der Pause-Zustand mitgetestet wird.
	if not _pause_done and _taps >= 4:
		_pause_done = true
		_timer = 0.9
		game.request_pause()
		return
	if pause != null and pause.visible:
		_timer = 0.9
		pause.resume_pressed.emit()
		return

	if arena == null or not arena.running:
		_timer = 0.3
		return

	if no_taps:
		_timer = 0.5
		return

	var enemy: Enemy = arena.nearest_enemy(arena.size * 0.5)
	if enemy == null:
		_timer = 0.12
		return
	_taps += 1
	if _taps > max_taps:
		_timer = 2.0
		return
	if _taps % 17 == 0:
		# Gelegentlicher Fehlgriff prueft auch den Kombo-Reset.
		game.handle_tap(arena.global_position + Vector2(6, 6))
	else:
		game.handle_tap(arena.global_position + enemy.position)
	_timer = 0.20