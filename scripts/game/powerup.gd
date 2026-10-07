class_name PowerUp
extends Node2D

## Sammelbare Gabe. Drei klar unterscheidbare Effekte, alle mit eigener
## Farbe, eigenem Glyph und eigener Dauer-Anzeige, damit man sie auch im
## wilden Treiben sofort erkennt:
##
##   sun    - SO NBURST  : kurzer Doppelpunkte-Bonus
##   frost  - REIF       : Gegner frieren zeitweise ein
##   chain  - KETTE      : die naechsten Toete loesen Blitzketten aus

const LIFETIME := 4.2
const HIT_FACTOR := 1.05

var kind: String = "sun"
var age: float = 0.0
var taken: bool = false

var _time: float = 0.0
var _phase: float = 0.0

const META := {
	"sun": {
		"color": Palette.AMBER,
		"title": "SONNENSTICH",
		"desc": "5s doppelte Punkte",
	},
	"frost": {
		"color": Palette.CYAN,
		"title": "REIF",
		"desc": "Gegner werden langsam",
	},
	"chain": {
		"color": Palette.MINT,
		"title": "KETTE",
		"desc": "Nächste 6 Töte zünden durch",
	},
}


func setup(new_kind: String) -> void:
	kind = new_kind
	_phase = randf() * TAU
	_time = randf() * 4.0


func meta() -> Dictionary:
	return META.get(kind, META["sun"])


func color() -> Color:
	return meta()["color"]


func title() -> String:
	return meta()["title"]


func tick(delta: float) -> void:
	_time += delta
	age += delta
	queue_redraw()


func time_left() -> float:
	return maxf(0.0, LIFETIME - age)


func hit_radius() -> float:
	return 34.0 * HIT_FACTOR


func contains_point(local_point: Vector2) -> bool:
	return local_point.distance_to(position) <= hit_radius()


func _draw() -> void:
	var fade: float = 1.0
	if age > LIFETIME - 0.8:
		fade = clampf((LIFETIME - age) / 0.8, 0.0, 1.0)
		fade = 0.25 + 0.75 * (0.5 + 0.5 * sin(_time * 22.0))

	var c: Color = color()
	var bob: float = sin(_time * 2.6 + _phase) * 4.0
	var origin := Vector2(0.0, bob)

	# Weicher Halo + pulsierender Ring zeigen die Lebenszeit an.
	draw_circle(origin, 44.0, Color(c.r, c.g, c.b, 0.14 * fade))
	draw_arc(origin, 34.0, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.30 * fade), 2.0, true)

	var life_ratio: float = clampf(time_left() / LIFETIME, 0.0, 1.0)
	draw_arc(origin, 40.0, -PI * 0.5, -PI * 0.5 + TAU * life_ratio, 40, Color(c.r, c.g, c.b, 0.85 * fade), 3.5, true)

	# Aussenrotierender Rahmen.
	var frame := PackedVector2Array()
	for i in 6:
		var a: float = _time * 1.4 + TAU * float(i) / 6.0
		frame.append(origin + Vector2(cos(a), sin(a)) * 27.0)
	frame.append(frame[0])
	draw_polyline(frame, Color(c.r, c.g, c.b, 0.95 * fade), 3.0, true)

	# Glyph
	draw_circle(origin, 18.0, Color(c.r, c.g, c.b, 0.22 * fade))
	match kind:
		"sun":
			for i in 8:
				var a: float = _time * 0.9 + TAU * float(i) / 8.0
				draw_line(
					origin + Vector2(cos(a), sin(a)) * 8.0,
					origin + Vector2(cos(a), sin(a)) * 16.0,
					Color(c.r, c.g, c.b, fade),
					3.0,
					true
				)
			draw_circle(origin, 6.0, Color(1, 1, 1, fade))
		"frost":
			for i in 3:
				var a: float = _time * 0.6 + PI * float(i) / 3.0
				draw_line(origin - Vector2(cos(a), sin(a)) * 15.0, origin + Vector2(cos(a), sin(a)) * 15.0, Color(c.r, c.g, c.b, fade), 2.6, true)
			draw_circle(origin, 4.5, Color(1, 1, 1, fade))
		_:
			var zig := PackedVector2Array([
				origin + Vector2(-15, 6), origin + Vector2(-4, -8),
				origin + Vector2(4, 5), origin + Vector2(15, -7),
			])
			draw_polyline(zig, Color(c.r, c.g, c.b, fade), 3.0, true)