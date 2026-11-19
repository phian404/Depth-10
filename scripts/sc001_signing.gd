extends Node3D
# SC-001 «Подписание»: обзор мышью, постукивание, мерцание лампы, прицел, папка.

const YAW_LIMIT: float = 35.0
const PITCH_LIMIT: float = 15.0
const BASE_PITCH: float = -24.0
const SENSITIVITY: float = 0.08
const SMOOTH: float = 8.0
const IDLE_HINT_TIME: float = 16.0
const DOT_SCALE: Vector2 = Vector2(3.0, 3.0)
const TAPS: Array[AudioStream] = [
	preload("res://audio/SFX_foley_finger_tap_01.wav"),
	preload("res://audio/SFX_foley_finger_tap_02.wav"),
	preload("res://audio/SFX_foley_finger_tap_03.wav"),
]

@onready var camera: Camera3D = $Camera3D
@onready var finger: Node3D = $Somov/Finger
@onready var lamp: SpotLight3D = $Lamp/SpotLight3D
@onready var fade: ColorRect = $FadeLayer/ColorRect
@onready var folder: MeshInstance3D = $Folder
@onready var dot: ColorRect = $ReticleLayer/Dot
@onready var doc = $DocumentLayer/SC001_Document

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
var hum: AudioStreamPlayer
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
	dot.pivot_offset = dot.size * 0.5
	# Гул лампы отдельным узлом, чтобы бит LIGHTS_OUT гасил его одним вызовом
	hum = preload("res://scripts/sc001_hum.gd").new()
	add_child(hum)
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
	if doc.is_open:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = event
		target_yaw = clampf(target_yaw - m.relative.x * SENSITIVITY, -YAW_LIMIT, YAW_LIMIT)
		target_pitch = clampf(target_pitch - m.relative.y * SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventMouseButton and event.pressed:
		idle_time = 0.0
		if event.button_index == MOUSE_BUTTON_LEFT and _aim_on_folder():
			doc.open(_folder_rect().get_center())
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	_update_look(delta)
	_update_tapping(delta)
	_update_lamp(delta)
	hum.brightness = lamp.light_energy / maxf(base_energy, 0.001)
	_update_reticle()

# Прицел: точка 2×2, на папке — 6×6; в оверлее документа скрыт
func _update_reticle() -> void:
	dot.visible = not doc.is_open
	if dot.visible:
		dot.scale = DOT_SCALE if _aim_on_folder() else Vector2.ONE

# Прямоугольник папки на экране по AABB меша
func _folder_rect() -> Rect2:
	var box: AABB = folder.get_aabb()
	var rect: Rect2 = Rect2()
	for i in 8:
		var p: Vector2 = camera.unproject_position(folder.global_transform * box.get_endpoint(i))
		rect = Rect2(p, Vector2.ZERO) if i == 0 else rect.expand(p)
	return rect

# Прицел в центре кадра попадает на папку
func _aim_on_folder() -> bool:
	return _folder_rect().has_point(get_viewport().get_visible_rect().size * 0.5)

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
