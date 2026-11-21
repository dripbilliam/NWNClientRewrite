extends RefCounted
# Godot owns profile metadata and current-user protected credentials. The
# original-server host may request an active key, but never owns this file.
const Protection=preload("res://systems/native_data/windows_protection.gd")
const PREFIX="NWN1"
const CURRENT_VERSION:=3
const GODOT_SETTINGS_FILE:="godot-client-settings.json"
const SHARED_SETTINGS_FILE:="client-settings.json"
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
	close()
	error="";state={};opened_bytes=PackedByteArray();opened_existing=false
	directory=profile_directory;file=directory.path_join(GODOT_SETTINGS_FILE);default_mods=mods_directory
	var parsed: Variant=null
	if FileAccess.file_exists(file):
		opened_existing=true
		opened_bytes=FileAccess.get_file_as_bytes(file)
		parsed=JSON.parse_string(opened_bytes.get_string_from_utf8())
	else:
		# Existing Godot v3 files may already use the shared filename. Keep
		# using an admitted v3 file in place and leave older files untouched.
		var shared_path:=directory.path_join(SHARED_SETTINGS_FILE)
		if FileAccess.file_exists(shared_path):
			var source:=FileAccess.get_file_as_bytes(shared_path)
			var shared: Variant=JSON.parse_string(source.get_string_from_utf8())
			if shared is Dictionary and shared.get("version")==CURRENT_VERSION:
				file=shared_path;opened_existing=true;opened_bytes=source;parsed=shared
	if opened_existing and (not parsed is Dictionary or not validate(parsed)):
		error="Saved client settings could not be read";return false
	protection=Protection.new()
	var executable:=helper if not helper.is_empty() else ProjectSettings.globalize_path("res://.cache/nwn79/windows-profile.exe")
	if not protection.open(executable):protection.close();protection=null
	if not opened_existing:
		state={"version":CURRENT_VERSION,"modsDirectory":default_mods,"installDirectory":"","loginProfiles":[],"activeProfileId":null};return true
	state=parsed;state["loginProfiles"]=[] if state.get("loginProfiles",[])==null else state.get("loginProfiles",[]);state["activeProfileId"]=state.get("activeProfileId",null)
	return true

func validate(value: Dictionary)->bool:
	var raw_version: Variant=value.get("version",null)
	if not (raw_version is int or raw_version is float) or not is_finite(float(raw_version)) or float(raw_version)!=floor(float(raw_version)):return false
	if int(raw_version)!=CURRENT_VERSION or not value.get("modsDirectory",null) is String:return false
	var mods: String=value.modsDirectory
	if js_length(mods)>4096 or mods.to_utf8_buffer().has(0) or not mods.is_empty() and not mods.is_absolute_path():return false
	var install: Variant=value.get("installDirectory","")
	if not install is String or js_length(str(install))>4096 or install.to_utf8_buffer().has(0) or not install.is_empty() and not install.is_absolute_path():return false
	var disabled: Variant=value.get("disabledMods",[])
	if not disabled is Array or disabled.size()>10000:return false
	var mod_id:=RegEx.create_from_string("^(local|[0-9]{1,32})$")
	for id in disabled:
		if not id is String or mod_id.search(id)==null:return false
	var rows: Variant=value.get("loginProfiles",[])
	if rows==null:rows=[]
	if not rows is Array or rows.size()>64:return false
	var ids:={}
	for row in rows:
		if not row is Dictionary or not valid_id(row.get("id",null)) or not valid_label(row.get("label",null)) or not valid_label(row.get("playerName",null)) or row.has("protectedCdKey") and row.protectedCdKey==null or not valid_blob(row.get("protectedCdKey",null)) or not current_blob(row.get("protectedCdKey",null)) or ids.has(row.id):return false
		ids[row.id]=true
	var active: Variant=value.get("activeProfileId",null)
	return (active==null or ids.has(active)) and (not value.has("protectedCdKey") or value.protectedCdKey!=null) and valid_blob(value.get("protectedCdKey",null)) and current_blob(value.get("protectedCdKey",null))

func current_blob(value: Variant)->bool:
	if value==null:return true
	var blob:=Marshalls.base64_to_raw(str(value))
	return blob.size()>=5 and blob.slice(0,4).get_string_from_ascii()==PREFIX

func js_length(value: String)->int:
	var units:=0
	for byte in value.to_utf8_buffer():
		if (int(byte) & 192)==128:continue
		units+=2 if int(byte)>=240 else 1
	return units

func valid_blob(value: Variant)->bool:
	if value==null:return true
	return value is String and js_length(str(value))<=16384 and RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(value)!=null
func valid_label(value: Variant)->bool:
	if not value is String or js_length(str(value))<1 or js_length(str(value))>32 or value.strip_edges().is_empty():return false
	for ch in value.to_utf8_buffer():
		if ch<32 or ch==127:return false
	return true
func valid_id(value: Variant)->bool:
	if not value is String or value.length()!=36:return false
	for index in [8,13,18,23]:
		if value[index]!="-":return false
	for index in 36:
		if index in [8,13,18,23]:continue
		if value[index] not in "0123456789abcdef":return false
	return true

func has_saved_key(row: Dictionary)->bool:
	return row.has("protectedCdKey") and row.protectedCdKey is String and not str(row.protectedCdKey).is_empty()

func active_row(value: Dictionary)->Dictionary:
	for row in value.get("loginProfiles",[]):
		if row.id==value.get("activeProfileId",null):return row
	return value

func status()->Dictionary:
	var active:=active_row(state)
	var profiles:=[]
	for row in state.get("loginProfiles",[]):profiles.append({"id":row.id,"label":row.label,"playerName":row.playerName,"hasSavedCdKey":has_saved_key(row)})
	return {"modsDirectory":state.get("modsDirectory",default_mods),"installDirectory":state.get("installDirectory",""),"defaultModsDirectory":default_mods,"disabledMods":state.get("disabledMods",[]).duplicate(),"hasSavedCdKey":has_saved_key(active),"hasLegacyCdKey":has_saved_key(state),"protectedStorageAvailable":protection!=null and not protection.closed,"activeProfileId":state.get("activeProfileId",null),"loginProfiles":profiles}

func protect_key(value: String)->String:
	var key:=value.strip_edges().to_upper()
	var pattern:=RegEx.create_from_string("^[A-Z0-9]{5}(-[A-Z0-9]{5}){6}$")
	if pattern.search(key)==null:error="Enter a CD key with seven groups of five characters";return ""
	if protection==null or protection.closed:error="Windows-protected key storage is unavailable";return ""
	var secret:=key.to_utf8_buffer()
	var result: Dictionary=protection.protect(secret)
	secret.fill(0)
	if result.has("error"):error=str(result.error);return ""
	var blob: PackedByteArray=PREFIX.to_utf8_buffer();blob.append_array(result.bytes)
	return Marshalls.raw_to_base64(blob)

func cd_key()->Dictionary:
	var row:=active_row(state)
	if not has_saved_key(row):return {"error":"Save or enter a CD key before connecting"}
	if protection==null or protection.closed:return {"error":"Windows-protected key storage is unavailable"}
	var blob:=Marshalls.base64_to_raw(str(row.protectedCdKey))
	if blob.size()<5 or blob.slice(0,4).get_string_from_utf8()!=PREFIX:return {"error":"Saved CD key storage is invalid"}
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

func commit(next: Dictionary)->bool:
	next.version=CURRENT_VERSION
	if not validate(next):error="Invalid client settings";return false
	var exists_now:=FileAccess.file_exists(file)
	if exists_now!=opened_existing or exists_now and FileAccess.get_file_as_bytes(file)!=opened_bytes:error="Saved settings changed in another client; reopen before saving";return false
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:error="Settings directory could not be created";return false
	var temp:=file+"."+Crypto.new().generate_random_bytes(16).hex_encode()+".tmp"
	var writer:=FileAccess.open(temp,FileAccess.WRITE)
	if writer==null:error="Settings could not be written";return false
	var serialized:=JSON.stringify(next)+"\n"
	writer.store_string(serialized);writer.flush();writer.close()
	if FileAccess.get_file_as_string(temp)!=serialized:
		DirAccess.remove_absolute(temp);error="Settings could not be written";return false
	if DirAccess.rename_absolute(temp,file)!=OK:
		DirAccess.remove_absolute(temp);error="Settings could not be committed";return false
	if FileAccess.get_file_as_string(file)!=serialized:error="Settings readback could not be verified";return false
	opened_bytes=serialized.to_utf8_buffer();opened_existing=true
	state=next;error="";return true

func update(request: Dictionary)->bool:
	if request.keys().any(func(name):return name not in ["installDirectory","modsDirectory","disabledMods","cdKey","removeCdKey"]):error="Invalid client settings";return false
	var next:=state.duplicate(true)
	if request.has("installDirectory"):
		var install: Variant=request.installDirectory
		if not install is String or install.is_empty() or js_length(str(install))>4096 or install.to_utf8_buffer().has(0) or not install.is_absolute_path() or not DirAccess.dir_exists_absolute(install):error="Select a valid NWN installation folder";return false
		next.installDirectory=install.simplify_path()
	if request.has("modsDirectory"):
		var folder: Variant=request.modsDirectory
		if not folder is String or js_length(str(folder))>4096 or folder.to_utf8_buffer().has(0) or not folder.is_empty() and not folder.is_absolute_path() or not folder.is_empty() and not DirAccess.dir_exists_absolute(folder):error="Select a valid mods folder";return false
		var selected_folder: String=folder.simplify_path() if not folder.is_empty() else ""
		if selected_folder!=next.modsDirectory:next.disabledMods=[]
		next.modsDirectory=selected_folder
	if request.has("disabledMods"):
		if not request.disabledMods is Array or request.disabledMods.size()>10000:error="Invalid mod selection";return false
		var selected: Array=[]
		var seen: Dictionary={}
		for id in request.disabledMods:
			if not id is String or RegEx.create_from_string("^(local|[0-9]{1,32})$").search(id)==null:error="Invalid mod selection";return false
			if not seen.has(id):seen[id]=true;selected.append(id)
		next.disabledMods=selected
	if request.has("removeCdKey") and not request.removeCdKey is bool:error="Invalid key removal option";return false
	if request.get("removeCdKey",false) and request.has("cdKey") and not str(request.cdKey).is_empty():error="Choose key replacement or removal";return false
	if request.has("cdKey") and not request.cdKey is String:error="Invalid CD-key format";return false
	var target:=active_row(next)
	if request.has("cdKey") and not str(request.cdKey).is_empty():
		var protected:=protect_key(str(request.cdKey))
		if protected.is_empty():return false
		target.protectedCdKey=protected
	if request.get("removeCdKey",false):target.erase("protectedCdKey")
	return commit(next)

func new_id()->String:
	var bytes:=Crypto.new().generate_random_bytes(16)
	bytes[6]=(int(bytes[6]) & 15) | 64
	bytes[8]=(int(bytes[8]) & 63) | 128
	var raw:=bytes.hex_encode()
	return raw.substr(0,8)+"-"+raw.substr(8,4)+"-"+raw.substr(12,4)+"-"+raw.substr(16,4)+"-"+raw.substr(20,12)

func save_profile(request: Dictionary)->bool:
	if request.keys().any(func(name):return name not in ["id","label","playerName","cdKey"]) or not valid_label(request.get("label",null)) or not valid_label(request.get("playerName",null)) or request.has("cdKey") and not request.cdKey is String:
		error="Enter a profile name and player name (up to 32 characters)";return false
	var next:=state.duplicate(true)
	var label:=str(request.label).strip_edges();var player:=str(request.playerName).strip_edges()
	if request.has("id") and not valid_id(request.id):error="This login profile no longer exists";return false
	var id:=str(request.get("id",""));var row: Dictionary={}
	if id.is_empty():
		if next.loginProfiles.size()>=64:error="You can save up to 64 login profiles";return false
		row={"id":new_id()}
	else:
		if not valid_id(id):error="This login profile no longer exists";return false
		for candidate in next.loginProfiles:
			if candidate.id==id:row=candidate;break
		if row.is_empty():error="This login profile no longer exists";return false
	if request.has("cdKey") and not str(request.cdKey).is_empty():
		var protected:=protect_key(str(request.cdKey))
		if protected.is_empty():return false
		row.protectedCdKey=protected
	elif not has_saved_key(row) and next.loginProfiles.is_empty() and has_saved_key(next):row.protectedCdKey=next.protectedCdKey
	if not has_saved_key(row):error="Enter a CD key for this login profile";return false
	# client_settings.mjs compares labels with the host locale's casing rules.
	var text_server:=TextServerManager.get_primary_interface()
	var language:=OS.get_locale_language()
	var folded_label:=text_server.string_to_lower(label,language)
	for other in next.loginProfiles:
		if other.id!=row.id and text_server.string_to_lower(str(other.label),language)==folded_label:error="Choose a unique profile name";return false
	row.label=label;row.playerName=player
	if id.is_empty():next.loginProfiles.append(row)
	next.activeProfileId=row.id
	return commit(next)

func select_profile(id: Variant)->bool:
	var next:=state.duplicate(true)
	if id!=null:
		var found:=false
		for row in next.loginProfiles:
			if row.id==id and has_saved_key(row):found=true;break
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
