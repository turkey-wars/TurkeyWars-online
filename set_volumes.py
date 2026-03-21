with open('turkey-wars/unit_2d.gd', 'r') as f:
    unit_text = f.read()

old_unit_audio = '''\taudio_player = AudioStreamPlayer3D.new()
\taudio_player.volume_db = -35.0
\tadd_child(audio_player)'''

new_unit_audio = '''\taudio_player = AudioStreamPlayer3D.new()
\tif unit_class == "melee" or unit_class == "tank":
\t\taudio_player.volume_db = -12.0
\telif unit_class == "range":
\t\taudio_player.volume_db = -28.0
\tadd_child(audio_player)'''

unit_text = unit_text.replace(old_unit_audio, new_unit_audio)

with open('turkey-wars/unit_2d.gd', 'w') as f:
    f.write(unit_text)

with open('turkey-wars/zez.gd', 'r') as f:
    zez_text = f.read()

old_zez_audio = '''\tbgm.stream = stream
\tbgm.volume_db = -24.0 # Turned this down more per request
\tbgm.autoplay = true'''

new_zez_audio = '''\tbgm.stream = stream
\tbgm.volume_db = -8.0 # Increased massively
\tbgm.autoplay = true'''

zez_text = zez_text.replace(old_zez_audio, new_zez_audio)

with open('turkey-wars/zez.gd', 'w') as f:
    f.write(zez_text)
