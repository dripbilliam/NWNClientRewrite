extends RefCounted
# Process-resident UI bitmaps keyed by the selected source binding. Pregame
# preparation can serve a later server catalog only when it selects the same
# original bytes; an NWSync or override winner receives a different key.
static var images: Dictionary={}
static var retained_bytes:=0

static func source_key(catalog,name: String) -> String:
	if catalog==null: return ""
	var raster: Dictionary=catalog.raster_location(name)
	if raster.is_empty(): return ""
	var type: int=int(raster.type)
	var selected: Dictionary=catalog.location(name,type)
	if selected.is_empty(): return ""
	var identity:=str(selected.layer.get("binding_identity",""))
	if identity.is_empty(): return ""
	return identity+":"+name.to_lower()+":"+str(type)

static func lookup(catalog,name: String) -> Texture2D:
	var key:=source_key(catalog,name)
	return images.get(key,null) if not key.is_empty() else null

static func retain(catalog,name: String,texture: Texture2D) -> void:
	if texture==null: return
	var key:=source_key(catalog,name)
	if key.is_empty() or images.has(key): return
	images[key]=texture
	retained_bytes+=texture.get_width()*texture.get_height()*4

static func snapshot() -> Dictionary:
	return {"textures":images.size(),"estimated_rgba_bytes":retained_bytes}
