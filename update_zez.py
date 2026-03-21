with open('turkey-wars/zez.gd', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.startswith('extends Node3D'):
        new_lines.append(line)
        new_lines.append('\n# --- TEMPORARY SPAWN CONFIG (Until wired to Main Menu) ---\n')
        new_lines.append('@export var attacker_soldier_count: int = 5\n')
        new_lines.append('@export var attacker_rifleman_count: int = 5\n')
        new_lines.append('@export var attacker_tank_count: int = 1\n\n')
        new_lines.append('@export var defender_soldier_count: int = 5\n')
        new_lines.append('@export var defender_rifleman_count: int = 5\n')
        new_lines.append('@export var defender_tank_count: int = 1\n')
        new_lines.append('# ---------------------------------------------------------\n')
        continue
    
    if line == '\t_spawn_armies()\n':
        new_lines.append(line)
        new_lines.append('\n\tvar bgm = AudioStreamPlayer.new()\n')
        new_lines.append('\tvar stream = preload("res://assets/audio/sfx/battle_music.ogg")\n')
        new_lines.append('\tif stream is AudioStreamOggVorbis:\n')
        new_lines.append('\t\tstream.loop = true\n')
        new_lines.append('\tbgm.stream = stream\n')
        new_lines.append('\tbgm.volume_db = -8.0\n')
        new_lines.append('\tbgm.autoplay = true\n')
        new_lines.append('\tadd_child(bgm)\n')
        continue

    # Attacker logic
    if line == '\tfor i in range(5):\n' and new_lines[-1] == '\t# For Attacker (Team 0)\n':
        new_lines.append('\tfor i in range(attacker_soldier_count):\n')
        continue
    if line == '\tfor i in range(5):\n' and new_lines[-1] == '\t\t_spawn_unit(0, false, preload("res://soldier_2d.tscn"))\n':
        new_lines.append('\tfor i in range(attacker_rifleman_count):\n')
        continue
    if line == '\t_spawn_unit(0, true, preload("res://tank_2d.tscn"))\n' or line == '\t_spawn_unit(0, false, preload("res://tank_2d.tscn"))\n':
        new_lines.append('\tfor i in range(attacker_tank_count):\n')
        new_lines.append('\t\t_spawn_unit(0, false, preload("res://tank_2d.tscn"))\n')
        continue

    # Defender logic
    if line == '\tfor i in range(5):\n' and new_lines[-1] == '\t# For Defender (Team 1)\n':
        new_lines.append('\tfor i in range(defender_soldier_count):\n')
        continue
    if line == '\tfor i in range(5):\n' and new_lines[-1] == '\t\t_spawn_unit(1, false, preload("res://soldier_2d.tscn"))\n':
        new_lines.append('\tfor i in range(defender_rifleman_count):\n')
        continue
    if line == '\t_spawn_unit(1, true, preload("res://tank_2d.tscn"))\n' or line == '\t_spawn_unit(1, false, preload("res://tank_2d.tscn"))\n':
        new_lines.append('\tfor i in range(defender_tank_count):\n')
        new_lines.append('\t\t_spawn_unit(1, false, preload("res://tank_2d.tscn"))\n')
        continue

    new_lines.append(line)

with open('turkey-wars/zez.gd', 'w') as f:
    f.writelines(new_lines)
