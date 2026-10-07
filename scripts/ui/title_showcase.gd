class_name TitleShowcase
extends Control

## Dekoratives Schaufenster fuer den Titelbildschirm: drei Schattenfiguren,
## die langsam durch die Titelflaeche treiben. Sie sind nicht antippbar,
## sondern zeigen nur, worum es im Spiel geht - und fuellen die sonst leere
## Mitte sinnvoll.

const FIGURES := [
	{"kind": Enemy.Kind.SHADE, "radius": 44.0, "speed": 15.0, "phase": 0.0, "y": 0.26, "x": 0.0},
	{"kind": Enemy.Kind.WISP, "radius": 29.0, "speed": -24.0, "phase": 1.1, "y": 0.52, "x": 0.18},
	{"kind": Enemy.Kind.SPLITTER, "radius": 38.0, "speed": 20.0, "phase": 1.6, "y": 0.74, "x": -0.14},
]

var _time: float = 0.0
var _enemies: Array[Enemy] = []
var _alpha: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry in FIGURES:
		var enemy := Enemy.new()
		add_child(enemy)
		enemy.setup(int(entry["kind"]))
		enemy.radius = float(entry["radius"])
		enemy._spawn = 1.0
		_enemies.append(enemy)


func _process(delta: float) -> void:
	_time += delta
	_alpha = minf(1.0, _alpha + delta * 0.9)
	_place()
	queue_redraw()


func _place() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return
	for i in _enemies.size():
		var entry: Dictionary = FIGURES[i]
		var enemy: Enemy = _enemies[i]
		var speed: float = float(entry["speed"])
		var t: float = fposmod(_time * speed * 0.02 + float(entry["phase"]), 2.0)
		var k: float = t - 1.0  # -1 .. 1
		enemy.position = Vector2(
			w * (0.5 + float(entry["x"])) + k * w * 0.30,
			h * float(entry["y"]) + sin(_time * 0.7 + float(entry["phase"])) * h * 0.030
		)
		enemy.velocity = Vector2(sin(_time * 0.5 + float(entry["phase"])) * speed, 0.0)
		enemy.spin = _time * (0.4 + 0.15 * float(i))
		enemy.modulate.a = 0.9


func _draw() -> void:
	# Sanftes Licht unter den Figuren, damit sie nicht im Nichts haengen.
	var glow: Color = Palette.AMBER
	for enemy in _enemies:
		draw_circle(enemy.position, enemy.radius * 1.7, Color(glow.r, glow.g, glow.b, 0.03 * _alpha))