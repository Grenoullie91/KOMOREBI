class_name Fx
extends Node2D

## Zentraler Partikel- und Effekt-Pool.
##
## Statt pro Treffer neue Nodes zu erzeugen, haelt eine einzige Instanz alle
## Effekte in typisierten Dictionaries und zeichnet sie gebuendelt. Das haelt
## den Overhead auch bei Dutzenden gleichzeitiger Explosionen klein.

const MAX_PARTS := 460

var _parts: Array = []
var _active: bool = false


func _ready() -> void:
	set_process(false)


func tick(delta: float) -> void:
	if not _active:
		return

	var gravity: float = 210.0
	var alive: Array = []
	for part in _parts:
		part["age"] += delta
		if part["age"] >= part["life"]:
			continue
		var type: String = part["type"]
		var v: Vector2 = part["vel"]
		match type:
			"spark":
				v *= maxf(0.0, 1.0 - delta * 2.4)
				v.y += gravity * 0.35 * delta
				part["vel"] = v
				part["pos"] = part["pos"] + v * delta
			"shard":
				v *= maxf(0.0, 1.0 - delta * 1.4)
				v.y += gravity * 0.55 * delta
				part["vel"] = v
				part["pos"] = part["pos"] + v * delta
				part["rot"] = part["rot"] + part["spin"] * delta
			"dot":
				v *= maxf(0.0, 1.0 - delta * 3.0)
				part["vel"] = v
				part["pos"] = part["pos"] + v * delta
		alive.append(part)
	_parts = alive

	queue_redraw()
	if _parts.is_empty():
		_active = false
		set_process(false)


func _push(part: Dictionary) -> void:
	if _parts.size() >= MAX_PARTS:
		_parts.pop_front()
	_parts.append(part)
	_active = true
	set_process(true)


func clear() -> void:
	_parts.clear()
	_active = false
	queue_redraw()


# ------------------------------------------------------------------- Spieler

## Explosions-Burst: Funken, Splitter und ein heller Blitz.
func burst(pos: Vector2, color: Color, power: float = 1.0, shard_count: int = 5) -> void:
	var spark_count: int = int(10 + 8.0 * power)
	for i in spark_count:
		var angle: float = randf() * TAU
		var speed: float = randf_range(150.0, 460.0) * power
		_push({
			"type": "spark",
			"pos": pos + Vector2.from_angle(angle) * randf_range(0.0, 10.0),
			"vel": Vector2.from_angle(angle) * speed,
			"age": 0.0,
			"life": randf_range(0.22, 0.46),
			"color": color.lerp(Color(1, 1, 1), randf() * 0.5),
			"width": randf_range(2.5, 5.5),
		})

	for i in shard_count:
		var angle: float = randf() * TAU
		_push({
			"type": "shard",
			"pos": pos,
			"vel": Vector2.from_angle(angle) * randf_range(90.0, 260.0) * power,
			"age": 0.0,
			"life": randf_range(0.34, 0.62),
			"color": color.darkened(0.15),
			"size": randf_range(4.0, 9.0),
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
		})

	_push({
		"type": "flash",
		"pos": pos,
		"vel": Vector2.ZERO,
		"age": 0.0,
		"life": 0.20,
		"color": Color(1, 1, 1),
		"size": 26.0 * power,
	})


## Weicher Lichtpunkt, z.B. fuer Komorebi-Sammler.
func sparkle(pos: Vector2, color: Color, count: int = 6) -> void:
	for i in count:
		var angle: float = randf() * TAU
		_push({
			"type": "dot",
			"pos": pos,
			"vel": Vector2.from_angle(angle) * randf_range(40.0, 150.0),
			"age": 0.0,
			"life": randf_range(0.3, 0.6),
			"color": color,
			"size": randf_range(2.5, 5.0),
		})


## Expandierender Ring - der haeufigste Treffer-Impuls.
func ring(pos: Vector2, color: Color, from_r: float, to_r: float, life: float = 0.34, width: float = 6.0) -> void:
	_push({
		"type": "ring",
		"pos": pos,
		"vel": Vector2.ZERO,
		"age": 0.0,
		"life": life,
		"color": color,
		"from": from_r,
		"to": to_r,
		"width": width,
	})


## Zwei konzentrische Ringe - fuer Kritische Treffer.
func double_ring(pos: Vector2, color: Color, from_r: float, to_r: float, life: float = 0.42) -> void:
	ring(pos, color, from_r, to_r * 0.7, life, 7.0)
	ring(pos, Color(color.r, color.g, color.b, 0.6), from_r * 0.5, to_r, life * 1.25, 4.0)


## Zickende Blitzbahn - fuer Kettenreaktionen.
func beam(from: Vector2, to: Vector2, color: Color, life: float = 0.24) -> void:
	var points := PackedVector2Array()
	var segments: int = 8
	var dir := to - from
	var normal := dir.normalized().orthogonal()
	for i in segments + 1:
		var k: float = float(i) / float(segments)
		var wobble: float = 0.0 if (i == 0 or i == segments) else randf_range(-1.0, 1.0) * dir.length() * 0.10
		points.append(from + dir * k + normal * wobble)
	_push({
		"type": "beam",
		"pos": from,
		"vel": Vector2.ZERO,
		"age": 0.0,
		"life": life,
		"color": color,
		"points": points,
	})


## Dauerhafte Markierung auf dem Boden (z.B. Frost-Nachhall).
func ground_scar(pos: Vector2, color: Color, radius: float, life: float) -> void:
	_push({
		"type": "scar",
		"pos": pos,
		"vel": Vector2.ZERO,
		"age": 0.0,
		"life": life,
		"color": color,
		"size": radius,
	})


# -------------------------------------------------------------------- Draw

func _draw() -> void:
	for part in _parts:
		var k: float = clampf(part["age"] / part["life"], 0.0, 1.0)
		var color: Color = part["color"]
		match part["type"]:
			"spark":
				var pos: Vector2 = part["pos"]
				var vel: Vector2 = part["vel"]
				var tail := pos - vel.normalized() * float(part["width"]) * 2.6
				draw_line(tail, pos, Color(color.r, color.g, color.b, (1.0 - k) * 0.95), float(part["width"]) * (1.0 - k * 0.6), true)
			"dot":
				draw_circle(part["pos"], float(part["size"]) * (1.0 - k * 0.5), Color(color.r, color.g, color.b, (1.0 - k) * 0.9))
			"flash":
				var r: float = float(part["size"]) * (0.4 + k * 1.6)
				draw_circle(part["pos"], r, Color(color.r, color.g, color.b, (1.0 - k) * 0.55))
			"shard":
				var s: float = float(part["size"])
				var rot: float = part["rot"]
				var pts := PackedVector2Array([
					part["pos"] + Vector2(cos(rot), sin(rot)) * s,
					part["pos"] + Vector2(cos(rot + 2.1), sin(rot + 2.1)) * s * 0.6,
					part["pos"] + Vector2(cos(rot + 4.2), sin(rot + 4.2)) * s,
				])
				draw_colored_polygon(pts, Color(color.r, color.g, color.b, (1.0 - k) * 0.9))
			"ring":
				var r: float = lerpf(float(part["from"]), float(part["to"]), 1.0 - pow(1.0 - k, 2.4))
				draw_arc(part["pos"], r, 0.0, TAU, 40, Color(color.r, color.g, color.b, (1.0 - k) * 0.9), float(part["width"]) * (1.0 - k * 0.7), true)
			"beam":
				var alpha: float = (1.0 - k) * 0.95
				draw_polyline(part["points"], Color(color.r, color.g, color.b, alpha * 0.4), 9.0 * (1.0 - k * 0.5), true)
				draw_polyline(part["points"], Color(1, 1, 1, alpha), 2.6, true)
			"scar":
				draw_arc(part["pos"], float(part["size"]) * (0.6 + k * 0.7), 0.0, TAU, 28, Color(color.r, color.g, color.b, (1.0 - k) * 0.35), 3.0, true)