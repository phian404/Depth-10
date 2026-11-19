extends Control
# SC-001: оверлей папки — четыре страницы, перелистывание, наклон боков (shear Y).

signal opened
signal closed
signal page_changed(index: int)

const PAGE_COUNT: int = 4
const EDGE_W: float = 20.0
const TURN_TIME: float = 0.35
const SHEAR_MAX: float = 0.05
const SHEAR_SPAN: float = 90.0
const SHEAR_SMOOTH: float = 8.0
const DIM_ALPHA: float = 0.45
const OPEN_TIME: float = 0.45

@onready var dim: ColorRect = %Dim
@onready var vignette: TextureRect = %Vignette
@onready var pivot: Node2D = %PaperPivot
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
var _shear: float = 0.0
var _mouse: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = false
	dim.color.a = 0.0
	vignette.modulate.a = 0.0
	edge_l.modulate.a = 0.0
	edge_r.modulate.a = 0.0
	_rest_pos = paper.position
	_mouse = get_local_mouse_position()
	_apply_page()

# Открытие: лист поднимается со стола к камере
func open(origin: Vector2) -> void:
	if is_open:
		return
	is_open = true
	_settled = false
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Курсор стартует из центра: до первого движения мыши лист стоит ровно
	_mouse = get_viewport_rect().size * 0.5
	_shear = 0.0
	paper.pivot_offset = paper.size * 0.5
	paper.scale = Vector2(0.6, 0.6)
	paper.position = pivot.to_local(origin) - paper.size * 0.3
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
		_shear = 0.0
		pivot.transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.0, 1.0), pivot.position)
		paper.position = _rest_pos)
	closed.emit()

func _process(delta: float) -> void:
	if not is_open:
		return
	cursor.position = _mouse - cursor.size * 0.5
	_update_hover(_to_local(_mouse))
	if not _settled:
		return
	_update_tilt(_mouse, delta)

# Наклон боков: shear по Y, вертикальные рёбра листа заваливаются за курсором.
# Отсчёт от центра листа, а не от вьюпорта: не зависит от размера окна.
func _update_tilt(mp: Vector2, delta: float) -> void:
	var off: float = clampf((mp.x - pivot.position.x) / SHEAR_SPAN, -1.0, 1.0)
	_shear = lerpf(_shear, -off * SHEAR_MAX, clampf(SHEAR_SMOOTH * delta, 0.0, 1.0))
	# Shear вокруг центра листа: origin пивота сохраняется, иначе лист уедет в угол
	pivot.transform = Transform2D(Vector2(1.0, 0.0), Vector2(_shear, 1.0), pivot.position)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not _settled:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		_update_hover(_to_local(_mouse))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		_click(_to_local(_mouse))
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
