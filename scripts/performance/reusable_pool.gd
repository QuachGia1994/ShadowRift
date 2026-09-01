extends Node
class_name ReusablePool

var _factory: Callable
var _available: Array[Node] = []
var _capacity := 0

func configure(factory: Callable, initial_capacity: int) -> void:
	_factory = factory
	_capacity = maxi(1, initial_capacity)
	for _index in range(_capacity):
		_available.append(_create_item())

func acquire() -> Node:
	var item := _available.pop_back() if not _available.is_empty() else _create_item()
	item.process_mode = Node.PROCESS_MODE_INHERIT
	if item is CanvasItem:
		(item as CanvasItem).visible = true
	return item

func release(item: Node) -> void:
	if not is_instance_valid(item) or item.get_parent() != self or _available.has(item):
		return
	if item is CanvasItem:
		(item as CanvasItem).visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	_available.append(item)

func available_count() -> int:
	return _available.size()

func _create_item() -> Node:
	var item := _factory.call() as Node
	add_child(item)
	if item is CanvasItem:
		(item as CanvasItem).visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	return item
