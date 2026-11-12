class_name GameFont
extends RefCounted
## The game's handwriting font (assets/fonts/handwriting.tres: Patrick Hand,
## slightly emboldened like a marker). It is also the project's default UI font
## (project.godot -> gui/theme/custom_font), so every Label, Button and
## RichTextLabel already uses it. Label3D ignores the project theme, so code
## that makes one should call GameFont.apply(label). To change the font for the
## whole game, point the .tres at a different base_font.

const FONT: Font = preload("res://assets/fonts/handwriting.tres")

static func apply(label: Label3D) -> Label3D:
	label.font = FONT
	return label
