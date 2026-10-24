extends RefCounted

static func png(url: String, maximum_dimension: int = 1024, maximum_characters: int = 350000) -> Texture2D:
	if not url.begins_with("data:image/png;base64,") or url.length() > maximum_characters:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(url.substr(22))) != OK or image.get_width() > maximum_dimension or image.get_height() > maximum_dimension:
		return null
	return ImageTexture.create_from_image(image)
