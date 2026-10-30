extends RefCounted
# Native-only profile storage. Never overwrite the original client's vault.
var directory:=""
var key:=""
var value:=""
var drafts: Dictionary={}
var failure:=""
var writes:=0
func configure(path: String) -> void: directory=path
func select(identity: String) -> bool:
	var next:=identity.sha256_text() if not identity.is_empty() else ""
	if next==key: return false
	flush(); key=next; value=""
	if key.is_empty(): return true
	if drafts.has(key): value=drafts[key]; return true
	var path:=directory.path_join(key+".txt")
	if FileAccess.file_exists(path):
		var file:=FileAccess.open(path,FileAccess.READ)
		if file==null: failure="Personal notes could not be read."; return true
		value=file.get_as_text(); file.close()
	return true
func edit(text: String) -> void:
	if key.is_empty() or text==value: return
	value=text; drafts[key]=text
func flush() -> bool:
	if drafts.is_empty(): return true
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory)!=OK: failure="Personal notes could not be saved."; return false
	for pending in drafts.keys():
		var target:=directory.path_join(str(pending)+".txt"); var temporary:=target+".tmp."+str(OS.get_process_id()); var file:=FileAccess.open(temporary,FileAccess.WRITE)
		if file==null: failure="Personal notes could not be saved."; return false
		file.store_string(str(drafts[pending])); file.flush(); var status:=file.get_error(); file.close()
		if status!=OK or DirAccess.rename_absolute(temporary,target)!=OK:
			if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
			failure="Personal notes could not be saved."; return false
		drafts.erase(pending); writes+=1
	failure=""; return true
