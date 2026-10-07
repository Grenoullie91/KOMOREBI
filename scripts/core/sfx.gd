class_name Sfx
extends Node

## Prozedurales Sound-Design.
##
## Statt Fremd-Assets werden alle Effekte beim Start aus reinen Funktionen
## in AudioStreamWAV-Puffer gerendert: Sinus-Sweeps, Rauschimpulse und
## Harmonische mit analytischer Phase (damit die Lambda stateless bleibt).
## Ergebnis: ein geschlossenes, konsistentes Sound-Konzept ohne externe
## Abhaengigkeit und ohne Copyright-Fragen.

const RATE := 22050
const VOICES := 12

## Sehr leise Grundlage, damit das Spiel auf dem Lautsprecher nicht clippt.
const MASTER_DB := -5.0

var enabled: bool = true

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _last_play: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)
	_build_library()
	Log.line("AUDIO streams=%d rate=%d enabled=1" % [_streams.size(), RATE])


func set_enabled(value: bool) -> void:
	enabled = value
	Log.line("AUDIO enabled=%s" % ("1" if enabled else "0"))


# ----------------------------------------------------------------- Library --

func _build_library() -> void:
	_streams["ui"] = _render(0.10, func(t: float, k: float) -> float:
		return _sweep(t, k, 720.0, 1180.0) * 0.32 * _decay(k, 8.0)
	)

	_streams["hit"] = _render(0.13, func(t: float, k: float) -> float:
		var tone := _sweep(t, k, 1500.0, 380.0) * 0.30 * _decay(k, 7.0)
		var grit := _noise(t) * 0.16 * _decay(k, 22.0)
		return tone + grit
	)

	_streams["kill"] = _render(0.24, func(t: float, k: float) -> float:
		var body := _sweep(t, k, 760.0, 150.0) * 0.34 * _decay(k, 5.0)
		var edge := _noise(t) * 0.20 * _decay(k, 13.0)
		return body + edge
	)

	_streams["crit"] = _render(0.34, func(t: float, k: float) -> float:
		var a := _sweep(t, k, 1500.0, 260.0) * 0.30 * _decay(k, 4.0)
		var b := _sweep(t, k, 2250.0, 480.0) * 0.14 * _decay(k, 6.0)
		var spark := _noise(t) * 0.14 * _decay(k, 16.0)
		return a + b + spark
	)

	_streams["explode"] = _render(0.52, func(t: float, k: float) -> float:
		var boom := _sweep(t, k, 130.0, 42.0) * 0.42 * _decay(k, 3.2)
		var dust := _noise(t) * 0.30 * _decay(k, 7.0) * (1.0 - 0.5 * k)
		var crack := _noise(t * 2.7) * 0.16 * _decay(k, 20.0)
		return boom + dust + crack
	)

	_streams["shatter"] = _render(0.34, func(t: float, k: float) -> float:
		var sum := 0.0
		var base := 1850.0
		for i in 3:
			var offset: float = float(i) * 0.035
			var lk: float = clampf((t - offset) / 0.16, 0.0, 1.0)
			if t < offset:
				continue
			sum += sin(TAU * base * float(i + 1) * 1.13 * t) * 0.16 * _decay(lk, 9.0)
		var dust := _noise(t) * 0.10 * _decay(k, 12.0)
		return sum + dust
	)

	_streams["combo"] = _render(0.20, func(t: float, k: float) -> float:
		var f: float = 1040.0 if k < 0.4 else 1560.0
		return _sweep(t, k, f, f * 1.06) * 0.26 * _decay(k, 6.5)
	)

	_streams["multi"] = _render(0.30, func(t: float, k: float) -> float:
		var f: float = 880.0 if k < 0.33 else (1174.0 if k < 0.66 else 1568.0)
		return _sweep(t, k, f, f) * 0.26 * _decay(k, 4.5)
	)

	_streams["power"] = _render(0.46, func(t: float, k: float) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var idx: int = clampi(int(k * 4.0), 0, 3)
		var local: float = fposmod(k * 4.0, 1.0)
		var f: float = float(notes[idx])
		var tone := _sweep(t, k, f, f) * 0.26 * _decay(local, 5.0)
		return tone + _noise(t) * 0.04 * _decay(k, 18.0)
	)

	_streams["miss"] = _render(0.18, func(t: float, k: float) -> float:
		return _sweep(t, k, 240.0, 110.0) * 0.20 * _decay(k, 6.0)
	)

	_streams["whoosh"] = _render(0.46, func(t: float, k: float) -> float:
		var swell: float = sin(PI * k)
		return _noise(t * 0.7 + k * 3.0) * 0.16 * swell
	)

	_streams["charge"] = _render(0.90, func(t: float, k: float) -> float:
		var swell: float = sin(PI * pow(k, 0.8))
		var body := _sweep(t, k, 120.0, 900.0) * 0.18 * swell
		return body + _noise(t * 0.5 + k) * 0.10 * swell
	)

	_streams["star"] = _render(0.42, func(t: float, k: float) -> float:
		var notes := [783.99, 987.77, 1318.5]
		var idx: int = clampi(int(k * 3.0), 0, 2)
		var local: float = fposmod(k * 3.0, 1.0)
		var f: float = float(notes[idx])
		return _sweep(t, k, f, f) * 0.24 * _decay(local, 5.0)
	)

	_streams["win"] = _render(1.40, func(t: float, k: float) -> float:
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var idx: int = clampi(int(k * 4.0), 0, 3)
		var local: float = fposmod(k * 4.0, 1.0)
		var f: float = float(notes[idx])
		var lead := _sweep(t, k, f, f) * 0.24 * _decay(local, 2.6)
		var fifth := _sweep(t, k, f * 1.5, f * 1.5) * 0.10 * _decay(local, 3.4)
		var pad := sin(TAU * 261.63 * t) * 0.06 * (1.0 - k)
		return lead + fifth + pad
	)

	_streams["lose"] = _render(1.30, func(t: float, k: float) -> float:
		var notes := [392.0, 329.63, 261.63, 196.0]
		var idx: int = clampi(int(k * 4.0), 0, 3)
		var local: float = fposmod(k * 4.0, 1.0)
		var f: float = float(notes[idx])
		var lead := _sweep(t, k, f, f * 0.995) * 0.24 * _decay(local, 2.2)
		var pad := sin(TAU * 130.81 * t) * 0.07 * (1.0 - k * 0.6)
		return lead + pad
	)


# -------------------------------------------------------------- Primitive --

## Phasenintegrierter Linear-Sweep - bewusst analytisch, damit die
## Erzeugungsfunktion keinen Zustand mitfuehren muss.
static func _sweep(t: float, k: float, f0: float, f1: float) -> float:
	var dur: float = maxf(k, 0.0001)
	var phase: float = TAU * (f0 * t + (f1 - f0) * t * t / (2.0 * dur))
	return sin(phase)


static func _decay(k: float, sharpness: float) -> float:
	return exp(-k * sharpness)


## Deterministisches Rauschen (Hash) - zufaellig, aber reproduzierbar.
static func _noise(t: float) -> float:
	var x: float = sin(t * 12000.0 + 0.5) * 43758.5453
	return (fposmod(x, 1.0) * 2.0) - 1.0


# ---------------------------------------------------------------- Renderer --

func _render(seconds: float, gen: Callable) -> AudioStreamWAV:
	var count: int = maxi(8, int(RATE * seconds))
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t: float = float(i) / float(RATE)
		var k: float = float(i) / float(count)
		var sample: float = clampf(float(gen.call(t, k)), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream


# ------------------------------------------------------------------ Play ---

func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not enabled or not _streams.has(id):
		return
	# Sehr viele identische Ticks in einem Frame klingen unangenehm - drosseln.
	var now: int = Time.get_ticks_msec()
	var last: int = int(_last_play.get(id, -999))
	if id in ["hit", "miss"] and now - last < 45:
		return
	_last_play[id] = now

	var player: AudioStreamPlayer = _voices[_cursor]
	_cursor = (_cursor + 1) % _voices.size()
	player.stream = _streams[id]
	player.volume_db = clampf(volume_db + MASTER_DB, -40.0, 6.0)
	player.pitch_scale = clampf(pitch, 0.4, 2.4)
	player.play()