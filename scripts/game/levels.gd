class_name Levels
extends RefCounted

## Leveltabelle des Kampagnenmodus.
##
## Acht Kapitel plus Endlos-Modus. Die Kurve ist bewusst stufenweise:
## erst eine reine Klick Mechanik, dann Bewegung, dann Zerfalls- und
## Kettenreaktionen, dann Panzerung, dann Bosse. Jedes Kapitel hat eine
## Soll-Zahl an Schatten und drei Score-Schwellen fuer Sterne.

static func list() -> Array:
	return [
		{
			"id": 1,
			"name": "ERSTER SCHEIN",
			"sub": "Light finds the dark",
			"mood": 0.05,
			"quota": 14,
			"time": 45.0,
			"spawn_start": 1.15,
			"spawn_end": 0.80,
			"max_alive": 7,
			"weights": {"shade": 10, "wisp": 0, "splitter": 0, "bulwark": 0, "shard": 0},
			"stars": [150, 340, 600],
			"tip": "Tippe die Schatten, bevor sie dich erreichen.",
		},
		{
			"id": 2,
			"name": "GLUTFLUG",
			"sub": "Wisp fire drifts",
			"mood": 0.16,
			"quota": 20,
			"time": 45.0,
			"spawn_start": 1.05,
			"spawn_end": 0.72,
			"max_alive": 8,
			"weights": {"shade": 9, "wisp": 4, "splitter": 0, "bulwark": 0, "shard": 0},
			"stars": [340, 640, 1000],
			"tip": "Funken huschen - warte den Moment ab.",
		},
		{
			"id": 3,
			"name": "SPLITTERNEBEL",
			"sub": "One becomes three",
			"mood": 0.30,
			"quota": 22,
			"time": 45.0,
			"spawn_start": 1.00,
			"spawn_end": 0.66,
			"max_alive": 9,
			"weights": {"shade": 8, "wisp": 3, "splitter": 4, "bulwark": 0, "shard": 0},
			"stars": [400, 760, 1200],
			"tip": "Splitter zerfallen in Scherben - zähle weiter.",
		},
		{
			"id": 4,
			"name": "PANZERLICHT",
			"sub": "Plates must break",
			"mood": 0.44,
			"quota": 24,
			"time": 45.0,
			"spawn_start": 0.95,
			"spawn_end": 0.64,
			"max_alive": 10,
			"weights": {"shade": 7, "wisp": 3, "splitter": 4, "bulwark": 4, "shard": 0},
			"stars": [460, 880, 1400],
			"tip": "Panzer brauchen drei Treffer und sprengen ihre Nachbarn.",
		},
		{
			"id": 5,
			"name": "DAEMMERUNG",
			"sub": "The treeline moves",
			"mood": 0.58,
			"quota": 28,
			"time": 48.0,
			"spawn_start": 0.85,
			"spawn_end": 0.54,
			"max_alive": 12,
			"weights": {"shade": 6, "wisp": 4, "splitter": 5, "bulwark": 5, "shard": 0},
			"stars": [560, 1080, 1700],
			"tip": "Die Wiese wird eng - Halte den Multiplikator hoch.",
		},
		{
			"id": 6,
			"name": "KAGURA",
			"sub": "The dance begins",
			"mood": 0.72,
			"quota": 18,
			"time": 55.0,
			"spawn_start": 0.90,
			"spawn_end": 0.60,
			"max_alive": 9,
			"boss": true,
			"boss_hp": 6,
			"weights": {"shade": 8, "wisp": 4, "splitter": 4, "bulwark": 3, "shard": 0},
			"stars": [620, 1200, 1900],
			"tip": "Streue die Schatten, dann trifft die große Finsternis.",
		},
		{
			"id": 7,
			"name": "NEBELSTURM",
			"sub": "No horizon left",
			"mood": 0.86,
			"quota": 32,
			"time": 48.0,
			"spawn_start": 0.78,
			"spawn_end": 0.46,
			"max_alive": 14,
			"weights": {"shade": 6, "wisp": 5, "splitter": 6, "bulwark": 5, "shard": 0},
			"stars": [700, 1350, 2100],
			"tip": "Nichts bleibt lange stehen - tippe im Takt.",
		},
		{
			"id": 8,
			"name": "GROSSER SCHATTEN",
			"sub": "End of the clearing",
			"mood": 1.0,
			"quota": 22,
			"time": 60.0,
			"spawn_start": 0.82,
			"spawn_end": 0.52,
			"max_alive": 12,
			"boss": true,
			"boss_hp": 8,
			"weights": {"shade": 6, "wisp": 5, "splitter": 6, "bulwark": 6, "shard": 0},
			"stars": [780, 1500, 2400],
			"tip": "Acht Kerzen im Kern. Bring sie alle zum Erlöschen.",
		},
	]


static func count() -> int:
	return list().size()


static func get_level(id: int) -> Dictionary:
	for entry in list():
		if int(entry["id"]) == id:
			return entry
	return list()[0]


static func next_id(id: int) -> int:
	var entries := list()
	for index in range(entries.size()):
		if int(entries[index]["id"]) == id:
			return int(entries[index + 1]["id"]) if index + 1 < entries.size() else 0
	return 0


## Gegnergewichtung inkl. späterer Härtung.
static func weighted_kind(weights: Dictionary, intensity: float) -> String:
	var total: float = 0.0
	for key in weights:
		var weight: float = float(weights[key])
		# Splitter werden mit der Zeit seltener, Panzer haeufiger.
		if key == "splitter":
			weight *= lerpf(1.0, 0.75, intensity)
		elif key == "bulwark":
			weight *= lerpf(0.55, 1.25, intensity)
		elif key == "wisp":
			weight *= lerpf(0.7, 1.35, intensity)
		total += weight
	if total <= 0.0:
		return "shade"
	var roll: float = randf() * total
	for key in weights:
		var weight: float = float(weights[key])
		if key == "splitter":
			weight *= lerpf(1.0, 0.75, intensity)
		elif key == "bulwark":
			weight *= lerpf(0.55, 1.25, intensity)
		elif key == "wisp":
			weight *= lerpf(0.7, 1.35, intensity)
		roll -= weight
		if roll <= 0.0:
			return String(key)
	return "shade"


## Endlos-Modus: Wellen, die immer schneller spawnen.
static func endless_spawn_interval(elapsed: float, duration: float) -> float:
	var k: float = clampf(elapsed / maxf(1.0, duration), 0.0, 1.0)
	return lerpf(0.95, 0.24, pow(k, 0.85))


static func endless_weights(elapsed: float, duration: float) -> Dictionary:
	var k: float = clampf(elapsed / maxf(1.0, duration), 0.0, 1.0)
	return {
		"shade": lerpf(10.0, 4.0, k),
		"wisp": lerpf(1.0, 6.0, k),
		"splitter": lerpf(0.0, 7.0, minf(1.0, k * 1.6)),
		"bulwark": lerpf(0.0, 6.0, maxf(0.0, k * 1.4 - 0.25)),
		"shard": 0,
	}

## Synthetische Level-Beschreibung des Endlos-Modus.
static func endless_level() -> Dictionary:
	return {
		"id": 0,
		"name": "ENDLOS",
		"sub": "So long as the light holds",
		"mood": 0.5,
		"quota": 0,
		"time": 60.0,
		"spawn_start": 0.95,
		"spawn_end": 0.24,
		"max_alive": 14,
		"weights": {"shade": 10, "wisp": 1, "splitter": 0, "bulwark": 0, "shard": 0},
		"stars": [0, 0, 0],
		"tip": "Sechzig Sekunden. So viele Schatten wie möglich.",
	}
