extends RefCounted
# Native local-vault file mutation. A server character is never a file ticket.
# The renderer presents the original confirmation; this owner rechecks the
# captured byte identity before removing exactly one approved loose BIC.
const Hash=preload("res://systems/native_data/prepared_cache.gd")
const MAX_BYTES:=948*65535-16
static func accepted(result: int) -> bool: return result==1
static func next_selection(selected: int,count: int) -> int: return mini(selected,count-1)
static func reason(row: Dictionary,roots: Array) -> String:
	if row.get("source")=="server": return "Server-vault characters cannot be deleted from this client."
	if row.get("isDM",false): return "Dungeon Master vault management is not migrated yet."
	var ticket: Variant=row.get("nativeFile")
	if not ticket is Dictionary or ticket.get("storageSource") not in ["local","workshop","installed"]: return "This character is not stored in an editable local vault."
	var path:=str(ticket.get("path","")).replace("\\","/").simplify_path(); var digest:=str(ticket.get("sha256","")); var size: Variant=ticket.get("bytes")
	if ticket.get("format")!="native-local-bic-v1" or not path.is_absolute_path() or path.get_extension().to_lower()!="bic" or not roots.has(path.get_base_dir().to_lower()) or digest.length()!=64 or not digest.is_valid_hex_number(false) or digest!=digest.to_lower() or not (size is int or size is float) or not is_finite(float(size)) or float(size)!=floor(float(size)) or size<56 or size>MAX_BYTES: return "The local character file identity is unavailable."
	return ""
static func remove(row: Dictionary,roots: Array) -> Dictionary:
	var refused:=reason(row,roots)
	if not refused.is_empty(): return {"success":false,"error":refused}
	var ticket: Dictionary=row.nativeFile; var path:=str(ticket.path).replace("\\","/").simplify_path(); var parent:=DirAccess.open(path.get_base_dir())
	if parent==null or parent.is_link(path.get_file()): return {"success":false,"error":"The local character file is unavailable or is a link."}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"success":false,"error":"The local character file is no longer available."}
	if file.get_length()!=int(ticket.bytes): file.close(); return {"success":false,"error":"The character changed while confirmation was open. Select it again before deleting."}
	var bytes:=file.get_buffer(int(ticket.bytes)); file.close()
	if bytes.size()!=int(ticket.bytes) or bytes.slice(0,4).get_string_from_ascii()!="BIC " or Hash.digest(bytes)!=ticket.sha256: return {"success":false,"error":"The character changed while confirmation was open. Select it again before deleting."}
	# Original70e5b0 removes LOCALVAULT/DMVAULT, then drops the row even if
	# RemoveFile returns false. Installed80M bytes are not that loose alias.
	if ticket.storageSource=="installed": return {"success":true,"fileRemoved":false,"dismissInstalled":true,"error":""}
	# Original RemoveFile191460 calls _chmod(...,0x80) before unlinking.
	# Never change installed content's attributes on the alias-miss route.
	FileAccess.set_read_only_attribute(path,false)
	var status:=DirAccess.remove_absolute(path)
	if status!=OK: return {"success":false,"error":"The local character file could not be deleted."}
	return {"success":true,"fileRemoved":true,"dismissInstalled":false,"error":""}
