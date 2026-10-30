extends RefCounted
# Offline discovery for the separate UI bake. Standard model states are data;
# native pixels still require the existing graphical GUI renderer. This is not
# a model/world-prework alias, nor a claim that generated UI poses are complete.
const Gff=preload("res://systems/native_data/gff_document.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const PREFIXES=["gui_","pnl_","ctl_","pb_","qb_","inv_"]
const STATES=["up","hilite","down","disabled","checkedup","checkeddown","uncheckedup","uncheckeddown"]
static func collect(node: Dictionary,models: Dictionary,fonts: Dictionary) -> void:
	var model:=str(node.get("Obj_ResRef","")).to_lower()
	if not model.is_empty() and model!="****": models[model]=true
	var font:=str(node.get("Obj_Caption",{}).get("AurString_Font",""))
	if not font.is_empty() and font!="****": fonts[font]=true
	for child in node.get("Obj_ChildList",[]): collect(child,models,fonts)
static func discover(catalog) -> Dictionary:
	var gui_names: Array=catalog.resource_names(2047); gui_names.sort()
	var found: Dictionary={}; var fonts: Dictionary={}; var sources: Array=[]; var issues: Array=[]
	for name in gui_names:
		var bytes: PackedByteArray=catalog.get_resource(str(name),2047)
		if not catalog.failure.is_empty(): issues.append({"resource":name,"error":catalog.failure}); continue
		var reader:=Gff.new(); var document:=reader.parse(bytes,"GUI ")
		if not reader.failure.is_empty(): issues.append({"resource":name,"error":reader.failure}); continue
		collect(document.root,found,fonts); sources.append({"name":name,"sha256":Cache.digest(bytes),"bytes":bytes.size()})
	# Also discover programmatic original widgets which need no GUI file, such
	# as quickbar banks and inventory grids. Exact generated poses and replacement
	# textures must additionally be captured from live native UI bake consumers.
	for name in catalog.resource_names(2002):
		if PREFIXES.any(func(prefix):return str(name).begins_with(prefix)): found[str(name)]=true
	if catalog.has_resource("scrollbar_simple",2002): found.scrollbar_simple=true
	var available: Array=[]; var missing: Array=[]
	for name in found:
		if catalog.has_resource(str(name),2002): available.append(str(name))
		else: missing.append(str(name))
	available.sort(); missing.sort(); var font_names: Array=fonts.keys(); font_names.sort()
	return {"models":available,"fonts":font_names,"gui_sources":sources,"missing_references":missing,"issues":issues,"native_data_only":true,"pixels_prebaked":false,"full_ui_prebake":false}
static func states(model: Dictionary) -> Array:
	var found: Dictionary={}
	for clip in model.get("animations",[]):
		var name:=str(clip.get("name","")).to_lower()
		if name in STATES: found[name]=true
	var result: Array=[""]
	for state in STATES:
		if found.has(state): result.append(state)
	return result
