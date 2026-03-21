with open('turkey-wars/unit_2d.gd', 'r') as f:
    lines = f.readlines()

new_lines = []
in_ready = False
ready_done = False
for line in lines:
    if line.startswith('func _ready():'):
        in_ready = True
        new_lines.append(line)
        new_lines.append('\tadd_to_group("units")\n\n')
        new_lines.append('\tif not sfx_loaded:\n')
        new_lines.append('\t\tsfx_melee.append(preload("res://assets/audio/sfx/melee_01.ogg"))\n')
        new_lines.append('\t\tsfx_melee.append(preload("res://assets/audio/sfx/melee_02.ogg"))\n')
        new_lines.append('\t\tsfx_melee.append(preload("res://assets/audio/sfx/melee_03.ogg"))\n')
        new_lines.append('\t\tsfx_range.append(preload("res://assets/audio/sfx/rifle_continuous.ogg"))\n')
        new_lines.append('\t\tsfx_tank.append(preload("res://assets/audio/sfx/tank_01.ogg"))\n')
        new_lines.append('\t\tsfx_tank.append(preload("res://assets/audio/sfx/tank_02.ogg"))\n')
        new_lines.append('\t\tsfx_loaded = true\n\n')
        new_lines.append('\taudio_player = AudioStreamPlayer3D.new()\n')
        new_lines.append('\taudio_player.volume_db = -35.0\n')
        new_lines.append('\tadd_child(audio_player)\n\n')
        new_lines.append('\tif not frames_cache.has(unit_class):\n')
        new_lines.append('\t\tframes_cache[unit_class] = _load_frames(unit_class)\n')
        new_lines.append('\tsprite.sprite_frames = frames_cache[unit_class]\n\n')
        new_lines.append('\tsprite.play("idle")\n\n')
        new_lines.append('\tvar mat = StandardMaterial3D.new()\n')
        new_lines.append('\tmat.albedo_color = Color(0.9, 0.2, 0.2) if team == Team.ATTACKER else Color(0.2, 0.4, 0.9)\n')
        new_lines.append('\tteam_ring.material_override = mat\n\n')
        continue
        
    if in_ready:
        if line.startswith('static func _load_frames'):
            in_ready = False
            new_lines.append(line)
        continue
    else:
        new_lines.append(line)

with open('turkey-wars/unit_2d.gd', 'w') as f:
    f.writelines(new_lines)
