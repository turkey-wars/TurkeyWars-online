extends Control

@onready var title_label = Label.new()
@onready var budget_label = Label.new()
@onready var units_container = VBoxContainer.new()
@onready var confirm_button = Button.new()

var is_attacker_phase = true
var current_budget = 0
var initial_budget = 0

var selected_units = {
	"warrior": 0,
	"ranger": 0,
	"wizard": 0
}

var unit_labels = {}

func _ready():
	_setup_ui()
	_start_attacker_phase()

func _setup_ui():
	var center = CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)
	
	var panel = PanelContainer.new()
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(budget_label)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	vbox.add_child(units_container)
	
	for unit_type in ["warrior", "ranger", "wizard"]:
		var hbox = HBoxContainer.new()
		units_container.add_child(hbox)
		
		var name_label = Label.new()
		name_label.text = unit_type.capitalize() + " (" + str(GameState.UNIT_COSTS[unit_type]) + ")"
		name_label.custom_minimum_size = Vector2(150, 0)
		hbox.add_child(name_label)
		
		var btn_minus = Button.new()
		btn_minus.text = "-"
		btn_minus.pressed.connect(_on_unit_minus.bind(unit_type))
		hbox.add_child(btn_minus)
		
		var count_label = Label.new()
		count_label.text = "0"
		count_label.custom_minimum_size = Vector2(40, 0)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(count_label)
		unit_labels[unit_type] = count_label
		
		var btn_plus = Button.new()
		btn_plus.text = "+"
		btn_plus.pressed.connect(_on_unit_plus.bind(unit_type))
		hbox.add_child(btn_plus)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	confirm_button.text = "Confirm Army"
	confirm_button.pressed.connect(_on_confirm)
	vbox.add_child(confirm_button)

func _start_attacker_phase():
	is_attacker_phase = true
	var att_idx = GameState.attack_data.attacker_idx
	title_label.text = GameState.players[att_idx].name + "'s Attack Force"
	
	initial_budget = GameState.players[att_idx].army
	current_budget = initial_budget
	
	_reset_selection()
	_update_ui()

func _start_defender_phase():
	is_attacker_phase = false
	var def_idx = GameState.attack_data.defender_idx
	
	if GameState.attack_data.is_capital:
		title_label.text = GameState.players[def_idx].name + "'s Capital Defense"
		initial_budget = 75000
	else:
		title_label.text = GameState.players[def_idx].name + "'s Defense Force"
		initial_budget = GameState.players[def_idx].army
		
	current_budget = initial_budget
	
	_reset_selection()
	_update_ui()

func _reset_selection():
	selected_units = {"warrior": 0, "ranger": 0, "wizard": 0}

func _on_unit_plus(unit_type):
	var cost = GameState.UNIT_COSTS[unit_type]
	if current_budget >= cost:
		current_budget -= cost
		selected_units[unit_type] += 1
		_update_ui()

func _on_unit_minus(unit_type):
	if selected_units[unit_type] > 0:
		var cost = GameState.UNIT_COSTS[unit_type]
		current_budget += cost
		selected_units[unit_type] -= 1
		_update_ui()

func _update_ui():
	budget_label.text = "Remaining Army Size: " + str(current_budget)
	for unit_type in selected_units.keys():
		unit_labels[unit_type].text = str(selected_units[unit_type])

func _on_confirm():
	if is_attacker_phase:
		GameState.attack_data.attacker_army = selected_units.duplicate()
		
		var def_idx = GameState.attack_data.defender_idx
		if def_idx == -1:
			# Neutral city, auto-generate and start battle
			_generate_neutral_army()
			get_tree().change_scene_to_file("res://battlefield.tscn")
		else:
			# Next player's turn to pick
			_start_defender_phase()
	else:
		GameState.attack_data.defender_army = selected_units.duplicate()
		get_tree().change_scene_to_file("res://battlefield.tscn")

func _generate_neutral_army():
	var budget = GameState.attack_data.neutral_size
	var army = {"warrior": 0, "ranger": 0, "wizard": 0}
	
	# Randomly distribute budget
	var types = ["warrior", "ranger", "wizard"]
	while true:
		var affordable = []
		for t in types:
			if GameState.UNIT_COSTS[t] <= budget:
				affordable.append(t)
		
		if affordable.is_empty():
			break
			
		var chosen = affordable[randi() % affordable.size()]
		army[chosen] += 1
		budget -= GameState.UNIT_COSTS[chosen]
		
	GameState.attack_data.defender_army = army
