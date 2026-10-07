class_name StatBar
extends Control

## Schlanke Statusleiste mit Beschriftung, Fuellung und optionalen Segmenten.
## Wird fuer Fortschritt (Schatten) und Restzeit verwendet.

var caption: String = ""
var value_text: String = ""
var fill: float = 0.0
var fill_color: Color = Palette.MINT
var track_color: Color = Color(1, 1, 1, 0.09)
var segments: int = 0
var danger: bool = false

const BAR_HEIGHT := 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_fill(value: float) -> void:
	fill = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	var font: Font = Fonts.SEMIBOLD
	var font_size: int = Palette.FONT_CHIP
	var ascent: float = font.get_ascent(font_size)
	var baseline: float = ascent + 2.0

	draw_string(font, Vector2(0, baseline), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.TEXT_DIM)
	draw_string(font, Vector2(0.0, baseline), value_text, HORIZONTAL_ALIGNMENT_RIGHT, w, font_size, Palette.TEXT)

	var top: float = baseline + 8.0
	var bar_h: float = minf(BAR_HEIGHT, maxf(6.0, h - top))
	var radius: float = bar_h * 0.5

	_rounded(Rect2(0.0, top, w, bar_h), radius, track_color)

	var width: float = w * fill
	if width > 1.0:
		var color: Color = fill_color
		if danger:
			color = fill_color.lerp(Palette.CRIMSON, clampf((0.35 - fill) / 0.35, 0.0, 1.0))
		_rounded(Rect2(0.0, top, width, bar_h), radius, color)
		# Heller Rand an der Fuellkante macht den Fortschritt deutlicher.
		draw_rect(Rect2(maxf(0.0, width - 3.0), top, 3.0, bar_h), Color(1, 1, 1, 0.55), true)

	if segments > 1:
		for i in range(1, segments):
			var x: float = w * float(i) / float(segments)
			draw_rect(Rect2(x, top, 1.5, bar_h), Color(0.02, 0.03, 0.06, 0.55), true)

	draw_rect(Rect2(0.0, top, w, bar_h), Color(1, 1, 1, 0.14), false, 1.5)


func _rounded(rect: Rect2, radius: float, color: Color) -> void:
	if radius <= 0.5:
		draw_rect(rect, color, true)
		return
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, rect.size.y), color, true)
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)