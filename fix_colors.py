import sys

with open('turkey-wars/map_scene.gd', 'r') as f:
    content = f.read()

idx = content.find('func _update_colors():')
if idx != -1:
    content = content[:idx]
    
new_func = """func _update_colors():
	for child in get_children():
		if child is Area2D:
			var target_color = Color(0.7, 0.7, 0.7)

			if game_phase == "picking":
				var selectable = _is_province_selectable(child.name)
				if selectable:
					target_color = Color(0.85, 0.85, 0.5)
				else:
					target_color = Color(0.4, 0.4, 0.4)

				if province_owners.has(child.name):
					var owner_idx = int(province_owners[child.name])
					var raw_col = players[owner_idx]["color"]
					if typeof(raw_col) == TYPE_STRING:
						target_color = Color(raw_col)
					else:
						target_color = raw_col

				if child == _hovered_area:
					target_color = target_color.lightened(0.3)
			else:
				var is_owned = province_owners.has(child.name)
				var owner_idx = int(province_owners.get(child.name, -1))
				var is_my_own = is_owned and owner_idx == turn_index
				var is_neighboring = _is_neighbor(child.name, turn_index)
				var is_capital = false
				if is_owned and GameState.capitals.has(owner_idx):
					is_capital = (GameState.capitals[owner_idx] == child.name)

				if is_owned:
					var raw_col = players[owner_idx]["color"]
					if typeof(raw_col) == TYPE_STRING:
						target_color = Color(raw_col)
					else:
						target_color = raw_col
					if is_capital:
						target_color = target_color.darkened(0.5)
				elif is_neighboring:
					target_color = Color.GRAY
				else:
					target_color = Color(0.9, 0.9, 0.9)

				if child == _hovered_area and is_neighboring and not is_my_own:
					target_color = Color.DARK_GRAY

			for node in child.get_children():
				if node is Polygon2D:
					node.color = target_color
"""
    
with open('turkey-wars/map_scene.gd', 'w') as f:
    f.write(content + new_func)

print('Updated successfully')
