extends Sprite3D
class_name Card

@onready var sprite: AnimatedSprite2D = %AnimatedSprite2D
func set_card(id: int):
	sprite.frame = id - 1
