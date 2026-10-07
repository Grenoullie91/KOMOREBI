class_name Backdrop
extends Control

## Lebender Dämmerungs-Hintergrund: weicher Farbverlauf, warmer Horizont,
## langsam wandernde Lichtschächte, aufsteigende Staubpartikel, eine
## Baum-Silhouette am unteren Rand und eine Vignette.
##
## Verlauf und Horizontglühen werden als GradientTexturen gezeichnet statt
## als viele Einzelbaender - das eliminiert die sichtbaren Stufen, die
## sonst entstehen, und ist auf dem Emulator zusaetzlich billiger.

const MOTE_COUNT := 44
## Stuetzstellen des Sinusprofils im Lichtschaft (siehe _draw_shafts).
const SHAFT_SLICES := 16
const TREE_COUNT := 7

var top_color: Color = Palette.NIGHT
var bottom_color: Color = Palette.HORIZON
var shaft_color: Color = Palette.AMBER
var mote_color: Color = Palette.GOLD
var intensity: float = 1.0
var animate: bool = true

## Der Hintergrund wird mit 30 Hz neu gezeichnet, nicht mit der
## Bildfrequenz. Er bewegt sich sehr langsam (Schwanken im Sekundentakt,
## treibende Staubpartikel) - der Unterschied ist unsichtbar, spart aber
## den grössten Teil der Zeichenbefehle: 48 Lichtschacht-Polygone und 88
## Partikelkreise pro Frame waren der Hauptkostenpunkt auf GLES3-Geräten.
const REDRAW_HZ := 30.0

var _time: float = 0.0
var _redraw_accum: float = 0.0
var _motes: Array = []
var _trees: Array = []
var _rng := RandomNumberGenerator.new()
var _gradient: GradientTexture2D
var _glow: GradientTexture2D
var _vignette: GradientTexture2D
var _halo: GradientTexture2D
var _shaft_profile: GradientTexture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_rng.seed = 20261006

	for i in MOTE_COUNT:
		_motes.append({
			"x": _rng.randf(),
			"y": _rng.randf(),
			"r": 1.3 + _rng.randf() * 2.8,
			"speed": 0.006 + _rng.randf() * 0.024,
			"phase": _rng.randf() * TAU,
		})

	for i in TREE_COUNT:
		_trees.append({
			"x": float(i) / float(TREE_COUNT - 1),
			# Breit und flach: die Silhouette ueberlappt zu einer Baumreihe,
			# statt als einzelne Zacken zu lesen.
			"w": 0.26 + _rng.randf() * 0.20,
			"h": 0.018 + _rng.randf() * 0.022,
		})

	_halo = GradientTexture2D.new()
	var halo := Gradient.new()
	halo.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	halo.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.85),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_halo.gradient = halo
	_halo.width = 64
	_halo.height = 64
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1.0, 0.5)

# Weiches Querprofil der Lichtschachte als Textur: der Schacht wird als
	# ein einziges texturiertes Trapez gezeichnet statt als 16 gefuellte
	# Streifen. Die Stuetzstellen sind exakt die Mittelpunkte des alten
	# Sinusprofils - dieselbe Kurve, aber ohne die sichtbaren Stufen und
	# mit einem Zeichenbefehl statt sechzehn.
	_shaft_profile = GradientTexture2D.new()
	var profile := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in SHAFT_SLICES + 1:
		var k: float = float(i) / float(SHAFT_SLICES)
		offsets.append(k)
		var a: float = sin(PI * clampf(k, 0.0, 1.0)) if i > 0 and i < SHAFT_SLICES else 0.0
		colors.append(Color(1.0, 1.0, 1.0, a))
	profile.offsets = offsets
	profile.colors = colors
	_shaft_profile.gradient = profile
	_shaft_profile.width = 64
	_shaft_profile.height = 4
	_shaft_profile.fill_from = Vector2(0.0, 0.0)
	_shaft_profile.fill_to = Vector2(1.0, 0.0)

	_rebuild_textures()
	set_process(animate)


func _process(delta: float) -> void:
	_time += delta
	_redraw_accum += delta
	if _redraw_accum < 1.0 / REDRAW_HZ:
		return
	_redraw_accum = 0.0
	queue_redraw()


## Kapitel-Farbverschiebung: 0 = kuehle Nacht, 1 = warmes Abendrot.
func set_mood(t: float) -> void:
	var k: float = clampf(t, 0.0, 1.0)
	top_color = Palette.NIGHT.lerp(Color("#1b1026"), k)
	bottom_color = Palette.HORIZON.lerp(Color("#421f1c"), k)
	shaft_color = Palette.AMBER.lerp(Color("#ff9a5c"), k)
	mote_color = Palette.GOLD.lerp(Color("#ffd9b0"), k)
	_rebuild_textures()
	queue_redraw()


func _rebuild_textures() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 1.0])
	gradient.colors = PackedColorArray([
		top_color,
		top_color.lerp(bottom_color, 0.35),
		top_color.lerp(bottom_color, 0.78),
		bottom_color,
	])
	_gradient = GradientTexture2D.new()
	_gradient.gradient = gradient
	_gradient.width = 4
	_gradient.height = 256
	_gradient.fill_from = Vector2(0.0, 0.0)
	_gradient.fill_to = Vector2(0.0, 1.0)

	var glow := Gradient.new()
	glow.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	glow.colors = PackedColorArray([
		Color(shaft_color.r, shaft_color.g, shaft_color.b, 0.22),
		Color(shaft_color.r, shaft_color.g, shaft_color.b, 0.08),
		Color(shaft_color.r, shaft_color.g, shaft_color.b, 0.0),
	])
	_glow = GradientTexture2D.new()
	_glow.gradient = glow
	_glow.width = 192
	_glow.height = 192
	_glow.fill = GradientTexture2D.FILL_RADIAL
	_glow.fill_from = Vector2(0.5, 0.5)
	_glow.fill_to = Vector2(1.0, 0.5)

	# Vignette in einem einzigen Zug - keine sichtbaren Stufen.
	var vignette := Gradient.new()
	vignette.offsets = PackedFloat32Array([0.0, 0.55, 0.82, 1.0])
	vignette.colors = PackedColorArray([
		Color(0.01, 0.015, 0.03, 0.0),
		Color(0.01, 0.015, 0.03, 0.0),
		Color(0.01, 0.015, 0.03, 0.14),
		Color(0.01, 0.015, 0.03, 0.46),
	])
	_vignette = GradientTexture2D.new()
	_vignette.gradient = vignette
	_vignette.width = 256
	_vignette.height = 256
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.0, 0.5)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0 or _gradient == null:
		return

	draw_texture_rect(_gradient, Rect2(0.0, 0.0, w, h), false)

	# Warmer Horizont am unteren Rand, radial weich auslaufend.
	var glow_size := Vector2(w * 2.2, h * 0.95)
	draw_texture_rect(
		_glow,
		Rect2(Vector2(-w * 0.6, h - glow_size.y * 0.72), glow_size),
		false,
		Color(1.0, 1.0, 1.0, intensity)
	)

	_draw_shafts(w, h)
	_draw_motes(w, h)
	_draw_treeline(w, h)
	draw_texture_rect(_vignette, Rect2(0.0, 0.0, w, h), false)


## Weicher Lichtschaft: mehrere schmale Streifen mit Sinus-Profil,
## damit die Kante nicht als harte Linie sichtbar wird.
func _draw_shafts(w: float, h: float) -> void:
	for s in 3:
		var base_x: float = w * (0.14 + 0.34 * float(s))
		var sway: float = sin(_time * 0.10 + float(s) * 2.1) * w * 0.05
		var tilt: float = 0.22 + 0.12 * sin(_time * 0.07 + float(s))
		var alpha: float = 0.030 * intensity * (0.65 + 0.35 * sin(_time * 0.21 + float(s) * 1.3))
		var top_w: float = w * 0.06
		var bottom_w: float = w * 0.26
		var color := Color(shaft_color.r, shaft_color.g, shaft_color.b, alpha)
		var bottom_offset: float = tilt * h

		# Ein Trapez mit dem Sinusprofil als Textur - dieselbe Formel wie
		# vorher, nur ohne 16 einzelne Polygone.
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(base_x + sway - top_w * 0.5, -h * 0.05),
				Vector2(base_x + sway + top_w * 0.5, -h * 0.05),
				Vector2(base_x + sway + bottom_offset + bottom_w * 0.5, h * 1.05),
				Vector2(base_x + sway + bottom_offset - bottom_w * 0.5, h * 1.05),
			]),
			color,
			PackedVector2Array([
				Vector2(0.0, 0.0),
				Vector2(1.0, 0.0),
				Vector2(1.0, 1.0),
				Vector2(0.0, 1.0),
			]),
			_shaft_profile
		)


func _draw_motes(w: float, h: float) -> void:
	for mote in _motes:
		var y: float = fposmod(float(mote["y"]) - _time * float(mote["speed"]), 1.0)
		var x: float = fposmod(
			float(mote["x"]) + sin(_time * 0.4 + float(mote["phase"])) * 0.02,
			1.0
		)
		var twinkle: float = 0.45 + 0.55 * sin(_time * 1.7 + float(mote["phase"]))
		var alpha: float = 0.34 * twinkle * intensity
		var color := Color(mote_color.r, mote_color.g, mote_color.b, alpha)
		draw_texture_rect(_halo, Rect2(Vector2(x * w, y * h) - Vector2.ONE * float(mote["r"]) * 2.8, Vector2.ONE * float(mote["r"]) * 5.6), false, Color(color.r, color.g, color.b, alpha * 0.12))
		draw_circle(Vector2(x * w, y * h), float(mote["r"]), color)


## Baum-Silhouette: gibt der Flaeche einen Ort statt reiner Farbe.
func _draw_treeline(w: float, h: float) -> void:
	var base_y: float = h * 1.005
	var color := Color(top_color.r * 0.30, top_color.g * 0.28, top_color.b * 0.40, 0.85)
	for tree in _trees:
		var cx: float = float(tree["x"]) * w + sin(_time * 0.13 + float(tree["x"]) * 9.0) * 3.0
		var tw: float = float(tree["w"]) * w
		var th: float = float(tree["h"]) * h
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(cx - tw * 0.5, base_y + th * 0.4),
				Vector2(cx, base_y - th),
				Vector2(cx + tw * 0.5, base_y + th * 0.4),
			]),
			color
		)
