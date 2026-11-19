extends AudioStreamPlayer
# Гул накаливания: процедурный генератор 50 Гц, яркость ведёт оркестратор сцены.

const MIX_RATE: float = 44100.0
const DB: float = -42.0
const TRIM: float = 2.15

var brightness: float = 1.0

var _playback: AudioStreamGeneratorPlayback
var _gain: float = 0.0
var _env: float = 1.0
var _phase: float = 0.0

func _ready() -> void:
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.4
	stream = gen
	_gain = db_to_linear(DB) * TRIM
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback

# Гул 50 Гц + гармоники, усиление сглаживается против треска
func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames: int = mini(_playback.get_frames_available(), 16384)
	if frames <= 0:
		return
	var k: float = 1.0 - exp(-1.0 / (0.008 * MIX_RATE))
	var buf: PackedVector2Array = PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		_phase += 50.0 / MIX_RATE
		if _phase > 1.0:
			_phase -= 1.0
		var hum: float = sin(TAU * _phase) * 0.6 + sin(TAU * _phase * 2.0) * 0.25 + sin(TAU * _phase * 3.0) * 0.1
		_env = lerpf(_env, brightness, k)
		buf[i] = Vector2.ONE * clampf(hum * _gain * _env, -1.0, 1.0)
	_playback.push_buffer(buf)
