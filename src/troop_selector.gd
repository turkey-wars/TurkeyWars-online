extends Control

@onready var title_label    = Label.new()
@onready var budget_label   = Label.new()
@onready var units_container = VBoxContainer.new()
@onready var confirm_button = Button.new()
@onready var budget_bar     = ProgressBar.new()

var phase_label: Label = null

var unit_plus_buttons  := {}
var unit_plus_ten_buttons := {}
var unit_minus_buttons := {}

var is_attacker_phase = true
var current_budget = 0
var initial_budget = 0

var selected_units = {
	"warrior": 0,
	"ranger": 0,
	"wizard": 0,
	"rocket_launcher": 0
}

var unit_labels = {}

func _ready():
	# Pick a buffed and nerfed unit if it's the start of the battle
	if GameState.attack_data.buffed_unit == "":
		var units = ["warrior", "ranger", "rocket_launcher", "wizard"]
		units.shuffle()
		GameState.attack_data.buffed_unit = units[0]
		GameState.attack_data.nerfed_unit = units[1]
		print("[DEBUG TroopSelector] Buffed: ", GameState.attack_data.buffed_unit, " | Nerfed: ", GameState.attack_data.nerfed_unit)

	_setup_ui()
	_start_attacker_phase()

func _setup_ui():
	var outer := MarginContainer.new()
	outer.set_anchors_preset(PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left",   40)
	outer.add_theme_constant_override("margin_right",  40)
	outer.add_theme_constant_override("margin_top",    30)
	outer.add_theme_constant_override("margin_bottom", 30)
	add_child(outer)

	var main_panel := PanelContainer.new()
	outer.add_child(main_panel)
	TWUIStyle.style_panel_container_accent(main_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)

	# ── HEADER ──────────────────────────────────────────────────
	var header_panel := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new()
	hdr_sb.bg_color              = Color(0.055, 0.070, 0.100, 1.0)
	hdr_sb.border_color          = Color(0.155, 0.195, 0.265, 1.0)
	hdr_sb.border_width_bottom   = 1
	hdr_sb.content_margin_left   = 24
	hdr_sb.content_margin_right  = 24
	hdr_sb.content_margin_top    = 18
	hdr_sb.content_margin_bottom = 18
	header_panel.add_theme_stylebox_override("panel", hdr_sb)
	main_vbox.add_child(header_panel)

	var hdr_hbox := HBoxContainer.new()
	hdr_hbox.add_theme_constant_override("separation", 32)
	header_panel.add_child(hdr_hbox)

	# Left side: phase badge + mission title.
	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 5)
	hdr_hbox.add_child(title_col)

	phase_label = Label.new()
	phase_label.text = tr("ATTACKER")
	TWUIStyle.style_label_muted(phase_label)
	title_col.add_child(phase_label)

	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TWUIStyle.style_label(title_label, true)
	title_label.add_theme_font_size_override("font_size", 26)
	title_col.add_child(title_label)

	# Right side: budget display.
	var budget_col := VBoxContainer.new()
	budget_col.add_theme_constant_override("separation", 4)
	hdr_hbox.add_child(budget_col)

	var budget_hdr := Label.new()
	budget_hdr.text = tr("BUDGET REMAINING")
	budget_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	TWUIStyle.style_label_muted(budget_hdr)
	budget_col.add_child(budget_hdr)

	budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	TWUIStyle.style_label_gold(budget_label, 34)
	budget_col.add_child(budget_label)

	# ── UNIT ROSTER ─────────────────────────────────────────────
	var roster_mc := MarginContainer.new()
	roster_mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_mc.add_theme_constant_override("margin_left",   24)
	roster_mc.add_theme_constant_override("margin_right",  24)
	roster_mc.add_theme_constant_override("margin_top",    16)
	roster_mc.add_theme_constant_override("margin_bottom", 16)
	main_vbox.add_child(roster_mc)

	units_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	units_container.add_theme_constant_override("separation", 0)
	roster_mc.add_child(units_container)

	var unit_defs := [
		["warrior", "SOLDIER"],
		["ranger",  "RIFLEMAN"],
		["rocket_launcher", "ROCKET"],
		["wizard",  "TANK"],
	]
	for i in unit_defs.size():
		var unit_type: String  = unit_defs[i][0]
		var display_name: String = tr(unit_defs[i][1])

		if i > 0:
			var row_sep := HSeparator.new()
			var row_sep_sb := StyleBoxFlat.new()
			row_sep_sb.bg_color = Color(0.155, 0.195, 0.265, 0.7)
			row_sep.add_theme_stylebox_override("separator", row_sep_sb)
			units_container.add_child(row_sep)

		var row_mc := MarginContainer.new()
		row_mc.add_theme_constant_override("margin_top",    12)
		row_mc.add_theme_constant_override("margin_bottom", 12)
		units_container.add_child(row_mc)

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		row_mc.add_child(hbox)

		var name_lbl := Label.new()
		name_lbl.text = display_name
		if unit_type == GameState.attack_data.buffed_unit:
			name_lbl.text += " (BUFFED)"
			name_lbl.add_theme_color_override("font_color", Color.GREEN)
		elif unit_type == GameState.attack_data.nerfed_unit:
			name_lbl.text += " (NERFED)"
			name_lbl.add_theme_color_override("font_color", Color.RED)
		else:
			TWUIStyle.style_label(name_lbl, true)

		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 17)
		hbox.add_child(name_lbl)

		var cost_lbl := Label.new()
		cost_lbl.text = "%s pts" % str(GameState.UNIT_COSTS[unit_type])
		TWUIStyle.style_label_muted(cost_lbl)
		cost_lbl.add_theme_font_size_override("font_size", 13)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(cost_lbl)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(20, 0)
		hbox.add_child(spacer)

		var btn_minus := Button.new()
		btn_minus.text = "−"
		btn_minus.custom_minimum_size = Vector2(38, 38)
		btn_minus.pressed.connect(_on_unit_minus.bind(unit_type))
		TWUIStyle.style_button(btn_minus)
		hbox.add_child(btn_minus)
		unit_minus_buttons[unit_type] = btn_minus

		var count_lbl := Label.new()
		count_lbl.text = "0"
		count_lbl.custom_minimum_size = Vector2(52, 0)
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		TWUIStyle.style_label(count_lbl, true)
		count_lbl.add_theme_font_size_override("font_size", 20)
		hbox.add_child(count_lbl)
		unit_labels[unit_type] = count_lbl

		var btn_plus := Button.new()
		btn_plus.text = "+"
		btn_plus.custom_minimum_size = Vector2(38, 38)
		btn_plus.pressed.connect(_on_unit_plus.bind(unit_type, 1))
		TWUIStyle.style_button(btn_plus)
		hbox.add_child(btn_plus)
		unit_plus_buttons[unit_type] = btn_plus

		var btn_plus_ten := Button.new()
		btn_plus_ten.text = "+10"
		btn_plus_ten.custom_minimum_size = Vector2(52, 38)
		btn_plus_ten.pressed.connect(_on_unit_plus.bind(unit_type, 10))
		TWUIStyle.style_button(btn_plus_ten)
		hbox.add_child(btn_plus_ten)
		unit_plus_ten_buttons[unit_type] = btn_plus_ten

	# ── FOOTER ──────────────────────────────────────────────────
	var footer_panel := PanelContainer.new()
	var ftr_sb := StyleBoxFlat.new()
	ftr_sb.bg_color              = Color(0.055, 0.070, 0.100, 1.0)
	ftr_sb.border_color          = Color(0.155, 0.195, 0.265, 1.0)
	ftr_sb.border_width_top      = 1
	ftr_sb.content_margin_left   = 24
	ftr_sb.content_margin_right  = 24
	ftr_sb.content_margin_top    = 16
	ftr_sb.content_margin_bottom = 16
	footer_panel.add_theme_stylebox_override("panel", ftr_sb)
	main_vbox.add_child(footer_panel)

	var footer_hbox := HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 20)
	footer_panel.add_child(footer_hbox)

	budget_bar.min_value = 0.0
	budget_bar.max_value = 1.0
	budget_bar.value     = 1.0
	budget_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_hbox.add_child(budget_bar)

	confirm_button.text = tr("CONFIRM ORDERS")
	confirm_button.custom_minimum_size = Vector2(220, 0)
	confirm_button.pressed.connect(_on_confirm)
	TWUIStyle.style_button_accent(confirm_button)
	footer_hbox.add_child(confirm_button)

func _start_attacker_phase():
	is_attacker_phase = true
	var att_idx = GameState.attack_data.attacker_idx
	var p = GameState.players[att_idx]
	title_label.text = tr("%s's Attack Force") % p.name
	if phase_label:
		phase_label.text = tr("ATTACKER")
		phase_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_RED)

	initial_budget = p.army
	current_budget = initial_budget

	_reset_selection()
	_update_ui()
	
	if p.get("is_bot", false):
		print("[DEBUG TroopSelector] Attacker is BOT. Auto-selecting...")
		_auto_select_bot_army()
		await get_tree().create_timer(1.0).timeout
		_on_confirm()


func _start_defender_phase():
	is_attacker_phase = false
	var def_idx = GameState.attack_data.defender_idx
	var p = GameState.players[def_idx]
	if phase_label:
		phase_label.text = tr("DEFENDER")
		phase_label.add_theme_color_override("font_color", TWUIStyle.COLOR_ACCENT_BLUE)

	if GameState.attack_data.is_capital:
		title_label.text = tr("%s's Capital Defense") % p.name
		# If the player's army is larger than the 75k floor, they use their full army for capital defense.
		initial_budget = max(75000, p.army)
	else:
		title_label.text = tr("%s's Defense Force") % p.name
		initial_budget = p.army

	current_budget = initial_budget

	_reset_selection()
	_update_ui()
	
	if p.get("is_bot", false):
		print("[DEBUG TroopSelector] Defender is BOT. Auto-selecting...")
		_auto_select_bot_army()
		await get_tree().create_timer(1.0).timeout
		_on_confirm()

func _auto_select_bot_army():
	# Use the logic from _generate_neutral_army but apply to selected_units
	var budget = initial_budget
	var army = {"warrior": 0, "ranger": 0, "wizard": 0, "rocket_launcher": 0}
	
	# --- ROCKET WEIGHT MODIFIER FOR DEFENDER ---
	var rocket_mod = 1.0
	if not is_attacker_phase:
		var att_army = GameState.attack_data.attacker_army
		var total_att_points = 0.0
		for t in att_army:
			total_att_points += att_army[t] * GameState.UNIT_COSTS[t]
		
		if total_att_points > 0:
			var rifle_points = att_army["ranger"] * GameState.UNIT_COSTS["ranger"]
			var rifle_ratio = rifle_points / total_att_points
			# Weight increases by up to 5x if attacker is 100% riflemen
			rocket_mod = 1.0 + (rifle_ratio * 4.0) 
			print("[DEBUG BotArmy] Attacker Rifle Ratio: ", rifle_ratio, " | Rocket Weight Mod: ", rocket_mod)
	# -------------------------------------------

	var types = ["warrior", "ranger", "wizard", "rocket_launcher"]
	while true:
		var affordable = []
		var weights = []
		var total_weight = 0.0
		
		for t in types:
			var cost = GameState.UNIT_COSTS[t]
			if cost <= budget:
				affordable.append(t)
				var w = 1.0 / float(cost)
				if t == "rocket_launcher":
					w *= rocket_mod
				weights.append(w)
				total_weight += w
		
		if affordable.is_empty():
			break
			
		var roll = randf() * total_weight
		var cumulative_weight = 0.0
		var chosen = affordable[0]
		
		for i in range(affordable.size()):
			cumulative_weight += weights[i]
			if roll <= cumulative_weight:
				chosen = affordable[i]
				break
				
		army[chosen] += 1
		budget -= GameState.UNIT_COSTS[chosen]
	
	selected_units = army
	current_budget = budget
	_update_ui()

func _reset_selection():
	selected_units = {"warrior": 0, "ranger": 0, "wizard": 0, "rocket_launcher": 0}

func _on_unit_plus(unit_type, amount):
	var cost = GameState.UNIT_COSTS[unit_type]
	var total_cost = cost * amount
	
	if current_budget >= total_cost:
		current_budget -= total_cost
		selected_units[unit_type] += amount
		_update_ui()
	else:
		# Add as many as possible
		var max_possible = current_budget / cost
		if max_possible > 0:
			current_budget -= max_possible * cost
			selected_units[unit_type] += max_possible
			_update_ui()

func _on_unit_minus(unit_type):
	if selected_units[unit_type] > 0:
		var cost = GameState.UNIT_COSTS[unit_type]
		current_budget += cost
		selected_units[unit_type] -= 1
		_update_ui()

func _update_ui():
	budget_label.text = str(current_budget)
	budget_bar.max_value = float(initial_budget) if initial_budget > 0 else 1.0
	budget_bar.value = float(current_budget)
	for unit_type in selected_units.keys():
		unit_labels[unit_type].text = str(selected_units[unit_type])

		var cost = GameState.UNIT_COSTS[unit_type]
		var can_afford = current_budget >= cost
		if unit_plus_buttons.has(unit_type):
			unit_plus_buttons[unit_type].disabled = not can_afford
		if unit_plus_ten_buttons.has(unit_type):
			unit_plus_ten_buttons[unit_type].disabled = not can_afford
		if unit_minus_buttons.has(unit_type):
			unit_minus_buttons[unit_type].disabled = selected_units[unit_type] <= 0

	# Confirm allowed only if the player picked at least one unit.
	var selected_total: int = 0
	for count in selected_units.values():
		selected_total += count
	confirm_button.disabled = selected_total <= 0

func _on_confirm():
	if is_attacker_phase:
		GameState.attack_data.attacker_army = selected_units.duplicate()
		
		var def_idx = GameState.attack_data.defender_idx
		if def_idx == -1:
			# Neutral city, auto-generate and start battle
			_generate_neutral_army()
			get_tree().change_scene_to_file("res://new_battlefield.tscn")
		else:
			# Next player's turn to pick
			_start_defender_phase()
	else:
		GameState.attack_data.defender_army = selected_units.duplicate()
		get_tree().change_scene_to_file("res://new_battlefield.tscn")

func _generate_neutral_army():
	var budget = GameState.attack_data.city_value
	var army = {"warrior": 0, "ranger": 0, "wizard": 0, "rocket_launcher": 0}
	
	# --- ROCKET WEIGHT MODIFIER FOR NEUTRAL DEFENDER ---
	var att_army = GameState.attack_data.attacker_army
	var total_att_points = 0.0
	for t in att_army:
		total_att_points += att_army[t] * GameState.UNIT_COSTS[t]
	
	var rocket_mod = 1.0
	if total_att_points > 0:
		var rifle_points = att_army["ranger"] * GameState.UNIT_COSTS["ranger"]
		var rifle_ratio = rifle_points / total_att_points
		rocket_mod = 1.0 + (rifle_ratio * 4.0) 
		print("[DEBUG NeutralArmy] Attacker Rifle Ratio: ", rifle_ratio, " | Rocket Weight Mod: ", rocket_mod)
	# -------------------------------------------

	# Weighted distribution based on cost (cheaper units are more likely)
	var types = ["warrior", "ranger", "wizard", "rocket_launcher"]
	while true:
		var affordable = []
		var weights = []
		var total_weight = 0.0
		
		for t in types:
			var cost = GameState.UNIT_COSTS[t]
			if cost <= budget:
				affordable.append(t)
				# Weight is inversely proportional to cost
				var w = 1.0 / float(cost)
				if t == "rocket_launcher":
					w *= rocket_mod
				weights.append(w)
				total_weight += w
		
		if affordable.is_empty():
			break
			
		var roll = randf() * total_weight
		var cumulative_weight = 0.0
		var chosen = affordable[0]
		
		for i in range(affordable.size()):
			cumulative_weight += weights[i]
			if roll <= cumulative_weight:
				chosen = affordable[i]
				break
				
		army[chosen] += 1
		budget -= GameState.UNIT_COSTS[chosen]
		
	GameState.attack_data.defender_army = army
