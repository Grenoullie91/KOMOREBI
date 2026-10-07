class_name Arena
extends Control

## Das Spielfeld: Gegner, Power-ups, Partikel, Trefferauflösung und Screen-Shake.
##
## Die Arena weiß bewusst nichts über Punkte, Kombos oder Level - sie meldet
## über Signale, was passiert ist, und lässt die Spiellogik im GameScreen.
## Das hält Regeln und Darstellung getrennt.

signal enemy_damaged(enemy: Enemy, at: Vector2)
signal enemy_killed(enemy: Enemy, at: Vector2, cause: String)
signal power_taken(powerup: PowerUp, at: Vector2)
signal missed(at: Vector2)

const SHAKE_DECAY := 7.5
const CRIT_CHANCE_BASE := 0.06
const CRIT_CHANCE_PER_COMBO := 0.012
const CRIT_CHANCE_MAX := 0.34
## Zeitfenster, in dem eine Kombo weiterlaeuft. Bewusst grosszuegig gewaehlt:
## bei schnellem Tippen soll die Kette nicht durch eine knapp verpasste
## Zwischenpause abbrechen.
const COMBO_WINDOW := 2.6
const MULTI_WINDOW := 0.30

var running: bool = false
var combo: int = 0
var combo_timer: float = 0.0
var combo_mult: int = 1
var kills: int = 0

var _world: Node2D
var _fx: Fx
var _float_layer: Control
var _flash: ColorRect

var _enemies: Array[Enemy] = []
var _powerups: Array[PowerUp] = []
var _rng := RandomNumberGenerator.new()

var _shake: float = 0.0
var _shake_vec: Vector2 = Vector2.ZERO

var _spawn_timer: float = 0.0
var _spawn_interval: float = 1.0
var _spawn_floor: float = 0.5
var _spawn_start: float = 1.0
var _max_alive: int = 8
var _weights: Dictionary = {"shade": 1}
var _level_duration: float = 45.0
var _elapsed: float = 0.0
var _endless: bool = false

var _boss: Enemy = null
var _boss_summon_in: float = 6.0

var _multi_timer: float = 0.0
var _multi_count: int = 0
var _kills_since_power: int = 0

## Streifen am oberen Rand, der dem HUD gehoert (kein Spawnbereich).
var top_inset: float = 128.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.randomize()

	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0.0)
	add_child(_flash)

	_world = Node2D.new()
	add_child(_world)

	_fx = Fx.new()
	_world.add_child(_fx)

	_float_layer = Control.new()
	_float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	resized.connect(_on_resized)


func _on_resized() -> void:
	for enemy in _enemies:
		_clamp_inside(enemy)
	for powerup in _powerups:
		_clamp_powerup(powerup)


# ----------------------------------------------------------------- Aufbau ---

func configure(level: Dictionary, endless: bool = false) -> void:
	_endless = endless
	_level_duration = float(level.get("time", 45.0))
	_spawn_start = float(level.get("spawn_start", 1.1))
	_spawn_floor = float(level.get("spawn_end", 0.6))
	_spawn_interval = _spawn_start
	_spawn_timer = 0.55
	_max_alive = int(level.get("max_alive", 8))
	_weights = (level.get("weights", {"shade": 1}) as Dictionary).duplicate()
	_elapsed = 0.0
	_boss_summon_in = 6.0


func begin() -> void:
	running = true


func stop() -> void:
	running = false


func clear_field() -> void:
	for enemy in _enemies:
		enemy.queue_free()
	_enemies.clear()
	for powerup in _powerups:
		powerup.queue_free()
	_powerups.clear()
	if _fx:
		_fx.clear()
	_boss = null
	combo = 0
	combo_timer = 0.0
	combo_mult = 1
	kills = 0
	_shake = 0.0
	_shake_vec = Vector2.ZERO
	for child in _float_layer.get_children():
		child.queue_free()


# ------------------------------------------------------------------ Update --

func tick(delta: float, enemy_scale: float) -> void:
	if not running:
		return

	_elapsed += delta

	# Kombo-Zeitfenster
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			combo_mult = 1
	if _multi_timer > 0.0:
		_multi_timer -= delta
		if _multi_timer <= 0.0:
			_multi_count = 0

	_tick_spawning(delta)

	# Oberer Freiraum, damit nichts unter dem HUD erscheint.
	var bounds := Rect2(Vector2(0.0, top_inset), Vector2(size.x, maxf(120.0, size.y - top_inset)))

	var dead: Array[Enemy] = []
	for enemy in _enemies:
		enemy.tick(delta, bounds, enemy_scale)
		if enemy._death > 0.0 and enemy._death > 0.24:
			dead.append(enemy)
		elif not enemy.alive:
			dead.append(enemy)
	for enemy in dead:
		_enemies.erase(enemy)
		enemy.queue_free()

	var expired: Array[PowerUp] = []
	for powerup in _powerups:
		powerup.tick(delta)
		if powerup.age >= PowerUp.LIFETIME:
			expired.append(powerup)
	for powerup in expired:
		_powerups.erase(powerup)
		_fx.sparkle(powerup.position, powerup.color(), 5)
		powerup.queue_free()

	_fx.tick(delta)
	_tick_shake(delta)
	_tick_report_positions(delta)


## Regelmaessig die aktuellen Gegnerpositionen melden.
##
## Der automatisierte Test braucht frische Koordinaten: die Spawn-Meldung
## beschreibt nur den Ort bei der Geburt, und die Gegner driften danach
## weiter. Ohne diese Zeile arbeitet der Test mit Positionen, die mehrere
## Sekunden alt sind - und verfehlt systematisch. Eine Zeile pro Intervall
## fasst alle lebenden Gegner zusammen, statt eine Zeile je Gegner und
## Frame zu erzeugen.
const REPORT_HZ := 4.0

var _report_timer: float = 0.0


func _tick_report_positions(delta: float) -> void:
	_report_timer -= delta
	if _report_timer > 0.0:
		return
	_report_timer = 1.0 / REPORT_HZ

	var parts: PackedStringArray = PackedStringArray()
	for enemy in _enemies:
		if enemy._death > 0.0 or not enemy.alive:
			continue
		parts.append("id=%d %s" % [enemy.get_instance_id(), Log.px_str(global_position + enemy.position)])
	for powerup in _powerups:
		parts.append("pup=%d %s" % [powerup.get_instance_id(), Log.px_str(global_position + powerup.position)])
	if parts.is_empty():
		return
	Log.line("ENEMY_POS " + " ".join(parts))


func _tick_spawning(delta: float) -> void:
	if _boss != null:
		return
	var intensity: float = clampf(_elapsed / maxf(1.0, _level_duration), 0.0, 1.0)
	if _endless:
		_spawn_interval = Levels.endless_spawn_interval(_elapsed, _level_duration)
		_weights = Levels.endless_weights(_elapsed, _level_duration)
	else:
		_spawn_interval = lerpf(_spawn_start, _spawn_floor, pow(intensity, 0.85))

	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	if _enemies.size() >= _max_alive:
		_spawn_timer = 0.25
		return
	_spawn_timer = _spawn_interval * _rng.randf_range(0.82, 1.18)
	spawn_enemy(Levels.weighted_kind(_weights, intensity))


func _tick_shake(delta: float) -> void:
	if _shake <= 0.0:
		_shake_vec = Vector2.ZERO
		_world.position = Vector2.ZERO
		return
	_shake = maxf(0.0, _shake - _shake * SHAKE_DECAY * delta - 6.0 * delta)
	var amount: float = _shake
	_shake_vec = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * amount
	_world.position = _shake_vec


# ------------------------------------------------------------------ Spawns --

func spawn_enemy(kind: String) -> Enemy:
	var enemy := Enemy.new()
	_world.add_child(enemy)
	enemy.setup(_kind_from_name(kind))
	enemy.position = _pick_free_position(enemy.radius)
	_enemies.append(enemy)
	Log.line("ENEMY_SPAWN id=%d kind=%s hp=%d %s" % [
		enemy.get_instance_id(), enemy.kind_name(), enemy.hp, Log.px_str(global_position + enemy.position)
	])
	return enemy


func spawn_boss(boss_hp: int) -> Enemy:
	var enemy := Enemy.new()
	_world.add_child(enemy)
	enemy.setup(Enemy.Kind.BOSS, boss_hp)
	enemy.position = size * 0.5
	enemy.z_index = 2
	_enemies.append(enemy)
	_boss = enemy
	Log.line("BOSS_SPAWN hp=%d %s" % [enemy.hp, Log.px_str(global_position + enemy.position)])
	return enemy


func boss() -> Enemy:
	return _boss


func spawn_powerup(kind: String) -> PowerUp:
	var powerup := PowerUp.new()
	_world.add_child(powerup)
	powerup.setup(kind)
	powerup.position = _pick_free_position(38.0)
	_powerups.append(powerup)
	Log.line("POWERUP_SPAWN id=%d kind=%s %s" % [
		powerup.get_instance_id(), kind, Log.px_str(global_position + powerup.position)
	])
	return powerup


## Zufaellige Gabe mit leicht bevorzugter Vielfalt: nie zweimal hintereinander
## dieselbe Sorte, solange mindestens zwei Sorten offen sind.
func roll_powerup() -> String:
	_kills_since_power += 1
	var guaranteed: bool = _kills_since_power >= 7
	_kills_since_power = 0
	if not guaranteed and randf() > 0.20:
		return ""
	return ["sun", "frost", "chain"].pick_random()


func _kind_from_name(name: String) -> int:
	match name:
		"wisp":
			return Enemy.Kind.WISP
		"splitter":
			return Enemy.Kind.SPLITTER
		"shard":
			return Enemy.Kind.SHARD
		"bulwark":
			return Enemy.Kind.BULWARK
		"boss":
			return Enemy.Kind.BOSS
		_:
			return Enemy.Kind.SHADE


func _pick_free_position(radius_px: float) -> Vector2:
	var pad: float = radius_px * 1.5 + 10.0
	var min_p := Vector2(pad, top_inset + pad)
	var max_p := size - Vector2(pad, pad)
	max_p.x = maxf(max_p.x, min_p.x)
	max_p.y = maxf(max_p.y, min_p.y)

	var candidate := Vector2.ZERO
	for attempt in 20:
		candidate = Vector2(
			_rng.randf_range(min_p.x, max_p.x),
			_rng.randf_range(min_p.y, max_p.y)
		)
		if _is_clear(candidate, radius_px + 26.0):
			break
	return candidate


func _is_clear(point: Vector2, min_distance: float) -> bool:
	for enemy in _enemies:
		if enemy.position.distance_to(point) < min_distance:
			return false
	for powerup in _powerups:
		if powerup.position.distance_to(point) < min_distance:
			return false
	return true


func _clamp_inside(node: Node2D) -> void:
	var pad: float = 40.0
	node.position.x = clampf(node.position.x, pad, maxf(pad, size.x - pad))
	node.position.y = clampf(node.position.y, top_inset + pad, maxf(top_inset + pad, size.y - pad))


func _clamp_powerup(powerup: PowerUp) -> void:
	_clamp_inside(powerup)


# --------------------------------------------------------------- Treffer ---

## Ein Tipp in Feldkoordinaten. Prioritaet: Power-up, dann naechster Gegner.
func tap(local_point: Vector2) -> void:
	if not running:
		return

	for powerup in _powerups:
		if powerup.contains_point(local_point):
			power_taken.emit(powerup, powerup.position)
			return

	var target: Enemy = null
	var best_distance: float = INF
	for enemy in _enemies:
		if enemy._death > 0.0 or not enemy.alive:
			continue
		var distance: float = enemy.position.distance_to(local_point)
		if distance <= enemy.hit_radius() and distance < best_distance:
			best_distance = distance
			target = enemy

	if target == null:
		missed.emit(local_point)
		return

	var killed: bool = target.take_damage()
	enemy_damaged.emit(target, target.position)
	if killed:
		enemy_killed.emit(target, target.position, "boss" if target.is_boss else "tap")


## Kritische Treffer werden mit waechsender Kombo wahrscheinlicher.
func roll_crit() -> bool:
	var chance: float = minf(CRIT_CHANCE_BASE + float(combo) * CRIT_CHANCE_PER_COMBO, CRIT_CHANCE_MAX)
	return randf() < chance


# ------------------------------------------------- Auswirkungen auf Gegner --

## Splitter zerfallen in drei Scherben.
func shatter(pos: Vector2, count: int = 3) -> void:
	for i in count:
		var enemy := Enemy.new()
		_world.add_child(enemy)
		enemy.setup(Enemy.Kind.SHARD)
		enemy.position = pos + Vector2.from_angle(TAU * float(i) / float(count) + randf() * 0.6) * 26.0
		_clamp_inside(enemy)
		_enemies.append(enemy)


## Kettenreaktion: naechste Gegner im Radius mittreffen.
func chain_from(source: Enemy, radius: float, max_targets: int = 2) -> Array[Enemy]:
	var found: Array[Enemy] = []
	var candidates: Array[Enemy] = []
	for enemy in _enemies:
		if enemy == source or enemy._death > 0.0 or not enemy.alive:
			continue
		var distance: float = enemy.position.distance_to(source.position)
		if distance <= radius:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return a.position.distance_to(source.position) < b.position.distance_to(source.position)
	)
	for i in mini(max_targets, candidates.size()):
		found.append(candidates[i])
	return found


## Splitterschaden (Panzer-Explosion): alle Gegner im Radius sofort toten.
func splash(pos: Vector2, radius: float, source: Enemy) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for enemy in _enemies:
		if enemy == source or enemy._death > 0.0 or not enemy.alive:
			continue
		if enemy.position.distance_to(pos) <= radius:
			found.append(enemy)
	return found


func begin_death(enemy: Enemy) -> void:
	enemy.start_death()


func alive_count() -> int:
	var count: int = 0
	for enemy in _enemies:
		if enemy.alive and enemy._death <= 0.0:
			count += 1
	return count


func nearest_enemy(point: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = INF
	for enemy in _enemies:
		if enemy._death > 0.0 or not enemy.alive:
			continue
		var distance: float = enemy.position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


# ------------------------------------------------------------- Präsentation --

func add_combo() -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_mult = clampi(1 + (combo - 1) / 4, 1, 9)


func reset_combo() -> void:
	combo = 0
	combo_timer = 0.0
	combo_mult = 1


func register_kill_in_window() -> int:
	_multi_count += 1
	_multi_timer = MULTI_WINDOW
	return _multi_count


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func flash(color: Color, alpha: float = 0.18, duration: float = 0.26) -> void:
	_flash.color = Color(color.r, color.g, color.b, alpha)
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(color.r, color.g, color.b, 0.0), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Laufzeit des aktuellen Kapitels (Endlos-Modus nutzt das fuer die Anzeige).
func elapsed() -> float:
	return _elapsed


func remove_powerup(powerup: PowerUp) -> void:
	_powerups.erase(powerup)
	powerup.queue_free()


func alive_powerups() -> Array[PowerUp]:
	return _powerups


## Schwebende Zahl an einer Feldposition.
func spawn_float(at: Vector2, text: String, color: Color, size: int = 44, rise: float = 110.0) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Fonts.BOLD)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.92))
	label.add_theme_constant_override("outline_size", maxi(6, size / 5))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(240.0, 70.0)
	# Nicht unter das HUD steigen: die Zahl bleibt sonst im Kopf verschwunden.
	var lowest: float = top_inset + 34.0
	label.position = Vector2(at.x - 120.0, maxf(lowest, at.y - 35.0))
	_float_layer.add_child(label)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(label, "position:y", maxf(lowest, label.position.y - rise), 0.78) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.22)
	tw.tween_property(label, "scale", Vector2(1.18, 1.18), 0.12).set_delay(0.02)
	label.pivot_offset = label.size * 0.5
	tw.finished.connect(label.queue_free)


## Kurzlebige Textmitte im Feld (z.B. "MULTI x3", "KRITISCH").
func spawn_banner(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", Fonts.BOLD)
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.05, 0.92))
	label.add_theme_constant_override("outline_size", 9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = size
	label.position = Vector2(-20.0, size.y * 0.34)
	label.pivot_offset = Vector2(size.x * 0.5, 20.0)
	label.scale = Vector2(0.7, 0.7)
	_float_layer.add_child(label)

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.set_ignore_time_scale(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.20).set_delay(0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.5)
	tw.finished.connect(label.queue_free)


func fx() -> Fx:
	return _fx


func debug_positions() -> Array:
	var out: Array = []
	for enemy in _enemies:
		out.append({"id": enemy.get_instance_id(), "pos": global_position + enemy.position})
	return out