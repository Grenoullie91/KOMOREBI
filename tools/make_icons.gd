extends SceneTree

## Erzeugt die Android-Icon-Dateien aus den SVG-Quellen.
##
## Godot ist der einzige SVG-Rasterizer, der auf diesem Host verlässlich
## verfügbar ist: die Farbverläufe in `icon.svg` brauchen einen echten Renderer,
## und genau den liefert der eigene Import. Deshalb werden die fertigen PNGs
## hiermit erzeugt statt mit einem externen Werkzeug.
##
## Aufruf (setzt einen vorherigen `--import` voraus, damit die SVGs als
## Textur importiert sind):
##   flatpak run org.godotengine.Godot --headless --path . --import
##   flatpak run org.godotengine.Godot --headless --path . \
##       --script res://tools/make_icons.gd

##Quelle -> Ziel, alle Pfade relativ zum Projekt.
const JOBS := [
	["res://icon.svg", "res://assets/icons/launcher_192.png", Vector2i(192, 192)],
	["res://icon.svg", "res://store/icon-512.png", Vector2i(512, 512)],
	["res://tools/icons/adaptive_foreground.svg", "res://assets/icons/adaptive_foreground_432.png", Vector2i(432, 432)],
	["res://tools/icons/adaptive_background.svg", "res://assets/icons/adaptive_background_432.png", Vector2i(432, 432)],
	# Boot-Splash: nur die Figur auf transparentem Grund. Godot legt
	# `boot_splash/bg_color` dahinter - mit eigenem Hintergrund waere ein
	# zweiter, abweichender Nachtblau-Ton sichtbar.
	["res://tools/icons/adaptive_foreground.svg", "res://assets/icons/splash_512.png", Vector2i(512, 512)],
]

var _failed: int = 0


func _init() -> void:
	for job in JOBS:
		_render(job[0], job[1], job[2])
	if _failed > 0:
		push_error("[icons] %d Datei(en) nicht erzeugt" % _failed)
		quit(1)
		return
	print("[icons] alle Icon-Dateien erzeugt")
	quit(0)


func _render(source: String, target: String, size: Vector2i) -> void:
	var texture := load(source) as Texture2D
	if texture == null:
		fail("%s nicht importiert" % source)
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		fail("%s liefert kein Bild" % source)
		return
	# Der Import liefert je nach Kompression ein komprimiertes Format; PNG
	# kann nur unkomprimierte Formate schreiben.
	if image.is_compressed() and image.decompress() != OK:
		fail("%s konnte nicht entpackt werden" % source)
		return
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)

	var absolute := ProjectSettings.globalize_path(target)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if image.save_png(absolute) != OK:
		fail("%s nicht speicherbar" % target)
		return
	print("[icons] %s -> %s (%dx%d)" % [source, target, size.x, size.y])


func fail(message: String) -> void:
	_failed += 1
	push_error("[icons] %s" % message)