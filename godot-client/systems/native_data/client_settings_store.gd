extends RefCounted
# Godot owns profile metadata and current-user protected credentials. The
# original-server host may request an active key, but never owns this file.
const Protection=preload("res://systems/native_data/windows_protection.gd")
const PREFIX="NWN1"
const CURRENT_VERSION:=3
var directory: String
var file: String
var default_mods: String
var protection
var state: Dictionary={}
var error: String=""
var opened_bytes:=PackedByteArray()
var opened_existing:=false

func open(profile_directory: String,mods_directory: String="",helper: String="")->bool:
	if not profile_directory.is_absolute_path():error="Invalid settings directory";return false
	directory=profile_directory;file=directory.path_join("client-settings.json");default_mods=mods_directory
	protection=Protection.new()
	var executable:=helper if not helper.is_empty() else ProjectSettings.globalize_path("res://.cache/nwn79/windows-profile.exe")
	if not protection.open(executable):error="Windows protected storage is unavailable";return false
	opened_existing=FileAccess.file_exists(file)
	if not FileAccess.file_exists(file):
		state={"version":CURRENT_VERSION,"modsDirectory":default_mods,"loginProfiles":[],"activeProfileId":null};return true
	var source:=FileAccess.get_file_as_bytes(file)
	var parsed: Variant=JSON.parse_string(source.get_string_from_utf8())
	if not parsed is Dictionary or not validate(parsed):error="Saved client settings could not be read";close();return false
	opened_bytes=source
	state=parsed;state["loginProfiles"]=state.get("loginProfiles",[]);state["activeProfileId"]=state.get("activeProfileId",null)
	return true

func validate(value: Dictionary)->bool:
	var version:=int(value.get("version",0))
	if version not in [1,2,CURRENT_VERSION] or not value.get("modsDirectory",null) is String:return false
	var mods: String=value.modsDirectory
	if mods.length()>4096 or mods.to_utf8_buffer().has(0) or not mods.is_empty() and not mods.is_absolute_path():return false
	var disabled: Variant=value.get("disabledMods",[])
	if not disabled is Array or disabled.size()>10000:return false
	var mod_id:=RegEx.create_from_string("^(local|[0-9]{1,32})$")
	for id in disabled:
		if not id is String or mod_id.search(id)==null:return false
	var rows: Variant=value.get("loginProfiles",[])
	if not rows is Array or rows.size()>64:return false
	var ids:={}
	for row in rows:
		if not row is Dictionary or not valid_id(row.get("id",null)) or not valid_label(row.get("label",null)) or not valid_blob(row.get("protectedCdKey",null)) or version==CURRENT_VERSION and not current_blob(row.get("protectedCdKey",null)) or ids.has(row.id):return false
		ids[row.id]=true
	var active: Variant=value.get("activeProfileId",null)
	return (active==null or ids.has(active)) and valid_blob(value.get("protectedCdKey",null)) and (version!=CURRENT_VERSION or current_blob(value.get("protectedCdKey",null)))

func current_blob(value: Variant)->bool:
	if value==null:return true
	var blob:=Marshalls.base64_to_raw(str(value))
	return blob.size()>=5 and blob.slice(0,4).get_string_from_ascii()==PREFIX

func valid_blob(value: Variant)->bool:
	if value==null:return true
	return value is String and value.length()<=16384 and RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(value)!=null
func valid_label(value: Variant)->bool:
	if not value is String or value.length()<1 or value.length()>32 or value.strip_edges().is_empty():return false
	for ch in value.to_utf8_buffer():
		if ch<32 or ch==127:return false
	return true
func valid_id(value: Variant)->bool:
	if not value is String or value.length()!=36:return false
	for index in [8,13,18,23]:
		if value[index]!="-":return false
	for index in 36:
		if index in [8,13,18,23]:continue
		if value[index].to_lower() not in "0123456789abcdef":return false
	return true

func active_row(value: Dictionary)->Dictionary:
	for row in value.get("loginProfiles",[]):
		if row.id==value.get("activeProfileId",null):return row
	return value

func status()->Dictionary:
	var active:=active_row(state)
	var profiles:=[]
	for row in state.get("loginProfiles",[]):profiles.append({"id":row.id,"label":row.label,"playerName":row.playerName,"hasSavedCdKey":row.has("protectedCdKey")})
	return {"modsDirectory":state.get("modsDirectory",default_mods),"defaultModsDirectory":default_mods,"disabledMods":state.get("disabledMods",[]).duplicate(),"hasSavedCdKey":active.has("protectedCdKey"),"hasLegacyCdKey":state.has("protectedCdKey"),"protectedStorageAvailable":protection!=null and not protection.closed,"activeProfileId":state.get("activeProfileId",null),"loginProfiles":profiles}

func protect_key(value: String)->String:
	var key:=value.strip_edges().to_upper()
	var pattern:=RegEx.create_from_string("^[A-Z0-9]{5}(-[A-Z0-9]{5}){6}$")
	if pattern.search(key)==null:error="Enter a CD key with seven groups of five characters";return ""
	var secret:=key.to_utf8_buffer()
	var result: Dictionary=protection.protect(secret)
	secret.fill(0)
	if result.has("error"):error=str(result.error);return ""
	var blob: PackedByteArray=PREFIX.to_utf8_buffer();blob.append_array(result.bytes)
	return Marshalls.raw_to_base64(blob)

func cd_key()->Dictionary:
	var row:=active_row(state)
	if not row.has("protectedCdKey"):return {"error":"Save or enter a CD key before connecting"}
	var blob:=Marshalls.base64_to_raw(str(row.protectedCdKey))
	if blob.size()<5 or blob.slice(0,4).get_string_from_utf8()!=PREFIX:return {"error":"Saved key needs the existing-user upgrade"}
	var result: Dictionary=protection.unprotect(blob.slice(4))
	if result.has("error"):return {"error":"The saved CD key could not be unlocked for this Windows user"}
	var secret: PackedByteArray=result.bytes
	var key:=secret.get_string_from_utf8()
	secret.fill(0)
	return {"cdKey":key}

static func valid_cd_key_bytes(bytes: PackedByteArray)->bool:
	if bytes.size()!=41:return false
	for index in range(41):
		var value: int=bytes[index]
		if index in [5,11,17,23,29,35]:
			if value!=45:return false
		elif not (value>=48 and value<=57 or value>=65 and value<=90 or value>=97 and value<=122):return false
	return true

# One-time v1/v2 settings import. Version 3 is the durable marker. Prior
# Chromium credentials are deliberately retired; the user can enter a new
# protected key or use a temporary key. Preserve all other settings exactly.
func upgrade_legacy()->Dictionary:
	if int(state.get("version",0))>=CURRENT_VERSION:return {"alreadyCurrent":true,"imported":false,"discardedCredentials":0,"credentialReentryRequired":false}
	var next:=state.duplicate(true)
	var rows: Array=[next]
	rows.append_array(next.get("loginProfiles",[]))
	var discarded:=0
	for row in rows:
		if not row is Dictionary or not row.has("protectedCdKey"):continue
		if not current_blob(row.protectedCdKey):row.erase("protectedCdKey");discarded+=1
	var original:=FileAccess.get_file_as_bytes(file)
	if original.is_empty() or original!=opened_bytes:return {"error":"Existing settings changed before the backup; reopen the client before importing"}
	var backup:=file.get_base_dir().path_join("client-settings.pre-nwn79-"+Crypto.new().generate_random_bytes(16).hex_encode()+".json")
	var backup_file:=FileAccess.open(backup,FileAccess.WRITE)
	if backup_file==null:return {"error":"Existing settings backup could not be created"}
	backup_file.store_buffer(original);backup_file.flush();backup_file.close()
	if FileAccess.get_file_as_bytes(backup)!=original:return {"error":"Existing settings backup could not be verified"}
	if not commit(next,true):return {"error":"Existing settings could not be imported: "+error,"backup":backup}
	return {"imported":true,"backup":backup,"importedVersion":CURRENT_VERSION,"discardedCredentials":discarded,"credentialReentryRequired":discarded>0}

func commit(next: Dictionary,importing: bool=false)->bool:
	# Recovery edits on an unresolved old profile stay in the old version until
	# the full backup-and-verify import succeeds. Fresh/current writes stay v3.
	next.version=CURRENT_VERSION if importing or int(state.get("version",0))>=CURRENT_VERSION else int(state.get("version",2))
	if not validate(next):error="Invalid client settings";return false
	var exists_now:=FileAccess.file_exists(file)
	if exists_now!=opened_existing or exists_now and FileAccess.get_file_as_bytes(file)!=opened_bytes:error="Saved settings changed in another client; reopen before saving";return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="Settings directory could not be created";return false
	var temp:=file+"."+str(Time.get_ticks_usec())+".tmp"
	var writer:=FileAccess.open(temp,FileAccess.WRITE)
	if writer==null:error="Settings could not be written";return false
	var serialized:=JSON.stringify(next)+"\n"
	writer.store_string(serialized);writer.flush();writer.close()
	if DirAccess.rename_absolute(temp,file)!=OK:
		DirAccess.remove_absolute(temp);error="Settings could not be committed";return false
	if FileAccess.get_file_as_string(file)!=serialized:error="Settings readback could not be verified";return false
	opened_bytes=serialized.to_utf8_buffer();opened_existing=true
	state=next;error="";return true

func update(request: Dictionary)->bool:
	if request.keys().any(func(name):return name not in ["modsDirectory","disabledMods","cdKey","removeCdKey"]):error="Invalid client settings";return false
	if request.has("removeCdKey") and not request.removeCdKey is bool or request.has("cdKey") and not request.cdKey is String:error="Invalid protected-key request";return false
	var next:=state.duplicate(true)
	if request.has("modsDirectory"):
		var folder: Variant=request.modsDirectory
		if not folder is String or folder.length()>4096 or not folder.is_empty() and not folder.is_absolute_path() or not folder.is_empty() and not DirAccess.dir_exists_absolute(folder):error="Select a valid mods folder";return false
		if folder!=next.modsDirectory:next.disabledMods=[]
		next.modsDirectory=folder
	if request.has("disabledMods"):
		if not request.disabledMods is Array or request.disabledMods.size()>10000:error="Invalid mod selection";return false
		for id in request.disabledMods:
			if not id is String or RegEx.create_from_string("^(local|[0-9]{1,32})$").search(id)==null:error="Invalid mod selection";return false
		next.disabledMods=request.disabledMods.duplicate()
	if request.get("removeCdKey",false) and request.has("cdKey"):error="Choose key replacement or removal";return false
	var target:=active_row(next)
	if request.has("cdKey") and not str(request.cdKey).is_empty():
		var protected:=protect_key(str(request.cdKey))
		if protected.is_empty():return false
		target.protectedCdKey=protected
	if request.get("removeCdKey",false):target.erase("protectedCdKey")
	return commit(next)

func new_id()->String:
	var raw:=Crypto.new().generate_random_bytes(16).hex_encode()
	return raw.substr(0,8)+"-"+raw.substr(8,4)+"-"+raw.substr(12,4)+"-"+raw.substr(16,4)+"-"+raw.substr(20,12)

func save_profile(request: Dictionary)->bool:
	if request.keys().any(func(name):return name not in ["id","label","playerName","cdKey"]) or not valid_label(request.get("label",null)) or not valid_label(request.get("playerName",null)) or request.has("cdKey") and not request.cdKey is String:
		error="Enter a profile name and player name (up to 32 characters)";return false
	var next:=state.duplicate(true)
	var label:=str(request.label).strip_edges();var player:=str(request.playerName).strip_edges()
	var id:=str(request.get("id",""));var row: Dictionary={}
	if id.is_empty():
		if next.loginProfiles.size()>=64:error="You can save up to 64 login profiles";return false
		row={"id":new_id()}
	else:
		if not valid_id(id):error="This login profile no longer exists";return false
		for candidate in next.loginProfiles:
			if candidate.id==id:row=candidate;break
		if row.is_empty():error="This login profile no longer exists";return false
	for other in next.loginProfiles:
		if other.id!=row.id and str(other.label).to_lower()==label.to_lower():error="Choose a unique profile name";return false
	if request.has("cdKey") and not str(request.cdKey).is_empty():
		var protected:=protect_key(str(request.cdKey))
		if protected.is_empty():return false
		row.protectedCdKey=protected
	elif not row.has("protectedCdKey") and next.loginProfiles.is_empty() and next.has("protectedCdKey"):row.protectedCdKey=next.protectedCdKey
	if not row.has("protectedCdKey"):error="Enter a CD key for this login profile";return false
	row.label=label;row.playerName=player
	if id.is_empty():next.loginProfiles.append(row)
	next.activeProfileId=row.id
	return commit(next)

func select_profile(id: Variant)->bool:
	var next:=state.duplicate(true)
	if id!=null:
		var found:=false
		for row in next.loginProfiles:
			if row.id==id and row.has("protectedCdKey"):found=true;break
		if not found:error="Select a saved login profile with a CD key";return false
	next.activeProfileId=id
	return commit(next)

func delete_profile(id: Variant)->bool:
	if not valid_id(id):error="This login profile no longer exists";return false
	var next:=state.duplicate(true)
	var found:=false
	for index in range(next.loginProfiles.size()-1,-1,-1):
		if next.loginProfiles[index].id==id:next.loginProfiles.remove_at(index);found=true
	if not found:error="This login profile no longer exists";return false
	if next.activeProfileId==id:next.activeProfileId=null
	return commit(next)

func close()->void:
	if protection!=null:protection.close();protection=null
