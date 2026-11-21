extends RefCounted
# Index selected local directories without reading their resource payloads.
# Reads use the inventoried filename, never a path supplied by a resource name.
const Extensions=preload("res://systems/native_data/resource_extensions.gd")
const TYPES=Extensions.TYPES
const LIMIT:=256*1024*1024
const Residency=preload("res://systems/native_data/resource_residency.gd")
var failure:=""
var index_identity:=""
func scan(directory: String, types: Array=[]) -> Dictionary:
	failure=""
	if not directory.is_absolute_path(): failure="Loose resources require an absolute selected directory"; return {}
	var root:=directory.simplify_path(); var folder:=DirAccess.open(root)
	if folder==null:
		if DirAccess.dir_exists_absolute(root): failure="Loose resource directory cannot be read"; return {}
		return {"entries":{},"directory":root}
	var names:=folder.get_files()
	if names.size()>1000000: failure="Loose resource directory exceeds bound"; return {}
	var cached:=Residency.index("loose-directory",[root,types,Extensions.REVISION],[var_to_bytes(names)],func():
		return {"value":scan_names(root,names,types),"error":""})
	index_identity=str(cached.identity)
	return cached.value
func scan_names(root: String,names: PackedStringArray,types: Array) -> Dictionary:
	var entries: Dictionary={}
	for filename in names:
		var extension:=filename.get_extension().to_lower(); var type:=int(TYPES.get(extension,-1))
		if type<0 or not types.is_empty() and not types.has(type): continue
		var name:=filename.get_basename().to_lower()
		if name.is_empty(): continue
		var path:=root.path_join(filename)
		# Like the original GetDirectoryList/AddDirectoryContents path, index
		# names/types in one directory pass. Stat actual payloads on demand;
		# unused override files must not each cost another filesystem query.
		entries[name+":"+str(type)]={"path":path,"type":type}
	return {"entries":entries,"directory":root}
func payload(entry: Dictionary) -> PackedByteArray:
	failure=""
	var path:=str(entry.path); var modified:=FileAccess.get_modified_time(path)
	if entry.has("modified") and modified!=int(entry.modified): failure="Selected loose resource was removed or changed"; return PackedByteArray()
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>LIMIT: failure="Selected loose resource is unavailable or exceeds bound"; return PackedByteArray()
	var size:=file.get_length(); var bytes:=file.get_buffer(size)
	if bytes.size()!=size or FileAccess.get_modified_time(path)!=modified: failure="Selected loose resource changed during read"; return PackedByteArray()
	return bytes
