extends Node2D

var _hovered_area = null

func _ready():
	for child in get_children():
		if child is Area2D:
			child.mouse_entered.connect(_on_area_mouse_entered.bind(child))
			child.mouse_exited.connect(_on_area_mouse_exited.bind(child))

func _on_area_mouse_entered(area: Area2D):
	_hovered_area = area
	_update_colors()

func _on_area_mouse_exited(area: Area2D):
	if _hovered_area == area:
		_hovered_area = null
	_update_colors()

func _update_colors():
	for child in get_children():
		if child is Area2D:
			var default_color = Color(0.7, 0.7, 0.7)
			var hover_color = Color(0.3, 0.3, 0.3)
			var target_color = hover_color if child == _hovered_area else default_color
			
			for node in child.get_children():
				if node is Polygon2D:
					node.color = target_color
