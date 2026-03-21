with open('turkey-wars/unit_2d.gd', 'r') as f:
    text = f.read()

text = text.replace('\t\t\t\t\t_play_attack_sfx()', '\t\t\t_play_attack_sfx()')

with open('turkey-wars/unit_2d.gd', 'w') as f:
    f.write(text)
