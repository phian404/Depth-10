extends Control
# SC-001: оверлей папки — четыре страницы, перелистывание, наклон за курсором.

signal opened
signal closed
signal page_changed(index: int)

const PAGE_COUNT: int = 4
const EDGE_W: float = 20.0
const TURN_TIME: float = 0.35
const TILT_MAX: float = 3.0
const TILT_SPAN: float = 260.0
const DIM_ALPHA: float = 0.45
const OPEN_TIME: float = 0.45

@onready var dim: ColorRect = %Dim
@onready var vignette: TextureRect = %Vignette
@onready var paper: Panel = %Paper
@onready var cursor: ColorRect = %Cursor
@onready var edge_l: ColorRect = %EdgeL
@onready var edge_r: ColorRect = %EdgeR
@onready var pages: Array[Control] = [%Page1, %Page2, %Page3, %Page4]

var is_open: bool = false
var page: int = 0
var _settled: bool = false
var _turning: bool = false
var _rest_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	dim.color.a = 0.0
	vignette.modulate.a = 0.0
	edge_l.modulate.a = 0.0
	edge_r.modulate.a = 0.0
	_apply_page()

# Открытие: лист поднимается со стола к камере
func open(origin: Vector2) -> void:
	if is_open:
		return
	is_open = true
	_settled = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	paper.pivot_offset = paper.size * 0.5
	_rest_pos = paper.position
	paper.scale = Vector2(0.6, 0.6)
	paper.position = origin - paper.size * 0.3
	paper.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(paper, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(paper, "position", _rest_pos, OPEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(paper, "modulate:a", 1.0, 0.3)
	tw.tween_property(dim, "color:a", DIM_ALPHA, 0.35)
	tw.tween_property(vignette, "modulate:a", 1.0, 0.35)
	tw.chain().tween_callback(func() -> void: _settled = true)
	opened.emit()

# Закрытие: папка возвращается на стол, страница запоминается
func close() -> void:
	if not is_open or _turning:
		return
	is_open = false
	_settled = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	edge_l.modulate.a = 0.0
	edge_r.modulate.a = 0.0
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(paper, "scale", Vector2(0.6, 0.6), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(paper, "modulate:a", 0.0, 0.3)
	tw.tween_property(dim, "color:a", 0.0, 0.25)
	tw.tween_property(vignette, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(func() -> void:
		visible = false
		paper.rotation = 0.0
		paper.position = _rest_pos)
	closed.emit()

func _process(delta: float) -> void:
	if not is_open:
		return
	var mp: Vector2 = get_local_mouse_position()
	cursor.position = mp - cursor.size * 0.5
	_update_hover(_to_local(get_global_mouse_position()))
	if not _settled:
		return
	var half: Vector2 = get_viewport_rect().size * 0.5
	var off: float = clampf((mp.x - half.x) / TILT_SPAN, -1.0, 1.0)
	paper.rotation = lerp_angle(paper.rotation, deg_to_rad(-off * TILT_MAX), clampf(8.0 * delta, 0.0, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not _settled:
		return
	if event is InputEventMouseMotion:
		_update_hover(_to_local(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(_to_local(event.position))
	elif event.is_action_pressed("ui_cancel"):
		close()

# Экранная точка → локальные координаты листа (с учётом наклона)
func _to_local(pos: Vector2) -> Vector2:
	return paper.get_global_transform_with_canvas().affine_inverse() * pos

func _update_hover(local: Vector2) -> void:
	var sz: Vector2 = paper.size
	var inside: bool = local.x >= 0.0 and local.y >= 0.0 and local.x <= sz.x and local.y <= sz.y
	var hot_l: bool = inside and page > 0 and local.x < EDGE_W
	var hot_r: bool = inside and page < PAGE_COUNT - 1 and local.x > sz.x - EDGE_W
	edge_l.modulate.a = 0.55 if hot_l else 0.0
	edge_r.modulate.a = 0.55 if hot_r else 0.0
	cursor.scale = Vector2(3.0, 3.0) if hot_l or hot_r else Vector2.ONE

func _click(local: Vector2) -> void:
	var sz: Vector2 = paper.size
	if local.x < 0.0 or local.y < 0.0 or local.x > sz.x or local.y > sz.y:
		close()
		return
	if local.x < EDGE_W:
		_turn(-1)
	elif local.x > sz.x - EDGE_W:
		_turn(1)

# Лист уезжает поверх соседнего, страница запоминается
func _turn(dir: int) -> void:
	var next: int = page + dir
	if _turning or next < 0 or next >= PAGE_COUNT:
		return
	_turning = true
	var from: Control = pages[page]
	var to: Control = pages[next]
	to.visible = true
	to.position = Vector2.ZERO
	to.rotation = 0.0
	from.z_index = 1
	page = next
	page_changed.emit(page)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(from, "position:x", -paper.size.x * dir, TURN_TIME).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(from, "rotation", deg_to_rad(-4.0 * dir), TURN_TIME)
	tw.chain().tween_callback(func() -> void:
		from.visible = false
		from.z_index = 0
		from.position = Vector2.ZERO
		from.rotation = 0.0
		_turning = false)

func _apply_page() -> void:
	for i in pages.size():
		pages[i].visible = i == page
		pages[i].position = Vector2.ZERO
		pages[i].rotation = 0.0
		pages[i].z_index = 0
