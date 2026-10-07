class_name Enemy
extends Node2D

## Ein Gegner. Alle Typen teilen sich Lebenszyklus, Pop-In, Trefferblitz und
## Zerstörung; unterscheiden sich aber in Bewegung, Trefferpunkten, Form und
## Rim-Farbe. Die gesamte Darstellung ist prozedural gezeichnet - dunkler Kern,
## heller Rand: so bleibt die Silhouette auf dem Nachtgrund immer lesbar.
##
## Wichtig fuer das Test-Setup: Trefferpunkte werden NICHT hier entschieden.
## Das Arena-Script fragt nur nach `hit_radius()` und `contains_point()`,
## damit Eingabe- und Spiellogik an einer Stelle liegen.

enum Kind { SHADE, WISP, SPLITTER, SHARD, BULWARK, BOSS }

const STATS := {
	Kind.SHADE: {"hp": 1, "radius": 44.0, "speed": 30.0, "score": 10},
	Kind.WISP: {"hp": 1, "radius": 28.0, "speed": 92.0, "score": 16},
	Kind.SPLITTER: {"hp": 1, "radius": 46.0, "speed": 24.0, "score": 20},
	Kind.SHARD: {"hp": 1, "radius": 20.0, "speed": 118.0, "score": 6},
	Kind.BULWARK: {"hp": 3, "radius": 54.0, "speed": 20.0, "score": 30},
	Kind.BOSS: {"hp": 6, "radius": 118.0, "speed": 0.0, "score": 150},
}

const HIT_FACTOR := 0.88
const POP_TIME := 0.30

var kind: int = Kind.SHADE
var hp: int = 1
var max_hp: int = 1
var radius: float = 44.0
var base_speed: float = 30.0
var score_value: int = 10
var rim: Color = Palette.SHADE_RIM
var core: Color = Palette.SHADE_CORE
var alive: bool = true
var is_boss: bool = false

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.0
var max_lifetime: float = 0.0
var spin: float = 0.0

var _spawn: float = 0.0
var _flash: float = 0.0
var _death: float = 0.0
var _time: float = 0.0
var _wander: Vector2 = Vector2.ZERO
var _wander_in: float = 0.0
var _dash_in: float = 0.0
var _boss_phase: float = 0.0


func setup(new_kind: int, boss_hp: int = 0) -> void:
	kind = new_kind
	var stats: Dictionary = STATS[kind]
	max_hp = int(stats["hp"])
	if kind == Kind.BOSS and boss_hp > 0:
		max_hp = boss_hp
	hp = max_hp
	radius = float(stats["radius"])
	base_speed = float(stats["speed"])
	score_value = int(stats["score"])
	is_boss = kind == Kind.BOSS

	match kind:
		Kind.SHADE:
			rim = Palette.SHADE_RIM
			core = Palette.SHADE_CORE
		Kind.WISP:
			rim = Palette.WISP_RIM
			core = Palette.WISP_CORE
		Kind.SPLITTER:
			rim = Palette.SPLIT_RIM
			core = Palette.SPLIT_CORE
		Kind.SHARD:
			rim = Palette.SPLIT_RIM.lightened(0.25)
			core = Palette.SPLIT_CORE
		Kind.BULWARK:
			rim = Palette.ARMOR_RIM
			core = Palette.ARMOR_CORE
		Kind.BOSS:
			rim = Palette.BOSS_RIM
			core = Palette.BOSS_CORE
			max_lifetime = 0.0

	_spawn = 0.0
	_flash = 0.0
	_death = 0.0
	_time = randf() * 6.0
	spin = randf() * TAU
	_wander = Vector2.from_angle(randf() * TAU)
	_wander_in = randf() * 0.8
	_dash_in = randf_range(0.4, 1.4)

	if kind == Kind.SHARD:
		max_lifetime = 6.0


func kind_name() -> String:
	return ["shade", "wisp", "splitter", "shard", "bulwark", "boss"][kind]


func hit_radius() -> float:
	return radius * HIT_FACTOR * _pop_scale()


func contains_point(local_point: Vector2) -> bool:
	return local_point.distance_to(position) <= hit_radius()


## Treffer abhandeln. Gibt true zurueck, wenn der Gegner dabei stirbt.
func take_damage() -> bool:
	hp -= 1
	_flash = 1.0
	return hp <= 0


func kill() -> void:
	alive = false


## Einen Frame vorruecken. `enemy_scale` verlangsamt nur die Gegner
## (Frost-Power-up), nicht die Spiellogik des restlichen Bildes.
func tick(delta: float, bounds: Rect2, enemy_scale: float) -> void:
	_time += delta
	spin += delta * _spin_speed()
	_spawn = minf(1.0, _spawn + delta / POP_TIME)
	_flash = maxf(0.0, _flash - delta * 4.5)

	if _death > 0.0:
		_death += delta
		queue_redraw()
		return

	lifetime += delta
	if max_lifetime > 0.0 and lifetime > max_lifetime:
		_spawn = maxf(0.0, _spawn - delta * 1.4)
		if _spawn <= 0.0:
			alive = false

	_move(delta, bounds, enemy_scale)

	# Sichtbarer Trefferblitz direkt nach dem Antippen.
	queue_redraw()


func start_death() -> void:
	_death = 0.0001


func _spin_speed() -> float:
	match kind:
		Kind.SHADE:
			return 0.6
		Kind.WISP:
			return 3.4
		Kind.SPLITTER:
			return -1.1
		Kind.SHARD:
			return 4.2
		Kind.BULWARK:
			return 0.45
		_:
			return 0.28


func _pop_scale() -> float:
	if _spawn >= 1.0:
		return 1.0
	var t: float = clampf(_spawn, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	return eased * (1.0 + 0.30 * sin(PI * t))


func _move(delta: float, bounds: Rect2, enemy_scale: float) -> void:
	var dt: float = delta * enemy_scale

	match kind:
		Kind.WISP:
			_dash_in -= dt
			if _dash_in <= 0.0:
				_dash_in = randf_range(0.55, 1.15)
				velocity = Vector2.from_angle(randf() * TAU) * base_speed * 2.1
			velocity = velocity.move_toward(Vector2.ZERO, base_speed * 5.0 * dt)
		Kind.SHARD:
			_wander_in -= dt
			if _wander_in <= 0.0:
				_wander_in = randf_range(0.5, 1.0)
				_wander = Vector2.from_angle(randf() * TAU)
			velocity = velocity.lerp(_wander * base_speed, clampf(dt * 3.0, 0.0, 1.0))
		Kind.BOSS:
			# Der Boss drueckt sich langsam auf die Mitte und pendelt leicht.
			_boss_phase += dt
			var target := bounds.get_center()
			var drift := Vector2(cos(_boss_phase * 0.6), sin(_boss_phase * 0.45)) * 26.0
			velocity = (target + drift - position).limit_length(46.0)
		_:
			_wander_in -= dt
			if _wander_in <= 0.0:
				_wander_in = randf_range(0.7, 1.7)
				_wander = Vector2.from_angle(randf() * TAU)
			velocity = velocity.lerp(_wander * base_speed, clampf(dt * 2.4, 0.0, 1.0))

	position += velocity * dt * _pop_scale()

	var pad: float = radius * 0.75 + 6.0
	var min_p := Vector2(bounds.position.x + pad, bounds.position.y + pad)
	var max_p := bounds.position + bounds.size - Vector2(pad, pad)
	max_p.x = maxf(max_p.x, min_p.x)
	max_p.y = maxf(max_p.y, min_p.y)
	if position.x < min_p.x or position.x > max_p.x:
		_wander.x = -_wander.x
		velocity.x = -absf(velocity.x)
		position.x = clampf(position.x, min_p.x, max_p.x)
	if position.y < min_p.y or position.y > max_p.y:
		_wander.y = -_wander.y
		velocity.y = -absf(velocity.y)
		position.y = clampf(position.y, min_p.y, max_p.y)


# ------------------------------------------------------------------ Zeichnen

func _draw() -> void:
	if _death > 0.0:
		_draw_dying()
		return

	var s: float = _pop_scale()
	if s <= 0.02:
		return
	var r: float = radius * s
	var breathe: float = 1.0 + 0.035 * sin(_time * 3.4)
	var rr: float = r * breathe

	# Weicher Glow in zwei Ringen - trennt die Figur vom Hintergrund.
	draw_circle(Vector2.ZERO, rr * 1.42, Color(rim.r, rim.g, rim.b, 0.10))
	draw_circle(Vector2.ZERO, rr * 1.20, Color(rim.r, rim.g, rim.b, 0.16))

	match kind:
		Kind.SHADE:
			_draw_shade(rr)
		Kind.WISP:
			_draw_wisp(rr)
		Kind.SPLITTER:
			_draw_splitter(rr)
		Kind.SHARD:
			_draw_shard(rr)
		Kind.BULWARK:
			_draw_bulwark(rr)
		Kind.BOSS:
			_draw_boss(rr)

	if _flash > 0.0:
		var f: float = _flash
		draw_circle(Vector2.ZERO, rr * (1.0 + 0.35 * f), Color(1, 1, 1, 0.55 * f))
		draw_circle(Vector2.ZERO, rr * (1.0 + 0.70 * f), Color(1, 1, 1, 0.22 * f))


func _draw_dying() -> void:
	var k: float = clampf(_death / 0.22, 0.0, 1.0)
	var r: float = radius * (1.0 + k * 0.9)
	var alpha: float = (1.0 - k) * 0.9
	draw_circle(Vector2.ZERO, r, Color(rim.r, rim.g, rim.b, alpha * 0.35))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 1, 1, alpha), 4.0, true)


func _ring(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


func _draw_shade(r: float) -> void:
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = spin + TAU * float(i) / 6.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, core)
	_ring(pts, rim, 4.0)
	draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 28, Color(rim.r, rim.g, rim.b, 0.75), 2.5, true)
	# Ein einzelnes leuchtendes Auge gibt jedem Schatten eine Richtung.
	var eye := Vector2(cos(spin * 0.6), sin(spin * 0.6)) * r * 0.14
	draw_circle(eye, r * 0.20, Color(1, 1, 1, 0.92))
	draw_circle(eye, r * 0.34, Color(rim.r, rim.g, rim.b, 0.30))


func _draw_wisp(r: float) -> void:
	# Drei nachlaufende Spitzen machen die schnelle Bewegung lesbar.
	for i in 3:
		var back: float = r * (1.5 + 0.45 * float(i))
		var tail := -velocity.normalized() * back
		var side := velocity.normalized().orthogonal() * r * 0.42 * float(i + 1)
		draw_line(tail, Vector2.ZERO, Color(rim.r, rim.g, rim.b, 0.30 - 0.08 * float(i)), r * 0.34, true)
		draw_circle(tail, r * (0.36 - 0.08 * float(i)), Color(rim.r, rim.g, rim.b, 0.45 - 0.10 * float(i)))
	draw_circle(Vector2.ZERO, r, core)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, rim, 3.5, true)
	draw_circle(Vector2.ZERO, r * 0.45, Color(1, 0.95, 0.85, 0.85))


func _draw_splitter(r: float) -> void:
	var pts := PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.88, 0), Vector2(0, r), Vector2(-r * 0.88, 0)
	])
	draw_colored_polygon(pts, core)
	_ring(pts, rim, 4.0)
	# Risse deuten an, dass beim Tod drei Scherben entstehen.
	for i in 3:
		var a: float = spin + TAU * float(i) / 3.0
		draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * r * 0.9, Color(rim.r, rim.g, rim.b, 0.8), 3.0, true)
	draw_circle(Vector2.ZERO, r * 0.22, Color(1, 1, 1, 0.85))


func _draw_shard(r: float) -> void:
	var pts := PackedVector2Array()
	for i in 3:
		var a: float = spin + TAU * float(i) / 3.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(core.r, core.g, core.b, 0.95))
	_ring(pts, Color(rim.r, rim.g, rim.b, 0.9), 2.5)


func _draw_bulwark(r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a: float = spin * 0.5 + TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, core)
	_ring(pts, rim, 4.0)

	# Rotierende Panzerplatten: je geschossene Platte weniger.
	var plates: int = maxi(0, hp)
	for i in plates:
		var a: float = -spin * 1.6 + TAU * float(i) / 3.0
		var c := Vector2(cos(a), sin(a)) * r * 0.55
		var plate := PackedVector2Array()
		for j in 4:
			var b: float = a + PI * 0.5 * float(j)
			plate.append(c + Vector2(cos(b), sin(b)) * r * 0.30)
		draw_colored_polygon(plate, Color(rim.r, rim.g, rim.b, 0.85))

	draw_arc(Vector2.ZERO, r * 0.30, 0.0, TAU, 20, Color(1, 1, 1, 0.55), 3.0, true)


func _draw_boss(r: float) -> void:
	# Drei gegenlaeufige Ringe um einen pulsierenden Kern.
	for ring_index in 3:
		var rr: float = r * (1.0 - 0.18 * float(ring_index))
		var seg: int = 6 + ring_index * 2
		var pts := PackedVector2Array()
		for i in seg:
			var a: float = spin * (1.0 - 0.35 * float(ring_index)) * (1.0 if ring_index % 2 == 0 else -1.0) \
				+ TAU * float(i) / float(seg)
			pts.append(Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color(core.r, core.g, core.b, 0.92))
		_ring(pts, Color(rim.r, rim.g, rim.b, 0.55 + 0.15 * float(ring_index)), 3.5)

	var pulse: float = 0.5 + 0.5 * sin(_time * 2.1)
	draw_circle(Vector2.ZERO, r * 0.42, Color(rim.r, rim.g, rim.b, 0.22 + 0.10 * pulse))
	draw_circle(Vector2.ZERO, r * 0.26, Color(0.04, 0.01, 0.06, 0.95))
	draw_arc(Vector2.ZERO, r * 0.26, 0.0, TAU, 24, Color(rim.r, rim.g, rim.b, 0.9), 3.0, true)

	# Schwachstellen: je verbleibender HP eine umlaufende Kerze.
	var alive_pips: int = maxi(0, hp)
	for i in alive_pips:
		var a: float = spin * 1.9 + TAU * float(i) / float(maxi(1, max_hp))
		var c := Vector2(cos(a), sin(a)) * r * 0.72
		draw_circle(c, r * 0.075, Color(1, 0.94, 0.72, 0.95))
		draw_circle(c, r * 0.16, Color(1, 0.85, 0.5, 0.22))

	if _flash > 0.0:
		draw_circle(Vector2.ZERO, r * 1.1, Color(1, 1, 1, 0.30 * _flash))


func visible_radius() -> float:
	return radius * 1.5