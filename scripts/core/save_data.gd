class_name SaveData
extends RefCounted

## Lokale Persistenz. Keine Cloud, keine Accounts - nur eine ConfigFile
## im user://-Verzeichnis des Geraets.

const PATH := "user://komorebi.cfg"

const MAX_STARS := 3

var best_score: Dictionary = {}      # Level-ID -> int
var stars: Dictionary = {}          # Level-ID -> int (0..3)
var endless_best: int = 0
var unlocked: int = 1
var howto_seen: bool = false
var total_shadows: int = 0
var sfx: bool = true


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		Log.line("SAVE fresh (keine Spieldaten)")
		Log.line("SAVE unlocked=%d endless=%d" % [unlocked, endless_best])
		return
	best_score = cfg.get_value("levels", "best", {})
	stars = cfg.get_value("levels", "stars", {})
	unlocked = int(cfg.get_value("progress", "unlocked", 1))
	endless_best = int(cfg.get_value("endless", "best", 0))
	total_shadows = int(cfg.get_value("progress", "shadows", 0))
	howto_seen = bool(cfg.get_value("options", "howto", false))
	sfx = bool(cfg.get_value("options", "sfx", true))
	if typeof(best_score) != TYPE_DICTIONARY:
		best_score = {}
	if typeof(stars) != TYPE_DICTIONARY:
		stars = {}
	unlocked = clampi(unlocked, 1, 12)
	Log.line("SAVE loaded unlocked=%d endless=%d shadows=%d" % [unlocked, endless_best, total_shadows])
	Log.save_state(self)


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("levels", "best", best_score)
	cfg.set_value("levels", "stars", stars)
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "shadows", total_shadows)
	cfg.set_value("endless", "best", endless_best)
	cfg.set_value("options", "howto", howto_seen)
	cfg.set_value("options", "sfx", sfx)
	cfg.save(PATH)
	Log.save_state(self)


## Ergebnis einer abgeschlossenen Runde einpflegen.
## Gibt die Zahl neu verdienter Sterne zurueck.
func record_level(level_id: int, score: int, earned_stars: int) -> int:
	var prev_best: int = int(best_score.get(str(level_id), 0))
	if score > prev_best:
		best_score[str(level_id)] = score
	var prev_stars: int = int(stars.get(str(level_id), 0))
	var gained: int = maxi(0, earned_stars - prev_stars)
	if earned_stars > prev_stars:
		stars[str(level_id)] = earned_stars
	if earned_stars > 0 and level_id + 1 > unlocked:
		unlocked = mini(level_id + 1, Levels.count() + 1)
	save_to_disk()
	return gained


func record_endless(score: int) -> bool:
	var is_record: bool = score > endless_best
	if is_record:
		endless_best = score
	save_to_disk()
	return is_record


func level_best(level_id: int) -> int:
	return int(best_score.get(str(level_id), 0))


func level_stars(level_id: int) -> int:
	return int(stars.get(str(level_id), 0))


func is_unlocked(level_id: int) -> bool:
	return level_id <= unlocked


func total_stars() -> int:
	var sum: int = 0
	for key in stars:
		sum += int(stars[key])
	return sum


## Sterne fuer einen Score, basierend auf den Schwellen des Levels.
static func stars_for(level: Dictionary, score: int) -> int:
	var thresholds: Array = level.get("stars", [0, 0, 0])
	var result: int = 0
	for threshold in thresholds:
		if score >= int(threshold):
			result += 1
	return clampi(result, 0, MAX_STARS)