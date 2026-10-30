extends RefCounted
const Vdf=preload("res://systems/native_data/steam_vdf.gd")
const ALIASES=["portraits","hak","tlk","modules","override","ambient","music","localvault","dmvault"]
var failure:=""
static func item_id(value: String) -> bool:
	if value.is_empty() or value.length()>32: return false
	for index in value.length():
		var c:=value.unicode_at(index)
		if c<48 or c>57: return false
	return true
func scan(directory: String, disabled: Array=[]) -> Array:
	failure=""
	if directory.is_empty(): return []
	if not directory.is_absolute_path() or disabled.size()>10000: failure="Invalid selected Workshop directory/options"; return []
	for id in disabled:
		if not id is String or id!="local" and not item_id(id): failure="Invalid disabled Workshop item"; return []
	var root:=directory.simplify_path(); var folder:=DirAccess.open(root)
	if folder==null:
		if DirAccess.dir_exists_absolute(root): failure="Selected Workshop directory is unreadable"
		return []
	var names:=Array(folder.get_directories()); names.sort()
	var installed: Array=[]; var local:=false
	for name in names:
		if folder.is_link(str(name)): continue
		if ALIASES.has(str(name).to_lower()): local=true
		if item_id(str(name)): installed.append(name)
	var order:=installed.duplicate(); var metadata:=root.path_join("../../appworkshop_704450.acf").simplify_path()
	if FileAccess.file_exists(metadata):
		var file:=FileAccess.open(metadata,FileAccess.READ)
		if file==null or file.get_length()>Vdf.MAX_BYTES: failure="Steam installed-item metadata is unavailable or exceeds bound"; return []
		var parser:=Vdf.new(); var rows:=parser.parse(file.get_as_text())
		if not parser.failure.is_empty(): failure=parser.failure; return []
		var section:=Vdf.section(rows,"WorkshopItemsInstalled")
		if not section.is_empty():
			order=[]
			for row in section[0]:
				if row.value is Array and installed.has(row.key) and not order.has(row.key): order.append(row.key)
	var roots: Array=[]
	if local and not disabled.has("local"): roots.append({"id":"local","directory":root})
	for id in order:
		if not disabled.has(id): roots.append({"id":id,"directory":root.path_join(id)})
	return roots
