with open('turkey-wars/zez.gd', 'r') as f:
    text = f.read()

import re
text = re.sub(
    r'extends Node3D\n',
    'extends Node3D\n\n# --- TEMPORARY SPAWN CONFIG (Until wired to Main Menu) ---\n@export var attacker_soldier_count: int = 5\n@export var attacker_rifleman_count: int = 5\n@export var attacker_tank_count: int = 1\n\n@export var defender_soldier_count: int = 5\n@export var defender_rifleman_count: int = 5\n@export var defender_tank_count: int = 1\n# ---------------------------------------------------------\n',
    text
)

old_spawn_logic = '''\t# For Attacker (Team 0)
\tfor i in range(5):
\t\t_spawn_unit(0, false, preload("res://soldier_2d.tscn"))
\tfor i in range(5):
\t\t_spawn_unit(0, true, preload("res://rifleman_2d.tscn"))
\t_spawn_unit(0, false, preload("res://tank_2d.tscn"))

\t# For Defender (Team 1)
\tfor i in range(5):
\t\t_spawn_unit(1, false, preload("res://soldier_2d.tscn"))
\tfor i in range(5):
\t\t_spawn_unit(1, true, preload("res://rifleman_2d.tscn"))
\t_spawn_unit(1, false, preload("res://tank_2d.tscn"))'''

new_spawn_logic = '''\t# For Attacker (Team 0)
\tfor i in range(attacker_soldier_count):
\t\t_spawn_unit(0, false, preload("res://soldier_2d.tscn"))
\tfor i in range(attacker_rifleman_count):
\t\t_spawn_unit(0, true, preload("res://rifleman_2d.tscn"))
\tfor i in range(attacker_tank_count):
\t\t_spawn_unit(0, false, preload("res://tank_2d.tscn"))

\t# For Defender (Team 1)
\tfor i in range(defender_soldier_count):
\t\t_spawn_unit(1, false, preload("res://soldier_2d.tscn"))
\tfor i in range(defender_rifleman_count):
\t\t_spawn_unit(1, true, preload("res://rifleman_2d.tscn"))
\tfor i in range(defender_tank_count):
\t\t_spawn_unit(1, false, preload("res://tank_2d.tscn"))'''

text = text.replace(old_spawn_logic, new_spawn_logic)

with open('turkey-wars/zez.gd', 'w') as f:
    f.write(text)
