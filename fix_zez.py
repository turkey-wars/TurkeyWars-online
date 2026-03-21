import re

with open('turkey-wars/zez.gd', 'r') as f:
    text = f.read()

text = text.replace('_spawn_unit(0, true, preload("res://tank_2d.tscn"))', '_spawn_unit(0, false, preload("res://tank_2d.tscn"))')
text = text.replace('_spawn_unit(1, true, preload("res://tank_2d.tscn"))', '_spawn_unit(1, false, preload("res://tank_2d.tscn"))')

bgm_code = """\t# After environment setup, spawn 2D units
\t_spawn_armies()

\tvar bgm = AudioStreamPlayer.new()
\tvar stream = preload("res://assets/audio/sfx/battle_music.ogg")
\tif stream is AudioStreamOggVorbis:
\t\tstream.loop = true
\tbgm.stream = stream
\tbgm.volume_db = -24.0 # Turned this down more per request
\tbgm.autoplay = true
\tadd_child(bgm)"""

text = text.replace('\t# After environment setup, spawn 2D units\n\t_spawn_armies()', bgm_code)

with open('turkey-wars/zez.gd', 'w') as f:
    f.write(text)
