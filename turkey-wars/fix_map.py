import sys

with open('turkey-wars/map_scene.gd', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('var province_owners: Dictionary = {}', 'var province_owners: Dictionary = {}\nvar game_phase: String = "picking"')

p1 = '''func _init_new_game_state(player_names: Array):
    players = []
    province_owners.clear()
    turn_index = 0'''
p2 = '''func _init_new_game_state(player_names: Array):
    players = []
    province_owners.clear()
    turn_index = 0
    game_phase = "picking"'''
text = text.replace(p1, p2)

text = text.replace('turn_index = state.get("turn_index", 0)', 'turn_index = state.get("turn_index", 0)\n    game_phase = state.get("game_phase", "picking")')

s1 = '''func _save_session():
    session_data["game_state"] = {
        "players": players,
        "province_owners": province_owners,
        "turn_index": turn_index
    }'''
s2 = '''func _save_session():
    session_data["game_state"] = {
        "players": players,
        "province_owners": province_owners,
        "turn_index": turn_index,
        "game_phase": game_phase
    }'''
text = text.replace(s1, s2)

num_func = '''func format_number(n: int) -> String:
    var s = str(n)
    var res = ""
    var count = 0
    for i in range(s.length() - 1, -1, -1):
        if count == 3:
            res = "," + res
            count = 0
        res = s[i] + res
        count += 1
    return res

func get_strength_text_and_color(strength: int) -> Array:
    match strength:
        1: return ["Very Easy", Color("00ff00")]
        2: return ["Easy", Color("90ee90")]
        3: return ["Normal", Color("ffa500")]
        4: return ["Strong", Color("ff4500")]
        5: return ["Very Strong", Color("ff0000")]
    return ["Unknown", Color("ffffff")]
'''
text = text.replace('func _update_ui():', num_func + '\nfunc _update_ui():')

ui1 = '''func _update_ui():
    if players.size() > 0:
        var p = players[turn_index]
        player_army_label.text = "Turn: %s | Region: %s | Army: %d" % [p["name"], p["region"], p["army"]]
        player_army_label.add_theme_color_override("font_color", Color(p["color"]))'''
ui2 = '''func _update_ui():
    if players.size() > 0:
        var p = players[turn_index]
        var phase_text = "Picking Phase" if game_phase == "picking" else "Playing Phase"
        var army_str = format_number(int(p["army"]))
        player_army_label.text = "[%s] Turn: %s | Region: %s | Army: %s" % [phase_text, p["name"], p["region"], army_str]
        player_army_label.add_theme_color_override("font_color", Color(p["color"]))'''
text = text.replace(ui1, ui2)

mouse_in = '''func _on_area_input_event(viewport: Node, event: InputEvent, shape_idx: int, area: Area2D):'''
sel_func = '''func _is_province_selectable(province_name: String) -> bool:
    if game_phase != "picking": return false
    if province_owners.has(province_name): return false
    var p = players[turn_index]
    var p_data = game_data.get(province_name, {})
    if p_data.is_empty(): return false
    var region_key = str(players.size())
    var p_region = p_data.get("regions", {}).get(region_key, "")
    if p["region"] != "Any" and p_region != p["region"]: return false
    var adjacencies = p_data.get("adjacencies", [])
    for adj in adjacencies:
        if province_owners.has(adj) and province_owners[adj] != turn_index: return false
    return true\n\n'''
text = text.replace(mouse_in, sel_func + mouse_in)

click1 = '''func _handle_province_click(province_name: String):
    if players.size() == 0: return
    
    if province_owners.has(province_name):
        print("Province already owned!")
        return
        
    var p = players[turn_index]
    var p_data = game_data.get(province_name, {})
    if p_data.is_empty(): return
    
    var region_key = str(players.size())
    var p_region = p_data.get("regions", {}).get(region_key, "")
    if p["region"] != "Any" and p_region != p["region"]:
        print("Province is not in your assigned region (" + p["region"] + ")!")
        return
        
    var adjacencies = p_data.get("adjacencies", [])
    for adj in adjacencies:
        if province_owners.has(adj) and province_owners[adj] != turn_index:
            print("Cannot pick a province that borders another player!")
            return
            
    province_owners[province_name] = turn_index
    p["provinces"].append(province_name)
    
    turn_index = (int(turn_index) + 1) % players.size()'''

click2 = '''func _handle_province_click(province_name: String):
    if players.size() == 0: return
    if game_phase != "picking": return
    
    if not _is_province_selectable(province_name): return
            
    province_owners[province_name] = turn_index
    players[turn_index]["provinces"].append(province_name)
    
    turn_index = int(turn_index) + 1
    if turn_index >= players.size():
        turn_index = 0
        game_phase = "playing"
'''
text = text.replace(click1, click2)

tt1 = '''        name_label.text = "Name: " + province_name + " (" + tooltip_owner + ")"
        strength_label.text = "Strength: " + str(data.get("strength", data.get("Strength", 0)))
        army_label.text = "Army Size: " + str(data.get("initial_army", data.get("Initial_Army", 0)))
    else:
        name_label.text = "Name: " + province_name
        strength_label.text = "Strength: ?"
        army_label.text = "Army Size: ?"'''

tt2 = '''        name_label.text = "Name: " + province_name + " (" + tooltip_owner + ")"
        
        var strength_val = int(data.get("strength", data.get("Strength", 0)))
        var strength_info = get_strength_text_and_color(strength_val)
        strength_label.text = "Strength: " + strength_info[0]
        strength_label.add_theme_color_override("font_color", strength_info[1])
        
        var army_val = int(data.get("initial_army", data.get("Initial_Army", 0)))
        army_label.text = "Army Size: " + format_number(army_val)
    else:
        name_label.text = "Name: " + province_name
        strength_label.text = "Strength: ?"
        strength_label.add_theme_color_override("font_color", Color.WHITE)
        army_label.text = "Army Size: ?"'''
text = text.replace(tt1, tt2)


col1 = '''func _update_colors():
    for child in get_children():
        if child is Area2D:
            var target_color = Color(0.7, 0.7, 0.7)
            
            if province_owners.has(child.name):'''
col2 = '''func _update_colors():
    for child in get_children():
        if child is Area2D:
            var target_color = Color(0.7, 0.7, 0.7)
            
            if game_phase == "picking":
                if _is_province_selectable(child.name):
                    target_color = Color(0.85, 0.85, 0.5)
                else:
                    target_color = Color(0.4, 0.4, 0.4)
            
            if province_owners.has(child.name):'''
text = text.replace(col1, col2)

with open('turkey-wars/map_scene.gd', 'w', encoding='utf-8') as f:
    f.write(text)
