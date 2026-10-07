class_name Log
extends RefCounted

## Einheitliche Logcat-Schnittstelle.
##
## Alle Spielereignisse gehen mit dem Praefix "[Game]" hinaus. Das ist bewusst
## die Schnittstelle, ueber die der automatisierte Test verifiziert - unabhaengig
## vom Bild also ein echter Doppelcheck. Viewport-Koordinaten werden dabei auf
## echte Display-Pixel umgerechnet, damit ADB-Taps ohne Umrechnung passen.

const PREFIX := "[Game]"


static func line(text: String) -> void:
	print(PREFIX + " " + text)


## Skalierung Viewport (Godot-Basis) -> Display-Pixel des Geraets.
static func viewport_scale() -> Vector2:
	var window_size := Vector2(DisplayServer.window_get_size())
	var viewport_size: Vector2 = Engine.get_main_loop().get_root().get_viewport().get_visible_rect().size
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector2.ONE
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Vector2.ONE
	return Vector2(window_size.x / viewport_size.x, window_size.y / viewport_size.y)


## Viewport-Punkt (Canvas-Koordinaten) -> echte Pixel.
static func point_px(viewport_point: Vector2) -> Vector2:
	return viewport_point * viewport_scale()


## Mittelpunkt eines Controls in echten Pixeln.
static func control_px(control: Control) -> Vector2:
	return point_px(control.get_global_rect().get_center())


## Debug-Meldung fuer einen antippbaren Knopf.
static func button(id: String, control: Control) -> void:
	line("BTN id=%s px=(%.1f, %.1f)" % [id, control_px(control).x, control_px(control).y])


## Loggt den kompletten Persistenzstand - damit der automatisierte Test
## den Zustand nach einem Neustart verifizieren kann.
static func save_state(data: SaveData) -> void:
	var per_level: PackedStringArray = PackedStringArray()
	for level_id in range(1, Levels.count() + 1):
		per_level.append("l%d=%d/%d" % [
			level_id, data.level_best(level_id), data.level_stars(level_id)
		])
	line("SAVE_STATE unlocked=%d endless=%d stars_total=%d shadows=%d sfx=%s per=[%s]" % [
		data.unlocked,
		data.endless_best,
		data.total_stars(),
		data.total_shadows,
		"1" if data.sfx else "0",
		" ".join(per_level),
	])


## Formatierter Punkt fuer Logzeilen.
static func px_str(viewport_point: Vector2) -> String:
	var p := point_px(viewport_point)
	return "px=(%.1f, %.1f)" % [p.x, p.y]