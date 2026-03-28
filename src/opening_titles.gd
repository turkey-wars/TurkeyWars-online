extends Control

@onready var title_label: Label = $CenterContainer/TitleCard/TitleLabel


func _ready() -> void:
	TWUIStyle.style_panel_container_accent($CenterContainer/TitleCard)
	TWUIStyle.style_game_title(title_label)
	title_label.add_theme_font_size_override("font_size", 58)

	title_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 1.0)
	tween.tween_interval(3.0)
	tween.tween_property(title_label, "modulate:a", 0.0, 1.0)