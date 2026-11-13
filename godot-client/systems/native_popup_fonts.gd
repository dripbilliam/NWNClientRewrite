extends "res://systems/native_bitmap_fonts.gd"
# Original popup fonts specify complete pixel height, rather than em size.
# Keep drawing, line height and fitting advances on the same derived font.
# This catalog-scoped owner is shared by speech and hover/Tab captions only.
func _init() -> void:
	ttf_pixel_height_enabled=true
