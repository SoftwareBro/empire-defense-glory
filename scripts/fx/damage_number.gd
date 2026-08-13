class_name DamageNumber
extends Node2D

## Floating text. Spawned by Fx.damage_number() for combat figures and by
## Fx.banner() for callouts like a tower's new rank.

const RISE: float = 40.0
const LIFETIME: float = 0.65

@onready var label: Label = $Label


func play(amount: int, tint: Color, is_kill: bool) -> void:
	_float(str(amount), tint, 22 if is_kill else 16, RISE, LIFETIME)


## Same floater, arbitrary text. Kept separate from play() so a rank-up never
## has to be laundered through an int that pretends to be damage.
func play_text(text: String, tint: Color, font_size: int, rise: float, lifetime: float) -> void:
	_float(text, tint, font_size, rise, lifetime)


func _float(text: String, tint: Color, font_size: int, rise: float, lifetime: float) -> void:
	label.text = text
	label.modulate = tint
	label.add_theme_font_size_override("font_size", font_size)

	scale = Vector2(0.55, 0.55)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(randf_range(-12.0, 12.0), -rise), lifetime).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, lifetime).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
