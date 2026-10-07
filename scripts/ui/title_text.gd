class_name TitleText
extends Control

## Display-Text mit manueller Laufweite (Tracking), optionalem Verlauf,
## Outline, Schatten und weichem Glow.
##
## Godots Standard-Label kann keine Laufweite setzen. Fuer Logo, Levelnamen und
## Button-Beschriftungen sieht getrackte Grossschrift aber deutlich
## professioneller aus, also wird hier zeichenweise gezeichnet.

var text: String = "":
	set(value):
		if text == value:
			return
		text = value
		_measure()
		update_minimum_size()
		queue_redraw()

var font: Font = load("res://assets/fonts/InterDisplay-Bold.otf")
var font_size: int = 44
var tracking: float = 4.0
var color: Color = Palette.TEXT
var color_end: Color = Color(0, 0, 0, 0)
var glow: Color = Color(0, 0, 0, 0)
var shadow_offset: Vector2 = Vector2(0.0, 5.0)
var outline: int = 0
var outline_color: Color = Color(0.02, 0.03, 0.06, 0.92)

var _advance: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _measure() -> void:
	_advance = PackedFloat32Array()
	_total = 0.0
	if font == null:
		return
	for i in text.length():
		var ch: String = text[i]
		var w: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_advance.append(w)
		_total += w
	if _advance.size() > 0:
		_total += tracking * float(_advance.size() - 1)


func _get_minimum_size() -> Vector2:
	return Vector2(_total + 10.0, float(font_size) * 1.32)


func _draw() -> void:
	if text.is_empty() or _advance.is_empty() or font == null:
		return

	var ascent: float = font.get_ascent(font_size)
	var baseline: float = size.y * 0.5 + ascent * 0.5 - float(font_size) * 0.055
	var x: float = (size.x - _total) * 0.5
	var use_gradient: bool = color_end.a > 0.0

	if glow.a > 0.0:
		var gx: float = x
		for i in text.length():
			var ch: String = text[i]
			var low: Color = Color(glow.r, glow.g, glow.b, glow.a * 0.30)
			draw_string(font, Vector2(gx - 1.5, baseline - 1.5), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, low)
			draw_string(font, Vector2(gx + 1.5, baseline + 1.5), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, low)
			gx += _advance[i] + tracking

	if shadow_offset != Vector2.ZERO:
		var sx: float = x
		for i in text.length():
			draw_string(font, Vector2(sx, baseline) + shadow_offset, text[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.01, 0.02, 0.05, 0.6))
			sx += _advance[i] + tracking

	var cx: float = x
	for i in text.length():
		var ch: String = text[i]
		var col: Color = color
		if use_gradient:
			var k: float = 0.0 if _total <= 0.0 else (cx - x) / _total
			col = color.lerp(color_end, k)
		if outline > 0:
			draw_string_outline(font, Vector2(cx, baseline), ch,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, outline_color)
		draw_string(font, Vector2(cx, baseline), ch,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		cx += _advance[i] + tracking