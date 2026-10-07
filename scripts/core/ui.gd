class_name UI
extends RefCounted

## Werkzeugkasten fuer die Oberflaeche: Theme, Stylebox-Fabrik, Buttons,
## Labels und Karten. Die ganze UI wird im Code aufgebaut, damit Typografie,
## Radien, Abstaende und Farben an genau einer Stelle liegen.

# ---------------------------------------------------------------- Stylebox ---

static func flat(
	bg: Color,
	radius: int = Palette.RADIUS,
	border: int = 0,
	border_color: Color = Palette.HAIRLINE,
	margin_h: int = 28,
	margin_v: int = 18
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border
	sb.border_width_top = border
	sb.border_width_right = border
	sb.border_width_bottom = border
	sb.border_color = border_color
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.anti_aliasing = true
	return sb


## Karte / Panel mit weichem Schlagschatten - der Grundton der UI.
static func card(bg: Color = Palette.GLASS, radius: int = Palette.RADIUS_LG) -> StyleBoxFlat:
	var sb := flat(bg, radius, 1, Color(1, 1, 1, 0.07), 0, 0)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	sb.shadow_offset = Vector2(0, 8)
	return sb


# ------------------------------------------------------------------ Theme ---

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.REGULAR
	t.default_font_size = Palette.FONT_BODY

	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("font_outline_color", "Label", Color(0.01, 0.02, 0.05, 0.9))
	t.set_constant("outline_size", "Label", 0)

	var btn := flat(Palette.MINT, Palette.RADIUS, 0, Color(0, 0, 0, 0), 34, 22)
	var btn_hover := flat(Palette.MINT.lightened(0.14), Palette.RADIUS, 0, Color(0, 0, 0, 0), 34, 22)
	var btn_press := flat(Palette.MINT_DEEP, Palette.RADIUS, 0, Color(0, 0, 0, 0), 34, 22)
	var btn_disabled := flat(Color(1, 1, 1, 0.07), Palette.RADIUS, 1, Color(1, 1, 1, 0.10), 34, 22)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", btn_hover)
	t.set_stylebox("pressed", "Button", btn_press)
	t.set_stylebox("disabled", "Button", btn_disabled)
	t.set_stylebox("focus", "Button", flat(Color(0, 0, 0, 0), Palette.RADIUS, 2, Palette.MINT, 34, 22))
	t.set_color("font_color", "Button", Palette.TEXT_DARK)
	t.set_color("font_hover_color", "Button", Palette.TEXT_DARK)
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1, 0.9))
	t.set_color("font_disabled_color", "Button", Palette.TEXT_FAINT)
	t.set_font("font", "Button", Fonts.SEMIBOLD)
	t.set_font_size("font_size", "Button", 30)

	var panel := card()
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", flat(Palette.GLASS, Palette.RADIUS, 1, Color(1, 1, 1, 0.06), 0, 0))

	return t


# ----------------------------------------------------------------- Widgets ---

static func label(
	text: String,
	size: int = Palette.FONT_BODY,
	color: Color = Palette.TEXT,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Fonts.REGULAR)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Label mit Umbruch bei fester Breite.
##
## Godot meldet fuer ein Label mit Autowrap nur eine Zeile als Mindesthoehe,
## weil die Breite erst zur Laufzeit feststeht. Ein Container gibt dem Label
## daraufhin zu wenig Platz - der Text laeuft aus der Karte heraus. Deshalb
## wird die tatsaechliche Umbruchhoehe hier vorher gemessen und als
## Mindestgroesse gesetzt.
static func wrapped(
	text: String,
	width: float,
	size: int = Palette.FONT_BODY - 2,
	color: Color = Palette.TEXT_DIM,
	align: int = HORIZONTAL_ALIGNMENT_LEFT,
	font: Font = null
) -> Label:
	var l := label(text, size, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var used_font: Font = font if font != null else Fonts.REGULAR
	var measured: Vector2 = used_font.get_multiline_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, width, size
	)
	l.custom_minimum_size = Vector2(width, measured.y + 8.0)
	return l


static func strong(
	text: String,
	size: int = Palette.FONT_HEAD,
	color: Color = Palette.TEXT,
	align: int = HORIZONTAL_ALIGNMENT_LEFT
) -> Label:
	var l := label(text, size, color, align)
	l.add_theme_font_override("font", Fonts.SEMIBOLD)
	return l


static func caption(text: String, color: Color = Palette.TEXT_FAINT) -> Label:
	var l := label(text, Palette.FONT_CHIP, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", Fonts.SEMIBOLD)
	return l


static func heading(text: String, size: int = Palette.FONT_HEAD, color: Color = Palette.TEXT) -> TitleText:
	var t := TitleText.new()
	t.text = text
	t.font = Fonts.BOLD
	t.font_size = size
	t.tracking = 2.0
	t.color = color
	t.custom_minimum_size = Vector2(0, float(size) * 1.3)
	return t


## Button in einer von drei Auspraegungen.
## kind: "primary" (Mint), "ghost" (nur Kontur) oder "quiet" (kaum sichtbar).
static func button(text: String, kind: String = "primary", height: int = 92) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, float(height))
	b.add_theme_font_override("font", Fonts.SEMIBOLD)
	b.add_theme_font_size_override("font_size", 28)

	match kind:
		"primary":
			b.add_theme_stylebox_override("normal", flat(Palette.MINT, Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_stylebox_override("hover", flat(Palette.MINT.lightened(0.15), Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_stylebox_override("pressed", flat(Palette.MINT_DEEP, Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_color_override("font_color", Palette.TEXT_DARK)
			b.add_theme_color_override("font_hover_color", Palette.TEXT_DARK)
			b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.95))
		"amber":
			b.add_theme_stylebox_override("normal", flat(Palette.AMBER, Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_stylebox_override("hover", flat(Palette.AMBER.lightened(0.15), Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_stylebox_override("pressed", flat(Palette.AMBER_DEEP, Palette.RADIUS, 0, Color(0, 0, 0, 0), 30, 20))
			b.add_theme_color_override("font_color", Palette.TEXT_DARK)
			b.add_theme_color_override("font_hover_color", Palette.TEXT_DARK)
			b.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.95))
		"ghost":
			b.add_theme_stylebox_override("normal", flat(Color(1, 1, 1, 0.05), Palette.RADIUS, 1, Color(1, 1, 1, 0.16), 30, 20))
			b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.11), Palette.RADIUS, 1, Color(1, 1, 1, 0.26), 30, 20))
			b.add_theme_stylebox_override("pressed", flat(Color(1, 1, 1, 0.16), Palette.RADIUS, 1, Palette.MINT, 30, 20))
			b.add_theme_color_override("font_color", Palette.TEXT)
			b.add_theme_color_override("font_hover_color", Palette.TEXT)
			b.add_theme_color_override("font_pressed_color", Palette.TEXT)
		_:
			b.add_theme_stylebox_override("normal", flat(Color(1, 1, 1, 0.0), Palette.RADIUS_SM, 0, Color(0, 0, 0, 0), 22, 14))
			b.add_theme_stylebox_override("hover", flat(Color(1, 1, 1, 0.08), Palette.RADIUS_SM, 0, Color(0, 0, 0, 0), 22, 14))
			b.add_theme_stylebox_override("pressed", flat(Color(1, 1, 1, 0.14), Palette.RADIUS_SM, 0, Color(0, 0, 0, 0), 22, 14))
			b.add_theme_font_size_override("font_size", 22)
			b.add_theme_color_override("font_color", Palette.TEXT_DIM)
			b.add_theme_color_override("font_hover_color", Palette.TEXT)

	_attach_press_punch(b)
	return b


## Kleiner Stauch-Effekt beim Antippen - haelt die Buttons lebendig.
static func _attach_press_punch(b: Button) -> void:
	b.pivot_offset = Vector2(0, 0)
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func() -> void: _punch_to(b, 0.955, 0.06))
	b.button_up.connect(func() -> void: _punch_to(b, 1.0, 0.16))


static func _punch_to(b: Button, target: float, time: float) -> void:
	var tw := b.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(b, "scale", Vector2.ONE * target, time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func spacer(height: float = 0.0, width: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func hsep(height: float = 10.0) -> Control:
	var c := spacer(height)
	return c


static func rule(color: Color = Palette.HAIRLINE) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", flat(color, 0, 0, Color(0, 0, 0, 0), 0, 0))
	return p


## Karte mit Innenabstand - der Standardcontainer fuer Overlays.
static func card_panel(pad: int = 30, bg: Color = Palette.GLASS) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card(bg, Palette.RADIUS_LG))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", pad)
	m.add_theme_constant_override("margin_right", pad)
	m.add_theme_constant_override("margin_top", pad)
	m.add_theme_constant_override("margin_bottom", pad)
	p.add_child(m)
	return p