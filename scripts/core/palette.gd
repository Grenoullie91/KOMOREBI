class_name Palette
extends RefCounted

## Zentrale Farb- und Typo-Werte fuer "KOMOREBI".
##
## Die Stimmung ist eine Daemmerungs-Waldlichtung: tiefes Blau-Violett als
## Grund, warmes Bernstein-Licht (Komorebi) als Ziel-Farbe, kaltes Mint fuer
## UI und Positive Feedback. Alles ist bewusst auf einen kleinen, klaren
## Satz von Farben reduziert, damit das Bild konsistent bleibt.

# --- Grundtoene -------------------------------------------------------------
const INK := Color("#05070d")
const NIGHT := Color("#0b0f1c")
const DUSK := Color("#141a2b")
const HORIZON := Color("#2a1c24")
const GLASS := Color("#111726")
const MIST := Color("#232c42")
const HAIRLINE := Color(1.0, 1.0, 1.0, 0.10)

# --- Text -------------------------------------------------------------------
const TEXT := Color("#eef2fa")
const TEXT_DIM := Color("#93a0bb")
const TEXT_FAINT := Color("#5f6b85")
const TEXT_DARK := Color("#08110f")

# --- Signalfarben -----------------------------------------------------------
const AMBER := Color("#ffc46b")
const AMBER_DEEP := Color("#ff8f3c")
const MINT := Color("#5fe9c0")
const MINT_DEEP := Color("#25b78f")
const CYAN := Color("#63d8ff")
const VIOLET := Color("#a98bff")
const MAGENTA := Color("#ff5fa2")
const CRIMSON := Color("#ff5b5b")
const GOLD := Color("#ffe9a8")

# --- Gegner -----------------------------------------------------------------
## Kern ist immer dunkel, damit Silhouetten auf dem Nachtgrund lesbar bleiben.
const SHADE_CORE := Color("#120c22")
const SHADE_RIM := Color("#7d6bff")
const WISP_CORE := Color("#1c1024")
const WISP_RIM := Color("#ffb347")
const SPLIT_CORE := Color("#1a0f26")
const SPLIT_RIM := Color("#ff5fa2")
const ARMOR_CORE := Color("#0f1622")
const ARMOR_RIM := Color("#63d8ff")
const BOSS_CORE := Color("#1b0b1e")
const BOSS_RIM := Color("#ff4f7d")

# --- Typografie -------------------------------------------------------------
const FONT_BODY := 26
const FONT_SMALL := 20
const FONT_CHIP := 18
const FONT_HEAD := 34
const FONT_DISPLAY := 44
const FONT_HERO := 58

# --- Raster -----------------------------------------------------------------
const RADIUS := 22
const RADIUS_SM := 12
const RADIUS_LG := 34