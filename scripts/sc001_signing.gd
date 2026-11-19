extends Node3D
# SC-001 «Подписание»: обзор мышью, постукивание, мерцание лампы, fade-in.

const YAW_LIMIT: float = 35.0
const PITCH_LIMIT: float = 15.0
const BASE_PITCH: float = -12.0
const SENSITIVITY: float = 0.08
const SMOOTH: float = 8.0
const IDLE_HINT_TIME: float = 16.0
const MIX_RATE: float = 44100.0
const HUM_DB: float = -42.0
const HUM_TRIM: float = 2.15
const TAPS: Array[AudioStream] = [
	preload("res://audio/SFX_foley_finger_tap_01.wav"),
	preload("res://audio/SFX_foley_finger_tap_02.wav"),
	preload("res://audio/SFX_foley_finger_tap_03.wav"),
]

@onready var camera: Camera3D = $Camera3D
@onready var finger: Node3D = $Somov/Finger
@onready var lamp: SpotLight3D = $Lamp/SpotLight3D
@onready var fade: ColorRect = $FadeLayer/ColorRect

var target_yaw: float = 0.0
var target_pitch: float = 0.0
var cur_yaw: float = 0.0
var cur_pitch: float = 0.0
var idle_time: float = 0.0
var tap_timer: float = 4.5
var base_energy: float = 1.0
var flicker_t: float = 0.0
var dropout_timer: float = 12.0
var dropout_left: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var audio: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var hum_gain: float = 0.0
var hum_env: float = 1.0
var hum_phase: float = 0.0
var tap_player: AudioStreamPlayer3D
var last_tap: int = -1

func _ready() -> void:
	rng.randomize()
	# Внутренний рендер 640×360 (project.godot не трогаем)
	var win: Window = get_window()
	win.content_scale_size = Vector2i(640, 360)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_energy = lamp.light_energy
	hum_gain = db_to_linear(HUM_DB) * HUM_TRIM
	# Процедурный звук: без файлов, генератор в буфер
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.4
	audio = AudioStreamPlayer.new()
	audio.stream = gen
	add_child(audio)
	audio.play()
	playback = audio.get_stream_playback() as AudioStreamGeneratorPlayback
	# Стук пальца: три записанных варианта, позиция на костяшке
	tap_player = AudioStreamPlayer3D.new()
	tap_player.unit_size = 1.0
	tap_player.max_distance = 40.0
	finger.add_child(tap_player)
	dropout_timer = rng.randf_range(8.0, 30.0)
	# Проявление из чёрного за 2 с
	fade.color.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(fade, "color:a", 0.0, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = event
		target_yaw = clampf(target_yaw - m.relative.x * SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
		target_pitch = clampf(target_pitch - m.relative.y * SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventMouseButton and event.pressed:
		idle_time = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	_update_look(delta)
	_update_tapping(delta)
	_update_lamp(delta)
	_update_audio(delta)

# Сглаженный обзор в пределах конуса
func _update_look(delta: float) -> void:
	var k: float = clampf(SMOOTH * delta, 0.0, 1.0)
	cur_yaw = lerpf(cur_yaw, target_yaw, k)
	cur_pitch = lerpf(cur_pitch, target_pitch, k)
	camera.rotation_degrees = Vector3(BASE_PITCH + cur_pitch, cur_yaw, 0.0)

# Одиночные удары пальцем; при простое > 16 с — чаще и сильнее
func _update_tapping(delta: float) -> void:
	idle_time += delta
	tap_timer -= delta
	if tap_timer > 0.0:
		return
	var hint: bool = idle_time > IDLE_HINT_TIME
	var amp: float = -30.0 if hint else -18.0
	var pause: float = rng.randf_range(1.5, 2.4) if hint else rng.randf_range(2.7, 4.2)
	tap_timer = pause + 0.18
	var tw: Tween = create_tween()
	tw.tween_property(finger, "rotation_degrees:x", amp, 0.09)
	tw.tween_property(finger, "rotation_degrees:x", 0.0, 0.09)
	# Вариант не повторяется дважды подряд
	var v: int = rng.randi_range(0, TAPS.size() - 1)
	if v == last_tap:
		v = (v + 1) % TAPS.size()
	last_tap = v
	tap_player.stream = TAPS[v]
	tap_player.play()

# Мерцание ±0.5% и редкое выпадение 0.05–0.15 с
func _update_lamp(delta: float) -> void:
	flicker_t += delta
	var n: float = sin(flicker_t * 0.9) * 0.5 + sin(flicker_t * 2.3 + 1.7) * 0.5
	var e: float = base_energy * (1.0 + 0.005 * n)
	dropout_timer -= delta
	if dropout_timer <= 0.0:
		dropout_left = rng.randf_range(0.05, 0.15)
		dropout_timer = rng.randf_range(8.0, 30.0)
	if dropout_left > 0.0:
		dropout_left -= delta
		e *= 0.35
	lamp.light_energy = e

# Гул лампы 50 Гц + гармоники, привязан к яркости
func _update_audio(_delta: float) -> void:
	if playback == null:
		return
	var frames: int = mini(playback.get_frames_available(), 16384)
	if frames <= 0:
		return
	var bright: float = lamp.light_energy / maxf(base_energy, 0.001)
	var k: float = 1.0 - exp(-1.0 / (0.008 * MIX_RATE))
	var buf: PackedVector2Array = PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		hum_phase += 50.0 / MIX_RATE
		if hum_phase > 1.0:
			hum_phase -= 1.0
		var hum: float = sin(TAU * hum_phase) * 0.6 + sin(TAU * hum_phase * 2.0) * 0.25 + sin(TAU * hum_phase * 3.0) * 0.1
		hum_env = lerpf(hum_env, bright, k)
		buf[i] = Vector2.ONE * clampf(hum * hum_gain * hum_env, -1.0, 1.0)
	playback.push_buffer(buf)
