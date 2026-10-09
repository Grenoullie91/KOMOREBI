class_name LicensesScreen
extends AppScreen

## Offline-Lizenzanzeige fuer KOMOREBI und Drittanbieter.

const LICENSE_FILES := [
	{
		"title": "KOMOREBI",
		"subtitle": "MIT License\nCopyright (c) 2026 Grenoullie91",
		"path": "res://LICENSE"
	},
	{
		"title": "INTER FONT",
		"subtitle": "SIL Open Font License 1.1\nInter Project Authors",
		"path": "res://assets/fonts/OFL.txt"
	},
	{
		"title": "GODOT ENGINE",
		"subtitle": "MIT License\nDrittanbieter-Copyrights und Lizenzhinweise",
		"path": "res://GODOT_COPYRIGHT.txt"
	}
]

var _buttons: Dictionary = {}


func _ready() -> void:
	super._ready()

	var column := page(SAFE_TOP, SAFE_BOTTOM)

	column.add_child(UI.caption("OPEN SOURCE"))

	var heading := UI.heading("LIZENZEN & CREDITS", 32, Palette.TEXT)
	column.add_child(heading)

	column.add_child(UI.wrapped(
		"KOMOREBI verwendet freie Software und Bibliotheken. "
		+ "Die vollständigen Lizenztexte sind offline verfügbar.",
		552.0,
		Palette.FONT_BODY,
		Palette.TEXT_DIM
	))

	for entry in LICENSE_FILES:
		var card := UI.card_panel(16, Color(0.04, 0.06, 0.11, 0.65))

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		card.add_child(box)

		var title := UI.heading(String(entry["title"]), 22, Palette.AMBER)
		box.add_child(title)

		box.add_child(UI.wrapped(
			String(entry["subtitle"]),
			500.0,
			Palette.FONT_SMALL,
			Palette.TEXT_DIM
		))

		var button := UI.button("DETAILS ANZEIGEN", "quiet", 48)
		register_button(String(entry["title"]), button)

		var path := String(entry["path"])
		button.pressed.connect(func() -> void:
			show_license(path, String(entry["title"]))
		)

		box.add_child(button)
		column.add_child(card)

		_buttons[entry["title"]] = button

	var back := UI.button("ZURUECK", "primary", 88)
	register_button("back", back)
	back.pressed.connect(func() -> void:
		navigate.emit("title", 0)
	)

	column.add_child(back)
	_buttons["back"] = back


func show_license(path: String, title: String) -> void:
	var text := _read_license(path)

	var popup := AcceptDialog.new()
	popup.title = title
	popup.dialog_text = text
	popup.size = Vector2(600, 700)
	add_child(popup)
	popup.popup_centered()


func _read_license(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Lizenzdatei fehlt:\n" + path

	return FileAccess.get_file_as_string(path)


func on_enter(_arg: int = 0) -> void:
	Log.line("SCREEN=LICENSES")
	log_buttons(_buttons)
	slide_in(self)
