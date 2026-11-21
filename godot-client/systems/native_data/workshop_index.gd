extends RefCounted
const ALIASES=["portraits","hak","tlk","modules","override","ambient","music","localvault","dmvault"]
var failure:=""
static func item_id(value: String) -> bool:
	if value.is_empty(): return false
	for index in value.length():
		var c:=value.unicode_at(index)
		if c<48 or c>57: return false
	return true
func scan(directory: String, disabled: Array=[]) -> Array:
	failure=""
	if directory.is_empty(): return []
	if not directory.is_absolute_path(): failure="Invalid selected Workshop directory/options"; return []
	var root:=directory.simplify_path(); var folder:=DirAccess.open(root)
	if folder==null:
		if DirAccess.dir_exists_absolute(root): failure="Selected Workshop directory is unreadable"
		elif FileAccess.file_exists(root): failure="Selected Workshop path is not a directory"
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
		if file==null:failure="Steam installed-item metadata is unavailable";return []
		var text:=file.get_as_text()
		var start:=text.find('"WorkshopItemsInstalled"')
		if start>=0:
			var open:=text.find("{",start)
			if open<0:failure="Steam installed-item section is malformed";return []
			var depth:=0;var end:=open
			while end<text.length():
				if text[end]=="{":depth+=1
				if text[end]=="}":
					depth-=1
					if depth==0:break
				end+=1
			var section:=text.substr(open+1,end-open-1)
			var pattern:=RegEx.new()
			if pattern.compile('(?m)^\\s*"(\\d+)"\\s*\\r?\\n\\s*\\{')!=OK:failure="Steam installed-item matcher is unavailable";return []
			order=[]
			for match_row in pattern.search_all(section):
				var id:=match_row.get_string(1)
				if installed.has(id):order.append(id)
	var roots: Array=[]
	if local and not disabled.has("local"): roots.append({"id":"local","directory":root})
	for id in order:
		if not disabled.has(id): roots.append({"id":id,"directory":root.path_join(id)})
	return roots

func directories_for(roots: Array, alias: String) -> Array[String]:
	failure=""
	if not ALIASES.has(alias): failure="Unsupported Workshop resource directory"; return []
	var result: Array[String]=[]
	for selected in roots:
		if not selected is Dictionary or not str(selected.get("directory","")).is_absolute_path(): failure="Invalid selected Workshop root"; return []
		var path:=str(selected.directory).path_join(alias)
		var folder:=DirAccess.open(path)
		if folder!=null:
			result.append(path)
		elif DirAccess.dir_exists_absolute(path):
			failure="Selected Workshop resource directory is unreadable"
			return []
		elif FileAccess.file_exists(str(selected.directory)):
			failure="Selected Workshop root is not a directory"
			return []
	return result
