extends RefCounted
# Godot-owned equivalents of the former startup host's Windows profile and
# installed workshop discovery. These paths contain no credential material.
const Settings=preload("res://systems/native_data/client_settings_store.gd")

static func resolve(install: String,appdata: String="",documents: String="",steam_directory: String="")->Dictionary:
	if appdata.is_empty():appdata=OS.get_environment("APPDATA")
	if documents.is_empty():documents=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if steam_directory.is_empty():steam_directory=OS.get_environment("ProgramFiles(x86)").path_join("Steam") if not OS.get_environment("ProgramFiles(x86)").is_empty() else "C:/Program Files (x86)/Steam"
	if not install.is_absolute_path() or not appdata.is_absolute_path() or not documents.is_absolute_path():return {"error":"Native startup paths are unavailable"}
	var profile:=documents.path_join("Neverwinter Nights")
	for name in ["Neverwinter Nights.0","Neverwinter Nights"]:
		var candidate:=documents.path_join(name)
		if FileAccess.file_exists(candidate.path_join("nwsync/nwsyncmeta.sqlite3")):profile=candidate;break
	var mods: Dictionary=default_mods(install,steam_directory)
	if mods.has("error"):return mods
	return {"settingsDirectory":appdata.path_join("nwn-model-viewer-research"),"userDirectory":profile,"defaultModsDirectory":str(mods.directory)}

static func default_mods(install: String,steam_directory: String)->Dictionary:
	var candidates: Array[String]=[]
	var directory:=install.simplify_path()
	for _index in range(6):
		candidates.append(directory.path_join("steamapps/workshop/content/704450"))
		var parent:=directory.get_base_dir()
		if parent==directory:break
		directory=parent
	var libraries:=steam_directory.path_join("steamapps/libraryfolders.vdf")
	if FileAccess.file_exists(libraries):
		var source:=FileAccess.open(libraries,FileAccess.READ)
		if source==null:return {"error":"Steam workshop library file could not be read"}
		var text:=source.get_as_text()
		source.close()
		var pattern:=RegEx.create_from_string('"path"\\s*"([^"]+)"')
		for row in pattern.search_all(text):
			candidates.append(str(row.get_string(1)).replace("\\\\","\\").path_join("steamapps/workshop/content/704450"))
	candidates.append(steam_directory.path_join("steamapps/workshop/content/704450"))
	var seen: Dictionary={}
	for candidate in candidates:
		var path:=candidate.simplify_path()
		if seen.has(path.to_lower()):continue
		seen[path.to_lower()]=true
		if DirAccess.dir_exists_absolute(path):return {"directory":path}
	return {"directory":""}

static func direct_ticket(install: String,profile_override: String="",settings_override: String="")->Dictionary:
	var startup: Dictionary=resolve(install)
	if startup.has("error"):return startup
	var profile:=profile_override if not profile_override.is_empty() else str(startup.userDirectory)
	var settings_directory:=settings_override if not settings_override.is_empty() else str(startup.settingsDirectory)
	if not profile.is_absolute_path() or not settings_directory.is_absolute_path():return {"error":"Native profile or settings location is unavailable"}
	var settings:=Settings.new()
	if not settings.open(settings_directory,str(startup.defaultModsDirectory)):
		settings.close()
		return {"error":"Saved client settings are unavailable"}
	var status: Dictionary=settings.status()
	settings.close()
	var active_name: String=""
	for row in status.loginProfiles:
		if row.id==status.activeProfileId:active_name=str(row.playerName);break
	var cache:=profile.path_join("replacement-client/server-content")
	return {"featureSelection":{},"directProfile":{"name":active_name,"hasSavedCdKey":status.hasSavedCdKey},"preworkSources":{"install":install,"profileDirectory":profile,"modsDirectory":status.modsDirectory,"disabledMods":status.disabledMods,"cacheDirectory":cache,"nativeDirectory":profile.path_join("nwsync"),"helper":ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")},"localCharacterRoots":[install.path_join("data/lcv"),profile.path_join("localvault"),settings_directory.path_join("network-characters/blobs")]}
