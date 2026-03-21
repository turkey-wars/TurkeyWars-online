with open('turkey-wars/zez.gd', 'r') as f:
    text = f.read()

import re

# Add variables
text = re.sub(
    r'# ---------------------------------------------------------\n',
    '# ---------------------------------------------------------\n\nvar attacker_count_label: Label\nvar defender_count_label: Label\n',
    text
)

# Call _setup_hud in _ready
text = text.replace(
    '\t_create_spring_afternoon_environment()',
    '\t_setup_hud()\n\t_create_spring_afternoon_environment()'
)

hud_code = '''
func _setup_hud():
\tvar hud_layer = CanvasLayer.new()
\thud_layer.layer = 10
\tadd_child(hud_layer)

\tvar root = Control.new()
\troot.set_anchors_preset(Control.PRESET_FULL_RECT)
\thud_layer.add_child(root)

\tattacker_count_label = Label.new()
\tattacker_count_label.text = "Attackers: 0"
\tattacker_count_label.position = Vector2(24, 14)
\tattacker_count_label.add_theme_font_size_override("font_size", 28)
\tattacker_count_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
\troot.add_child(attacker_count_label)

\tdefender_count_label = Label.new()
\tdefender_count_label.text = "Defenders: 0"
\tdefender_count_label.anchor_left = 1.0
\tdefender_count_label.anchor_right = 1.0
\tdefender_count_label.offset_left = -320
\tdefender_count_label.offset_right = -24
\tdefender_count_label.offset_top = 14
\tdefender_count_label.offset_bottom = 58
\tdefender_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
\tdefender_count_label.add_theme_font_size_override("font_size", 28)
\tdefender_count_label.add_theme_color_override("font_color", Color(0.3, 0.3, 1.0))
\troot.add_child(defender_count_label)

func _process(_delta: float):
\t_update_team_counters()

func _update_team_counters():
\tif not attacker_count_label or not defender_count_label:
\t\treturn

\tvar attacker_alive = 0
\tvar defender_alive = 0
\tfor u in get_tree().get_nodes_in_group("units"):
\t\tif not is_instance_valid(u):
\t\t\tcontinue
\t\tif u.team == 0 and u.current_state != u.State.DEAD:
\t\t\tattacker_alive += 1
\t\telif u.team == 1 and u.current_state != u.State.DEAD:
\t\t\tdefender_alive += 1

\tattacker_count_label.text = "Attackers: %d" % attacker_alive
\tdefender_count_label.text = "Defenders: %d" % defender_alive
'''

text = text + '\n' + hud_code

with open('turkey-wars/zez.gd', 'w') as f:
    f.write(text)
