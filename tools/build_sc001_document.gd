extends SceneTree
# Одноразовый генератор scenes/SC001_Document.tscn. Запуск:
#   redot...console.exe --headless --path . --script res://tools/build_sc001_document.gd

const PAPER_SIZE := Vector2(190.0, 268.0)
const PAD := 14.0
const INK := Color(0.165, 0.149, 0.125)
const INK_DIM := Color(0.44, 0.41, 0.35)
const PAPER_COLOR := Color(0.847, 0.824, 0.753)
const STAMP_COLOR := Color(0.478, 0.263, 0.149)
const OUT_PATH := "res://scenes/SC001_Document.tscn"

var font: SystemFont

func _initialize() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Liberation Mono", "Consolas"])
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.hinting = TextServer.HINTING_NONE
	font.generate_mipmaps = false

	var root := Control.new()
	root.name = "SC001_Document"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	root.set_script(load("res://scripts/sc001_document.gd"))

	root.add_child(_dim())
	root.add_child(_vignette())
	var pivot := _pivot()
	root.add_child(pivot)
	var paper := _paper()
	pivot.add_child(paper)
	for i in 4:
		paper.add_child(_page(i + 1))
	paper.add_child(_edge("EdgeL", true))
	paper.add_child(_edge("EdgeR", false))
	root.add_child(_cursor())

	_own(root, root)
	var packed := PackedScene.new()
	var err: int = packed.pack(root)
	print("pack=", err, " nodes=", packed.get_state().get_node_count())
	err = ResourceSaver.save(packed, OUT_PATH)
	print("save=", err)
	quit()

func _own(node: Node, root: Node) -> void:
	for c in node.get_children():
		c.owner = root
		_own(c, root)

func _dim() -> ColorRect:
	var c := ColorRect.new()
	c.name = "Dim"
	c.unique_name_in_owner = true
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.color = Color(0.031, 0.035, 0.043, 0.0)
	return c

func _vignette() -> TextureRect:
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.8))
	grad.set_offset(0, 0.55)
	grad.set_offset(1, 1.0)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 320
	tex.height = 180
	var t := TextureRect.new()
	t.name = "Vignette"
	t.unique_name_in_owner = true
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	return t

# Пивот наклона: центр листа в локальном нуле, shear применяется к нему
func _pivot() -> Node2D:
	var p := Node2D.new()
	p.name = "PaperPivot"
	p.unique_name_in_owner = true
	p.position = Vector2(320.0, 180.0 + 8.0)
	return p

func _paper() -> Panel:
	var p := Panel.new()
	p.name = "Paper"
	p.unique_name_in_owner = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.clip_contents = true
	p.size = PAPER_SIZE
	p.position = -PAPER_SIZE * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_COLOR
	sb.border_color = Color(0.36, 0.34, 0.29)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	return p

func _edge(name_: String, left: bool) -> ColorRect:
	var c := ColorRect.new()
	c.name = name_
	c.unique_name_in_owner = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.color = Color(0.92, 0.9, 0.85, 1.0)
	if left:
		c.anchor_bottom = 1.0
		c.offset_left = 1.0
		c.offset_right = 2.0
	else:
		c.anchor_left = 1.0
		c.anchor_right = 1.0
		c.anchor_bottom = 1.0
		c.offset_left = -2.0
		c.offset_right = -1.0
	return c

func _cursor() -> ColorRect:
	var c := ColorRect.new()
	c.name = "Cursor"
	c.unique_name_in_owner = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(2, 2)
	c.pivot_offset = Vector2(1, 1)
	c.color = Color(0.92, 0.9, 0.85, 0.9)
	return c

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(0, h)
	return c

func _box() -> VBoxContainer:
	var b := VBoxContainer.new()
	b.name = "Box"
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.offset_left = PAD
	b.offset_top = PAD
	b.offset_right = -PAD
	b.offset_bottom = -PAD
	b.add_theme_constant_override("separation", 3)
	return b

func _page(n: int) -> Control:
	var page := Control.new()
	page.name = "Page%d" % n
	page.unique_name_in_owner = true
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = n == 1
	var box := _box()
	page.add_child(box)
	var data := _page_data(n)
	box.add_child(_label(data[0], 13, INK))
	box.add_child(_spacer(2))
	box.add_child(_label(data[1], 9, INK_DIM))
	box.add_child(_spacer(10))
	for row in data[2]:
		box.add_child(_label(row[0], 8, INK_DIM))
		box.add_child(_label(row[1], 11, INK))
		box.add_child(_spacer(6))
	if n == 4:
		page.add_child(_signature_block())
		page.add_child(_stamp())
	return page

func _page_data(n: int) -> Array:
	match n:
		1:
			return ["ДОГОВОР ПОДРЯДА", "№ 0427-О · 12.11.2006", [
				["ПОДРЯДЧИК", "Орлов К.А."],
				["ЗАКАЗЧИК", "[ИЗЪЯТО]"],
				["ОБЪЕКТ", "Глубина-10"],
				["ПРЕДМЕТ", "работы по договору подряда"],
			]]
		2:
			return ["УСЛОВИЯ РАБОТЫ", "раздел 2", [
				["СРОК", "2–3 недели"],
				["АВАНС", "500 000 руб."],
				["ОПЛАТА", "по акту приёмки"],
				["РЕЖИМ", "соблюдение режима объекта"],
			]]
		3:
			return ["ОСОБЫЕ УСЛОВИЯ", "раздел 3", [
				["СУБЪЕКТ", "А-0427-О"],
				["ПРОГНОЗ", "нестабилен"],
				["ТЕРАПИЯ", "продолжение зависит от выполнения условий контракта"],
			]]
		_:
			return ["ПОДПИСАНИЕ", "раздел 4", [
				["ПОДТВЕРЖДЕНИЕ", "с условиями ознакомлен, согласен"],
			]]

func _signature_block() -> Control:
	var c := Control.new()
	c.name = "SigBlock"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(PAD, 150.0)
	c.size = Vector2(140, 60)
	var zone := Control.new()
	zone.name = "SigZone"
	zone.unique_name_in_owner = true
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.size = Vector2(140, 28)
	c.add_child(zone)
	var line := ColorRect.new()
	line.name = "SigLine"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(0, 28)
	line.size = Vector2(140, 1)
	line.color = INK_DIM
	c.add_child(line)
	var cap := _label("подпись подрядчика", 8, INK_DIM)
	cap.name = "SigCaption"
	cap.position = Vector2(0, 32)
	cap.size = Vector2(140, 10)
	c.add_child(cap)
	var date := _label("12.11.2006", 10, INK)
	date.name = "DateValue"
	date.unique_name_in_owner = true
	date.position = Vector2(0, 46)
	date.size = Vector2(140, 12)
	date.visible = false
	c.add_child(date)
	return c

func _stamp() -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Stamp"
	p.unique_name_in_owner = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(96, 202)
	p.pivot_offset = Vector2(40, 12)
	p.rotation = deg_to_rad(-8.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.847, 0.824, 0.753, 0.0)
	sb.border_color = STAMP_COLOR
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.content_margin_left = 6
	sb.content_margin_top = 3
	sb.content_margin_right = 6
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := _label("СОГЛАСОВАНО", 10, STAMP_COLOR)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p
