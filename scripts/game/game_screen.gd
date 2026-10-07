class_name GameScreen
extends AppScreen

## Der Spielbildschirm: Regeln, Punkte, Kombo, Gaben, Levelabschluss.
##
## Hier - und nicht in der Arena - liegt die gesamte Spiellogik:
## Punkte, Kombinationen, Kritische Treffer, Gaben, Levelziel und
## Ergebnis. Die Arena liefert nur Ereignisse.

signal request_screen(target: String, arg: int)

enum State { INTRO, PLAYING, PAUSED, RESULT }

const SLOWMO_FACTOR := 0.35
const SLOWMO_CRIT := 0.16
const SLOWMO_KILL_CHAIN := 0.35
const FROST_FACTOR := 0.42
const SUN_DURATION := 5.0
const FROST_DURATION := 6.0
const CHAIN_USES := 6

var level: Dictionary = {}
var endless: bool = false

var _state: int = State.INTRO
var _arena: Arena
var _hud: Hud
var _frame: Panel
var _intro: LevelIntroSheet
var _pause: PauseSheet
var _result: ResultSheet

var _score: int = 0
var _kills: int = 0
var _hits: int = 0
var _misses: int = 0
var _crits: int = 0
var _multis: int = 0
var _best_combo: int = 0
var _sun_left: float = 0.0
var _frost_left: float = 0.0
var _chain_left: int = 0
var _slowmo_left: float = 0.0

var _time_left: float = 0.0
var _duration: float = 45.0
var _quota: int = 0
var _boss_pending: bool = false
var _boss_hp: int = 0
var _finished: bool = false
var _endless_score_recorded: bool = false


func _ready() -> void:
	super._ready()

	# ------------------------------------------------------------ Spielfeld --
	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", UI.flat(Color(0.02, 0.03, 0.06, 0.42), Palette.RADIUS_LG, 2, Color(1, 1, 1, 0.07), 0, 0))
	add_child(_frame)

	_arena = Arena.new()
	_arena.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arena.offset_left = 6.0
	_arena.offset_top = 6.0
	_arena.offset_right = -6.0
	_arena.offset_bottom = -6.0
	add_child(_arena)

	_hud = Hud.new()
	add_child(_hud)
	_hud.visible = false

	# -------------------------------------------------------------- Sheets --
	_intro = LevelIntroSheet.new()
	_intro.begin_pressed.connect(_on_begin)
	_intro.menu_pressed.connect(func() -> void: request_screen.emit("levels", 0))
	add_child(_intro)

	_pause = PauseSheet.new()
	_pause.resume_pressed.connect(_on_resume)
	_pause.restart_pressed.connect(_on_restart)
	_pause.menu_pressed.connect(func() -> void: request_screen.emit("title", 0))
	_pause.sound_toggled.connect(_on_sound_toggled)
	add_child(_pause)

	_result = ResultSheet.new()
	_result.primary_pressed.connect(_on_result_primary)
	_result.secondary_pressed.connect(_on_result_secondary)
	_result.menu_pressed.connect(func() -> void: request_screen.emit("title", 0))
	add_child(_result)

	# Die Pausen-Karte ist statisch und wird deshalb einmal aufgebaut.
	_pause.build()

	# ------------------------------------------------------------ Verdrahtung --
	_arena.enemy_damaged.connect(_on_enemy_damaged)
	_arena.enemy_killed.connect(_on_enemy_killed)
	_arena.power_taken.connect(_on_power_taken)
	_arena.missed.connect(_on_missed)
	_hud.pause_button.pressed.connect(request_pause)
	# Der HUD-Knopf gehoert nicht zu einer Karte und wird daher hier von Hand
	# protokolliert, damit der Test eine Reaktion auch bestaetigen kann.
	_hud.pause_button.pressed.connect(func() -> void: Log.line("BTN id=pause pressed=1"))

	set_process(true)


# ------------------------------------------------------------------ Aufbau --

## Wird nach dem Einhaengen aufgerufen - erst dann existiert die Arena.
func on_enter(arg: int = 0) -> void:
	begin(level if not level.is_empty() else Levels.get_level(maxi(1, arg)), endless)


func begin(new_level: Dictionary, as_endless: bool) -> void:
	level = new_level
	endless = as_endless
	_state = State.INTRO
	_quota = 0 if endless else int(level.get("quota", 16))
	_duration = float(level.get("time", 45.0))
	_boss_pending = level.has("boss")
	_boss_hp = int(level.get("boss_hp", 6))
	_arena.configure(level, endless)
	_arena.clear_field()
	_show_intro()


func _show_intro() -> void:
	_state = State.INTRO
	_hud.visible = false
	_hud.set_chapter(
		"ENDLOS" if endless
		else "KAPITEL %d  -  %s" % [int(level.get("id", 0)), String(level.get("name", ""))]
	)
	_hud.set_score(0, false)
	_hud.set_best(AppRoot.save.level_best(int(level.get("id", 1))) if not endless else AppRoot.save.endless_best)
	_hud.set_progress(0, _quota)
	_hud.set_time(_duration, _duration)
	_hud.set_combo(0, 0.0)

	AppRoot.root.guard_input(0.45)
	_intro.build(
		level,
		AppRoot.save.level_best(int(level.get("id", 1))),
		AppRoot.save.level_stars(int(level.get("id", 1)))
	)
	_intro.show_overlay(true)
	Log.line("LEVEL_INTRO id=%d quota=%d time=%.0f" % [
		int(level.get("id", 0)), _quota, _duration
	])


func _start_round() -> void:
	_state = State.PLAYING
	_finished = false
	_score = 0
	_kills = 0
	_hits = 0
	_misses = 0
	_crits = 0
	_multis = 0
	_best_combo = 0
	_sun_left = 0.0
	_frost_left = 0.0
	_chain_left = 0
	_slowmo_left = 0.0
	_time_left = _duration
	_endless_score_recorded = false

	_arena.clear_field()
	_arena.configure(level, endless)
	_arena.begin()

	AppRoot.root.guard_input(0.45)
	_intro.hide_overlay(true)
	_hud.visible = true
	_hud.set_score(0, false)
	_hud.set_progress(0, _quota)
	_hud.set_time(_time_left, _duration)
	_hud.set_powerups([])

	# Erste Schatten sofort sichtbar machen - die Runde startet ohne Leerlauf.
	for i in 3:
		_arena.spawn_enemy("shade")

	var banner: String = "ENDLOS-MODUS" if endless else "KAPITEL %d" % int(level.get("id", 0))
	_arena.spawn_banner(banner, Palette.AMBER)
	AppRoot.sfx.play("whoosh", -4.0)

	Log.line("LEVEL_START id=%d quota=%d time=%.0f endless=%s" % [
		int(level.get("id", 0)), _quota, _duration, "1" if endless else "0"
	])
	Log.line("STATE=PLAYING level=%d" % int(level.get("id", 0)))
	Log.line("SCORE=0")
	for _i in 4:
		await get_tree().process_frame
	Log.button("pause", _hud.pause_button)
	Log.line("FIELD_RECT x=%.1f y=%.1f w=%.1f h=%.1f" % [
		_arena.global_position.x, _arena.global_position.y, _arena.size.x, _arena.size.y
	])


# ----------------------------------------------------------------- Update ---

func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return

	# Zeitlupe beeinflusst das Spiel, nicht die UI-Animationen.
	var world_delta: float = delta
	if _slowmo_left > 0.0:
		_slowmo_left = maxf(0.0, _slowmo_left - delta)
		world_delta = delta * SLOWMO_FACTOR

	var enemy_scale: float = FROST_FACTOR if _frost_left > 0.0 else 1.0
	_arena.tick(world_delta, enemy_scale)

	_sun_left = maxf(0.0, _sun_left - delta)
	_frost_left = maxf(0.0, _frost_left - delta)

	if not endless:
		_time_left = maxf(0.0, _time_left - world_delta)
		if _time_left <= 0.0 and not _finished:
			_finish(false)
			return
	else:
		_time_left = maxf(0.0, _duration - _arena.elapsed())
		if _time_left <= 0.0 and not _finished:
			_finish(true)
			return

	_hud.set_combo(_arena.combo, _arena.combo_timer / Arena.COMBO_WINDOW)
	_hud.set_time(_time_left, _duration)
	_hud.tick(delta)
	_hud.set_powerups(_active_powerups())

	if _boss_pending and _kills >= _quota:
		_spawn_boss()


func _active_powerups() -> Array:
	var active: Array = []
	if _sun_left > 0.0:
		active.append({"kind": "sun", "color": Palette.AMBER, "title": "SONNENSTICH", "left": _sun_left, "total": SUN_DURATION})
	if _frost_left > 0.0:
		active.append({"kind": "frost", "color": Palette.CYAN, "title": "REIF", "left": _frost_left, "total": FROST_DURATION})
	if _chain_left > 0:
		active.append({"kind": "chain", "color": Palette.MINT, "title": "KETTE x%d" % _chain_left, "left": float(_chain_left), "total": float(CHAIN_USES)})
	return active


# ------------------------------------------------------------------- Input --

func handle_tap(global_point: Vector2) -> bool:
	if _state != State.PLAYING:
		return false
	# Ausserhalb des Feldes zaehlt nicht als Fehlgriff.
	if not _arena.get_global_rect().has_point(global_point):
		return false
	var local: Vector2 = _arena.get_global_transform().affine_inverse() * global_point
	_arena.tap(local)
	return true


## Von aussen aufrufbar (HUD-Knopf, Entwicklungshilfe).
func request_pause() -> void:
	if _state == State.PLAYING:
		_pause_round()


# ------------------------------------------------------------------ Treffer --

func _on_enemy_damaged(enemy: Enemy, at: Vector2) -> void:
	_hits += 1
	var color: Color = enemy.rim
	_arena.fx().ring(at, color, enemy.radius * 0.6, enemy.radius * 1.5, 0.28, 4.0)
	_arena.fx().sparkle(at, color, 6)
	_arena.shake(5.0)
	AppRoot.sfx.play("hit", -3.0, randf_range(0.92, 1.08))
	if enemy.hp > 0:
		_arena.spawn_float(at, "-1", Palette.TEXT_DIM, 30, 60.0)
		Log.line("HIT id=%d kind=%s hp=%d total=%d" % [enemy.get_instance_id(), enemy.kind_name(), enemy.hp, _score])
	else:
		_arena.shake(9.0)


func _on_enemy_killed(enemy: Enemy, at: Vector2, cause: String) -> void:
	_arena.begin_death(enemy)
	_kills += 1
	if not endless:
		AppRoot.save.total_shadows += 1

	var color: Color = enemy.rim
	var direct: bool = cause == "tap" or cause == "boss"
	var crit: bool = direct and _arena.roll_crit()

	# --- Punkte -----------------------------------------------------------
	var points: int = enemy.score_value
	if direct:
		_arena.add_combo()
		_best_combo = maxi(_best_combo, _arena.combo)
	var mult: float = float(_arena.combo_mult)
	if _sun_left > 0.0:
		mult *= 2.0
	if crit:
		points = int(round(float(points) * 2.0))
		_crits += 1
	var gained: int = int(round(float(points) * mult))
	_score += gained

	# --- Feedback ---------------------------------------------------------
	var power: float = 1.0
	if enemy.is_boss:
		power = 3.0
	elif crit:
		power = 1.6
	elif mult > 1.0:
		power = 1.15 + minf(mult, 9.0) * 0.05

	_arena.fx().burst(at, color, power, 4 + int(power * 3.0))
	if crit:
		_arena.fx().double_ring(at, Palette.GOLD, enemy.radius * 0.5, enemy.radius * 3.2)
		_arena.flash(Palette.GOLD, 0.10, 0.24)
		_slowmo_left = maxf(_slowmo_left, SLOWMO_CRIT)
		AppRoot.sfx.play("crit", -2.0, randf_range(0.97, 1.05))
		_arena.spawn_float(at + Vector2(0, -40), "KRITISCH", Palette.GOLD, 32, 90.0)
	else:
		_arena.fx().ring(at, color, enemy.radius * 0.6, enemy.radius * 2.6, 0.34, 5.0)
		AppRoot.sfx.play("kill", -4.0, randf_range(0.94, 1.10))

	if mult > 1.0:
		_arena.spawn_float(at, "x%d  +%s" % [int(mult), Hud._format(gained)], Palette.AMBER, 34, 96.0)
	else:
		_arena.spawn_float(at, "+%s" % Hud._format(gained), Palette.TEXT, 36, 96.0)

	_arena.shake(12.0 * power)
	_hud.set_score(_score, true)
	_hud.set_progress(_kills, _quota)

	if _arena.combo >= 3 and _arena.combo % 4 == 0:
		AppRoot.sfx.play("combo", -6.0, clampf(0.85 + float(_arena.combo) * 0.035, 0.85, 1.8))
		_arena.spawn_banner("KOMBO %d" % _arena.combo, Palette.AMBER)

	# --- Mehrfach-Treffer -------------------------------------------------
	var chain_count: int = _arena.register_kill_in_window()
	if chain_count >= 2:
		_multis += 1
		var bonus: int = 40 * chain_count
		_score += bonus
		_hud.set_score(_score, false)
		AppRoot.sfx.play("multi", -4.0, clampf(0.9 + 0.06 * float(chain_count), 0.9, 1.5))
		_arena.spawn_banner("MEHRFACH x%d  +%d" % [chain_count, bonus], Palette.MINT)

	# --- Auswirkungen -----------------------------------------------------
	_apply_death_effects(enemy, at, cause, direct)

	# --- Gegnerverhalten --------------------------------------------------
	if enemy.kind == Enemy.Kind.SPLITTER:
		_arena.shatter(at, 3)
		AppRoot.sfx.play("shatter", -4.0, randf_range(0.95, 1.05))
	elif enemy.kind == Enemy.Kind.BULWARK:
		var victims: Array[Enemy] = _arena.splash(at, 190.0, enemy)
		if victims.size() > 0:
			_arena.fx().ring(at, Palette.ARMOR_RIM, 40.0, 210.0, 0.42, 8.0)
			_arena.shake(22.0)
			AppRoot.sfx.play("explode", -3.0)
			_arena.spawn_banner("SPLITTER", Palette.CYAN)
		for victim in victims:
			_arena.fx().burst(victim.position, victim.rim, 1.1, 3)
			_arena.begin_death(victim)
			_on_enemy_killed(victim, victim.position, "splash")
	elif enemy.is_boss:
		_on_boss_defeated(enemy, at)
	else:
		var powerup_kind: String = _arena.roll_powerup()
		if powerup_kind != "":
			_arena.spawn_powerup(powerup_kind)

	# --- Logcat ------------------------------------------------------------
	var flags: String = ""
	if crit:
		flags += " crit=1"
	Log.line("KILL id=%d kind=%s cause=%s gained=%d total=%d combo=%d mult=%s%s" % [
		enemy.get_instance_id(), enemy.kind_name(), cause, gained, _score,
		_arena.combo, ("%d" % int(mult) if mult == floorf(mult) else "%.1f" % mult), flags,
	])
	Log.line("SCORE=%d" % _score)

	if enemy.is_boss and not _finished:
		_finish(true)
	elif not endless and not _finished and _kills >= _quota and not level.has("boss"):
		_finish(true)


func _apply_death_effects(enemy: Enemy, at: Vector2, _cause: String, direct: bool) -> void:
	if _chain_left > 0 and direct and not enemy.is_boss:
		_chain_left -= 1
		var victims: Array[Enemy] = _arena.chain_from(enemy, 220.0, 2)
		if victims.size() > 0:
			_slowmo_left = maxf(_slowmo_left, SLOWMO_KILL_CHAIN)
			for victim in victims:
				_arena.fx().beam(at, victim.position, Palette.MINT, 0.26)
		if victims.size() > 0:
			_arena.spawn_banner("KETTE", Palette.MINT)
			AppRoot.sfx.play("explode", -6.0, 1.25)
		for victim in victims:
			_arena.fx().burst(victim.position, victim.rim, 1.0, 3)
			_arena.begin_death(victim)
			_on_enemy_killed(victim, victim.position, "chain")


func _on_missed(at: Vector2) -> void:
	_misses += 1
	_arena.reset_combo()
	_arena.fx().ring(at, Color(0.5, 0.55, 0.7), 8.0, 62.0, 0.26, 3.0)
	_arena.shake(3.0)
	AppRoot.sfx.play("miss", -8.0)
	Log.line("MISS total=%d combo=0" % _score)


func _on_power_taken(powerup: PowerUp, at: Vector2) -> void:
	var kind: String = powerup.kind
	_arena.fx().burst(at, powerup.color(), 1.3, 6)
	_arena.fx().double_ring(at, powerup.color(), 20.0, 140.0, 0.45)
	_arena.flash(powerup.color(), 0.10, 0.30)
	_arena.spawn_banner(powerup.title(), powerup.color())
	_arena.spawn_float(at, powerup.meta()["desc"], powerup.color(), 26, 80.0)
	_arena.shake(7.0)
	AppRoot.sfx.play("power", -3.0)

	match kind:
		"sun":
			_sun_left = SUN_DURATION
		"frost":
			_frost_left = FROST_DURATION
		"chain":
			_chain_left = CHAIN_USES
	_arena.remove_powerup(powerup)
	Log.line("POWERUP kind=%s" % kind)
	Log.line("ACTIVE sun=%.1f frost=%.1f chain=%d" % [_sun_left, _frost_left, _chain_left])


# -------------------------------------------------------------------- Boss --

func _spawn_boss() -> void:
	_boss_pending = false
	var boss: Enemy = _arena.spawn_boss(_boss_hp)
	_arena.flash(Palette.BOSS_RIM, 0.22, 0.6)
	_arena.shake(30.0)
	_arena.spawn_banner("GROSSER SCHATTEN", Palette.BOSS_RIM)
	AppRoot.sfx.play("charge", -3.0)
	_arena.fx().ring(boss.position, Palette.BOSS_RIM, 20.0, 260.0, 0.7, 10.0)
	_slowmo_left = maxf(_slowmo_left, 0.5)
	Log.line("BOSS_APPEAR hp=%d" % boss.hp)


func _on_boss_defeated(enemy: Enemy, at: Vector2) -> void:
	_boss_hp = 0
	_slowmo_left = maxf(_slowmo_left, 0.9)
	_arena.fx().burst(at, Palette.BOSS_RIM, 4.0, 14)
	_arena.fx().double_ring(at, Palette.GOLD, 40.0, 420.0, 0.8)
	_arena.flash(Palette.GOLD, 0.30, 0.8)
	_arena.shake(48.0)
	AppRoot.sfx.play("explode", 0.0, 0.8)


# ------------------------------------------------------------------ Pause ---

func _pause_round() -> void:
	if _state != State.PLAYING:
		return
	AppRoot.root.guard_input(0.45)
	_state = State.PAUSED
	_arena.stop()
	_pause.set_sound_enabled(AppRoot.save.sfx)
	_pause.show_overlay(true)
	Log.line("STATE=PAUSED")


func _on_resume() -> void:
	_pause.hide_overlay(true)
	_state = State.PLAYING
	_arena.begin()
	Log.line("STATE=PLAYING level=%d" % int(level.get("id", 0)))


func _on_restart() -> void:
	_pause.hide_overlay(false)
	_pause.visible = false
	_start_round()


func _on_sound_toggled(enabled: bool) -> void:
	AppRoot.save.sfx = enabled
	AppRoot.save.save_to_disk()
	AppRoot.sfx.set_enabled(enabled)
	if enabled:
		AppRoot.sfx.play("ui", -4.0)


func _on_begin() -> void:
	_start_round()


# ---------------------------------------------------------------- Ergebnis --

func _finish(victory: bool) -> void:
	if _finished:
		return
	_finished = true
	# Kurze Sperre: das emulierte Mausereignis des Treffers darf nicht sofort
	# durchschlagen. Die Ergebnis-Karte schuetzt sich zusaetzlich selbst,
	# solange sie einblendet (siehe Overlay.show_overlay).
	AppRoot.root.guard_input(0.3)
	_state = State.RESULT
	_arena.stop()
	_arena.flash(Palette.AMBER if victory else Palette.CRIMSON, 0.22, 0.7)

	var level_id: int = int(level.get("id", 1))
	var stars: int = 0
	var stats: Array = []
	var headline: String = ""
	var subline: String = ""
	var primary_text: String = ""
	var secondary_text: String = ""
	var is_record: bool = false

	if endless:
		is_record = AppRoot.save.record_endless(_score)
		headline = "LICHT HALT"
		subline = "ENDLOS-MODUS"
		primary_text = "NOCHMAL"
		secondary_text = "ZUR UEBERSICHT"
		stats = [
			["Schatten", str(_kills)],
			["Beste Kombo", "x%d" % _best_combo],
			["Kritische Treffer", str(_crits)],
			["Mehrfach-Treffer", str(_multis)],
			["Fehlgriffe", str(_misses)],
			["Bestwert", Hud._format(AppRoot.save.endless_best)],
		]
		if is_record:
			subline = "NEUER BESTWERT"
		Log.line("ENDLESS_END score=%d kills=%d record=%s" % [_score, _kills, "1" if is_record else "0"])
		AppRoot.sfx.play("win" if victory else "lose", -2.0)
	else:
		stars = SaveData.stars_for(level, _score) if victory else 0
		var gained: int = 0
		if victory:
			gained = AppRoot.save.record_level(level_id, _score, stars)
		headline = "KAPITEL GESCHAFFT" if victory else "DAS LICHT ERLOESCHT"
		subline = "KAPITEL %d  -  %s" % [level_id, String(level.get("name", ""))]
		var next_id: int = Levels.next_id(level_id)
		if victory:
			primary_text = "WEITER" if next_id > 0 else "ENDLOS-MODUS"
			secondary_text = "NOCHMAL" if next_id > 0 else "ZUR UEBERSICHT"
		else:
			primary_text = "NOCHMAL"
			secondary_text = "ZUR UEBERSICHT"
		stats = [
			["Schatten", "%d / %d" % [_kills, _quota]],
			["Beste Kombo", "x%d" % _best_combo],
			["Kritische Treffer", str(_crits)],
			["Mehrfach-Treffer", str(_multis)],
			["Fehlgriffe", str(_misses)],
			["Bestwert", Hud._format(AppRoot.save.level_best(level_id))],
		]
		if gained > 0:
			stats.append(["Neue Sterne", "+%d" % gained])
		if victory and stars > 0:
			for i in stars:
				AppRoot.sfx.play("star", -4.0, 1.0 + 0.08 * float(i))
		AppRoot.sfx.play("win" if victory else "lose", -2.0)
		Log.line("LEVEL_%s id=%d score=%d kills=%d/%d stars=%d bestCombo=%d crits=%d multis=%d misses=%d" % [
			"CLEAR" if victory else "FAIL", level_id, _score, _kills, _quota,
			stars, _best_combo, _crits, _multis, _misses,
		])
		AppRoot.save.save_to_disk()

	_victory_pending = victory
	_result.build(
		victory, headline, subline, _score, stars, stats,
		primary_text, secondary_text, not endless
	)
	_result.show_overlay(true)
	# Kurz warten, damit die Explosionen noch sichtbar sind.
	await get_tree().create_timer(0.35).timeout
	Log.line("STATE=RESULT")


var _victory_pending: bool = false


func _on_result_primary() -> void:
	if endless:
		_start_round()
		return
	if not _victory_pending:
		_start_round()
		return
	var next_id: int = Levels.next_id(int(level.get("id", 1)))
	if next_id > 0:
		request_screen.emit("level", next_id)
	else:
		request_screen.emit("endless", 0)


func _on_result_secondary() -> void:
	if endless:
		request_screen.emit("title", 0)
		return
	_start_round()