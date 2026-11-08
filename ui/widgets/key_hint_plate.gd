class_name KeyHintPlate
extends TextureRect
## One key plate of TutorialPopup: the hand-drawn button with the key's name on it.

@onready var _key: Label = %Key

func set_key(text: String) -> void:
	_key.text = text
