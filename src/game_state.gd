extends Node

# Global game state manager to pass data between the Map and the Battlefield

var players = [
	{"name": "Mark", "region": "Any", "color": Color(0.8, 0.2, 0.2), "army": 50000, "alive": true, "is_bot": false},
	{"name": "James", "region": "Any", "color": Color(0.2, 0.8, 0.2), "army": 50000, "alive": true, "is_bot": true},
	{"name": "Avery", "region": "Any", "color": Color(0.2, 0.2, 0.8), "army": 50000, "alive": true, "is_bot": true}
]

var neutral_cities = {} # province_name -> army_size
var province_owners = {} # province_name -> player_index
var capitals = {} # player_index -> province_name

var current_turn = 0
var game_phase = "picking" # "picking", "playing"

var attack_data = {
	"attacker_idx": -1,
	"defender_idx": -1, # -1 if neutral
	"province": "",
	"attacker_army": {"warrior": 0, "ranger": 0, "wizard": 0, "rocket_launcher": 0},
	"defender_army": {"warrior": 0, "ranger": 0, "wizard": 0, "rocket_launcher": 0},
	"buffed_unit": "",
	"nerfed_unit": "",
	"is_capital": false,
	"city_value": 0
}

const UNIT_COSTS = {
	"warrior": 280,
	"ranger": 550,
	"wizard": 2000,
	"rocket_launcher": 1700
}

var last_save_path = "user://saves/default.json"

func start_battle(attacker, defender, prov, city_val):
	attack_data.attacker_idx = attacker
	attack_data.defender_idx = defender
	attack_data.province = prov
	attack_data.city_value = city_val
	
	if defender == -1:
		attack_data.is_capital = false
	else:
		# JSON safety: check both int and string keys
		var cap_name = capitals.get(defender, capitals.get(str(defender), ""))
		attack_data.is_capital = (cap_name == prov)
	
	# Transition to troop selection UI or battlefield
	get_tree().change_scene_to_file("res://troop_selector.tscn")

func simulate_battle(att_idx: int, def_idx: int, prov: String, city_val: int):
	# Bot vs Bot simulation
	var att_army = players[att_idx].army
	var def_army = 0
	if def_idx == -1:
		def_army = city_val
	else:
		def_army = players[def_idx].army
	
	var total = att_army + def_army
	var roll = randf() * total
	var attacker_won = (roll < att_army)
	
	# Update attack data for resolve_battle
	attack_data.attacker_idx = att_idx
	attack_data.defender_idx = def_idx
	attack_data.province = prov
	attack_data.city_value = city_val
	
	if def_idx != -1:
		var cap_name = capitals.get(def_idx, capitals.get(str(def_idx), ""))
		attack_data.is_capital = (cap_name == prov)
	else:
		attack_data.is_capital = false

	print("[DEBUG GameState] Simulating Bot Battle. Attacker Won: ", attacker_won)
	resolve_battle(attacker_won)

func resolve_battle(attacker_won: bool):
	var prov = attack_data.province
	var def_idx = attack_data.defender_idx
	var att_idx = attack_data.attacker_idx
	var city_value = attack_data.city_value
	
	print("[DEBUG GameState] Resolving Battle: ", prov, " Won: ", attacker_won)

	# Reset buffs/nerfs for the next battle
	attack_data.buffed_unit = ""
	attack_data.nerfed_unit = ""

	var bonus = city_value / 10
	
	if attacker_won:
		province_owners[prov] = att_idx
		players[att_idx].army += bonus
		
		if def_idx != -1:
			# Losing player loses 10% of city's army size
			players[def_idx].army -= bonus
			if players[def_idx].army < 0: players[def_idx].army = 0
			
			if attack_data.is_capital:
				# Capital captured! Eliminate the player and neutralize their other lands.
				print("[DEBUG GameState] CAPITAL CAPTURED! Eliminating Player ", def_idx)
				players[def_idx]["alive"] = false
				
				var provinces_to_clear = []
				for p_name in province_owners:
					if int(province_owners[p_name]) == def_idx and p_name != prov:
						provinces_to_clear.append(p_name)
				
				for p_name in provinces_to_clear:
					province_owners.erase(p_name)
				print("[DEBUG GameState] Neutralized ", provinces_to_clear.size(), " provinces.")
	
	next_turn()
	get_tree().change_scene_to_file("res://map_scene.tscn")

func next_turn():
	var prev_turn = current_turn
	current_turn = (current_turn + 1) % players.size()
	
	if game_phase == "playing":
		var attempts = 0
		while not _is_player_alive(current_turn) and attempts < players.size():
			print("[DEBUG GameState] Skipping dead player ", current_turn)
			current_turn = (current_turn + 1) % players.size()
			attempts += 1
	
	print("[DEBUG GameState] Turn changed from ", prev_turn, " to ", current_turn)

func _is_player_alive(idx: int) -> bool:
	# 1. Check alive flag
	if not players[idx].get("alive", true): return false
	
	# 2. Check capital ownership (JSON safety for keys)
	var cap_prov = capitals.get(idx, capitals.get(str(idx), ""))
	if cap_prov == "": return true # Haven't picked yet
	
	var current_owner = province_owners.get(cap_prov, -1)
	return int(current_owner) == idx
