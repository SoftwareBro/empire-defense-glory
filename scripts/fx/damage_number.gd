class_name DamageNumber
extends Node2D

## Floating combat text. Spawned only by Fx.damage_number().

const RISE: float = 40.0
const LIFETIME: float = 0.65

@onready var label: Label = $Label


func play(amount: int, tint: Color, is_kill: bool) -> void:
	label.text = str(amount)
	label.modulate = tint
	label.add_theme_font_size_override("font_size", 22 if is_kill else 16)

	scale = Vector2(0.55, 0.55)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(randf_range(-12.0, 12.0), -RISE), LIFETIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
