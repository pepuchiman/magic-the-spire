class_name MapView
extends Control
## マップの表示。下が1階、上がボス。ノードは色付きの丸、つながりは線で描く。
## ノードがタップされたら node_tapped で知らせる（進むかどうかは画面側で決める）

signal node_tapped(node: MapNode)

## 1階あたりの高さ
const FLOOR_HEIGHT := 150.0
## ノードの大きさ
const NODE_SIZE := 100.0
const MARGIN_Y := 90.0

var _run: RunState
var _buttons: Dictionary = {}  # MapNode → Button
var _selected: MapNode


## ランのマップを表示する
func setup(run: RunState) -> void:
	_run = run
	for button: Button in _buttons.values():
		button.queue_free()
	_buttons.clear()
	custom_minimum_size.y = MARGIN_Y * 2 + FLOOR_HEIGHT * (run.map.floor_count() - 1) + NODE_SIZE
	for node: MapNode in run.map.all_nodes():
		var button := Button.new()
		button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		button.size = button.custom_minimum_size
		button.text = TextKeys.map_node(node.type)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func() -> void: node_tapped.emit(node))
		add_child(button)
		_buttons[node] = button
	_update_look()
	_layout()
	if not resized.is_connected(_layout):
		resized.connect(_layout)


## 選んだノードを強調する（null で解除）
func set_selected(node: MapNode) -> void:
	_selected = node
	_update_look()


## ノードの中心の位置（このマップの中での位置）
func node_center(node: MapNode) -> Vector2:
	var count := _run.map.get_floor(node.floor_index).size()
	var x := size.x * (node.index + 1) / (count + 1)
	var y := custom_minimum_size.y - MARGIN_Y - NODE_SIZE / 2.0 - FLOOR_HEIGHT * node.floor_index
	return Vector2(x, y)


func get_button(node: MapNode) -> Button:
	return _buttons.get(node)


func _layout() -> void:
	for node: MapNode in _buttons:
		var button: Button = _buttons[node]
		button.position = node_center(node) - button.size / 2.0
	queue_redraw()


func _update_look() -> void:
	var available := _run.available_nodes()
	for node: MapNode in _buttons:
		var button: Button = _buttons[node]
		var color := _type_color(node.type)
		var border := color.darkened(0.4)
		var border_width := 3
		if node == _run.current_node:
			border = UiPalette.HIGHLIGHT  # 現在地
			border_width = 8
		elif node == _selected:
			border = UiPalette.SELECTED
			border_width = 8
		elif available.has(node):
			border = Color.WHITE  # 次に進める
			border_width = 6
		var box := UiPalette.make_box(color, border, border_width, int(NODE_SIZE / 2.0))
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, box)
		# 通過済みは薄く、進めないノードは暗く
		if node.visited and node != _run.current_node:
			button.modulate = Color(1, 1, 1, 0.45)
		elif available.has(node) or node == _run.current_node:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.55, 0.55, 0.6)
	queue_redraw()


func _draw() -> void:
	if _run == null:
		return
	for node: MapNode in _run.map.all_nodes():
		for target: MapNode in node.next:
			var walked := node.visited and target.visited
			var color := UiPalette.HIGHLIGHT if walked else Color(1, 1, 1, 0.25)
			draw_line(node_center(node), node_center(target), color, 6.0 if walked else 4.0, true)


static func _type_color(type: GameEnums.MapNodeType) -> Color:
	match type:
		GameEnums.MapNodeType.BATTLE:
			return Color(0.55, 0.28, 0.28)
		GameEnums.MapNodeType.ELITE:
			return Color(0.70, 0.20, 0.45)
		GameEnums.MapNodeType.EVENT:
			return Color(0.30, 0.45, 0.70)
		GameEnums.MapNodeType.REST:
			return Color(0.28, 0.58, 0.38)
		GameEnums.MapNodeType.TREASURE:
			return Color(0.75, 0.62, 0.25)
	return Color(0.45, 0.12, 0.30)
