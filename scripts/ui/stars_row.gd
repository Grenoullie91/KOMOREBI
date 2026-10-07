class_name StarsRow
extends Control

## Drei Sterne als Bewertung. Gefuellte Sterne wachsen gestaffelt ein,
## leere bleiben als Kontur stehen - so ist auch der "noch nicht verdient"
## -Zustand klar ablesbar.
##
## Die Zeichnung richtet sich nach der tatsaechlichen Breite des Controls und
## skaliert herunter, falls zu wenig Platz ist. Dadurch kann die Zeile in
## jedem Container (Karte, Auswahlliste) ohne Sonderfaelle sitzen.

signal animation_finished()

var total: int = SaveData.MAX_STARS
var filled: int = 0
var animate: bool = true
var star_size: float = 62.0
var gap: float = 20.0

var _time: float = 0.0
var _progress: Array[float] = [0.0, 0.0, 0.0]
var _done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.resize(total)
	_progress.fill(0.0)
	refresh_minimum_size()


func refresh_minimum_size() -> void:
	custom_minimum_size = Vector2(
		total * star_size + maxf(0.0, float(total - 1)) * gap,
		star_size * 1.2
	)
	queue_redraw()


func set_result(count: int, animate_stars: bool = true) -> void:
	filled = clampi(count, 0, total)
	animate = animate_stars
	_time = 0.0
	if not animate:
		for i in total:
			_progress[i] = 1.0 if i < filled else 0.0
		_done = true
		queue_redraw()
		return
	_done = false
	queue_redraw()


func _process(delta: float) -> void:
	if _done or not animate:
		return
	_time += delta
	var all_done: bool = true
	for i in total:
		var delay: float = 0.28 * float(i)
		if _time < delay:
			all_done = false
			continue
		var local: float = clampf((_time - delay) / 0.42, 0.0, 1.0)
		# Kleiner Rueckprall macht das Einsetzen satt.
		var overshoot: float = 1.0 + 0.26 * sin(PI * local) * (1.0 - local * 0.4)
		var target: float = 1.0 if i < filled else 0.0
		_progress[i] = lerpf(_progress[i], target, clampf(delta * 12.0, 0.0, 1.0))
		if not is_equal_approx(_progress[i], target):
			all_done = false
		elif local < 1.0 and target > 0.0:
			all_done = false
	if all_done:
		_done = true
		animation_finished.emit()
	queue_redraw()


## Einfach gehalten: gleiche Zellen fuer jeden Stern, Mittelpunkt der Zelle als
## Mittelpunkt des Sterns. Kein Nachrechnen von Breiten - damit sitzt die
## Zeile in jedem Container exakt mittig.
func _draw() -> void:
	if total <= 0 or size.x <= 0.0:
		return
	var cell: float = minf(size.x / float(total), star_size + gap)
	var radius: float = cell * 0.40
	var row_width: float = cell * float(total)
	var x: float = (size.x - row_width) * 0.5
	var center_y: float = size.y * 0.5

	for i in total:
		var progress: float = clampf(_progress[i], 0.0, 1.0)
		var bounce: float = 1.0 + 0.18 * sin(PI * progress) * (1.0 - progress) if i < filled else 1.0
		_draw_star(
			Vector2(x + cell * 0.5, center_y),
			radius * bounce,
			i < filled,
			progress
		)
		x += cell


## Zehn Punkte eines fuenfzackigen Sterns, bereits um `center` verschoben.
## Wichtig: die Punkte werden hier vollstaendig positioniert - ohne diesen
## Versatz landen alle Sterne uebereinander im Ursprung.
func _star_points(center: Vector2, radius: float, inner_ratio: float = 0.46) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var angle: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = radius if i % 2 == 0 else radius * inner_ratio
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


func _draw_star(center: Vector2, radius: float, lit: bool, amount: float) -> void:
	if radius <= 1.0:
		return
	if lit:
		var fill_amount: float = clampf(amount, 0.0, 1.0)
		# Der Kern waechst von innen nach aussen - so faellt das Einsetzen auf.
		draw_colored_polygon(_star_points(center, radius * (0.30 + 0.70 * fill_amount)), Palette.AMBER)
		if fill_amount > 0.5:
			draw_colored_polygon(_star_points(center, radius * (0.10 + 0.52 * fill_amount)), Palette.GOLD)
	else:
		draw_colored_polygon(_star_points(center, radius), Color(1, 1, 1, 0.10))

	var outline_points := _star_points(center, radius)
	var closed := PackedVector2Array(outline_points)
	closed.append(outline_points[0])
	# Konturfarbe explizit bestimmen - eine Bedingung direkt als Argument ist
	# fehleranfaellig und hat die leeren Sterne unauffaellig bleiben lassen.
	var outline := Color(1, 1, 1, 0.38)
	if lit:
		outline = Color(1, 1, 1, 0.85)
	draw_polyline(closed, outline, 2.0, true)
