extends RefCounted
# Freeze a screen's constructed, installed-content targets before any received
# rows or later size-dependent controls can change its membership.

static func capture(scope: String,owner: Control,frame,models: Dictionary,scrollbars: Array=[]) -> Dictionary:
	var result:={"scope":scope,"models_expected":models.size(),"images":[],"fonts":[],"failures":[],"untagged_fonts":0,"admitted":false}
	var mutable_images: Dictionary={}
	for bar in scrollbars:
		if not is_instance_valid(bar): result.failures.append("Missing original scrollbar owner"); continue
		if not str(bar.failure).is_empty(): result.failures.append(str(bar.failure)); continue
		if str(bar.rail_key).is_empty() or str(bar.thumb_key).is_empty(): result.failures.append("Missing original scrollbar image request")
		if is_instance_valid(bar.rail): mutable_images[bar.rail.get_instance_id()]={"bar":weakref(bar),"role":"rail"}
		if is_instance_valid(bar.thumb): mutable_images[bar.thumb.get_instance_id()]={"bar":weakref(bar),"role":"thumb"}
	for node in owner.find_children("*","Control",true,false):
		if node is TextureRect:
			var key:=str(node.get_meta("native_gui_art_key",""))
			# Godot adds its own untagged adornments directly to ScrollContainer.
			# Every client-created source image is tagged by the painter or bar.
			if key.is_empty() and node.get_parent() is ScrollContainer: continue
			if key.is_empty(): result.failures.append("Unregistered static image: "+str(node.get_path()))
			else:
				var row:={"target":weakref(node),"key":key,"kind":"model" if key.begins_with("gui:") else "raster","meta_key":true}
				if mutable_images.has(node.get_instance_id()): row.merge(mutable_images[node.get_instance_id()])
				result.images.append(row)
		var font:=str(node.get_meta("native_font_resource",""))
		if not font.is_empty(): result.fonts.append({"target":weakref(node),"key":font})
		elif node is Label and not node.text.is_empty(): result.untagged_fonts+=1
		if node is Button and frame.button_geometry.has(node.get_instance_id()):
			var data: Dictionary=frame.button_geometry[node.get_instance_id()]
			for pair in data.styles.values():
				var style_key: String=frame.art.models.model_key(str(data.resource),str(pair[1]),data.overrides)
				result.images.append({"target":weakref(pair[0]),"key":style_key,"kind":"model","meta_key":false})
	return result

static func snapshot(manifest: Dictionary,frame,failure: String="") -> Dictionary:
	var result:={"scope":str(manifest.get("scope","")),"sealed":not manifest.is_empty(),"ready":false,"models_expected":int(manifest.get("models_expected",0)),"models_ready":int(manifest.get("models_expected",0)) if not manifest.is_empty() else 0,"images_expected":0,"images_ready":0,"fonts_expected":0,"fonts_ready":0,"untagged_fonts":int(manifest.get("untagged_fonts",0)),"pending":[],"failures":Array(manifest.get("failures",[])).duplicate()}
	if not failure.is_empty(): result.failures.append(failure)
	if manifest.is_empty():
		if result.failures.is_empty(): result.pending.append("GFF/model layout")
		return result
	if not is_instance_valid(frame) or not is_instance_valid(frame.art) or not is_instance_valid(frame.fonts):
		result.failures.append("Page artwork/font owners are unavailable"); return result
	for row in manifest.images:
		result.images_expected+=1
		var target: Object=row.target.get_ref()
		var key: String=row.key
		var mutable: bool=row.has("bar")
		if mutable and bool(manifest.admitted): result.images_ready+=1; continue
		if mutable and is_instance_valid(target):
			# A content-size change before first admission replaces the request.
			# Track that exact request and require the bar to publish it.
			var current_key:=str(target.get_meta("native_gui_art_key",""))
			if not current_key.is_empty() and current_key!=key: row.key=current_key; key=current_key
		if not is_instance_valid(target): result.failures.append("Retired page image "+key)
		elif bool(row.get("meta_key",false)) and str(target.get_meta("native_gui_art_key",""))!=key: result.failures.append("Page image key changed: "+key)
		elif mutable and (not is_instance_valid(row.bar.get_ref()) or str(row.bar.get_ref().thumb_image_key if row.role=="thumb" else row.bar.get_ref().rail_key)!=key): result.pending.append("image:"+key)
		elif target.get("texture")!=null and target.get("texture")==frame.art.textures.get(key): result.images_ready+=1
		elif frame.art.failed.has(key):
			var reason: String=frame.art.ui_assets.failure(str(row.kind),key) if frame.art.ui_assets!=null else ""
			result.failures.append("Page image "+key+": "+(reason if not reason.is_empty() else "Original UI image could not be prepared"))
		else: result.pending.append("image:"+key)
	for row in manifest.fonts:
		result.fonts_expected+=1
		var target: Object=row.target.get_ref()
		var key: String=row.key
		if not is_instance_valid(target): result.failures.append("Retired page font "+key)
		elif str(target.get_meta("native_font_applied",""))==key: result.fonts_ready+=1
		elif frame.fonts.failed.has(key): result.failures.append("Page font "+key+": "+str(frame.fonts.failed[key]))
		else: result.pending.append("font:"+key)
	result.ready=result.pending.is_empty() and result.failures.is_empty()
	if result.ready: manifest.admitted=true
	return result
