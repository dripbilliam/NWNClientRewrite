extends SceneTree
const Store=preload("res://systems/native_data/client_settings_store.gd")
const CryptoOwner=preload("res://systems/native_data/native_network_crypto.gd")
const Build=preload("res://systems/native_data/native_installed_network_build.gd")
const Identity=preload("res://systems/native_data/native_login_identity.gd")
const Peer=preload("res://systems/native_data/native_network_peer.gd")
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Admission=preload("res://systems/native_data/native_resource_admission.gd")
const NWSyncStore=preload("res://systems/native_data/nwsync_store.gd")
const Characters=preload("res://systems/native_data/native_server_characters.gd")
var session: RefCounted
var identity: RefCounted
var settings: RefCounted
var request_status:=false
var capture_status:=false
var status_requested:=false
var status_deadline:=0
var client_language:=0
var request_character_list:=false
var list_requested:=false

func _initialize()->void:
	var options: Dictionary={}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var at:=argument.find("=");options[argument.substr(2,at-2)]=argument.substr(at+1)
	var host:=str(options.get("host",""))
	var port:=int(options.get("port","0"))
	request_status=str(options.get("status","false"))=="true"
	request_character_list=str(options.get("character-list","false"))=="true"
	if request_character_list:request_status=true
	capture_status=str(options.get("capture-status","false"))=="true"
	if host.is_empty() or port<1 or port>65535:fail("Server endpoint is unavailable");return
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/nwn-network-crypto.exe")
	var crypto=CryptoOwner.new()
	if not crypto.open(helper):fail("Native crypto helper is unavailable");return
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var build: Dictionary=Build.read(install,crypto)
	crypto.close()
	if build.has("error"):fail(str(build.error));return
	var talk:=FileAccess.get_file_as_bytes(install.path_join("lang/en/data/dialog.tlk"))
	if talk.size()<12 or talk.slice(0,8).get_string_from_ascii()!="TLK V3.0":fail("Original talk-table language is unavailable");return
	var language: int=talk.decode_u32(8)
	client_language=language
	settings=Store.new()
	if not settings.open(OS.get_environment("APPDATA").path_join("nwn-model-viewer-research")):fail("Saved client settings are unavailable");return
	var credential: Dictionary=settings.cd_key()
	if credential.has("error"):fail("Saved CD key is unavailable");return
	var active: Dictionary=settings.active_row(settings.state)
	var player_name:=str(active.get("playerName",""))
	identity=Identity.new()
	if not identity.configure(str(credential.cdKey)):fail("Saved CD key format is unavailable");return
	credential.cdKey=""
	session=Peer.new()
	var metadata: Dictionary={"connectionType":16,"build":build.build,"language":language,"name":player_name,"legacyPublicKey":"","platformId":build.platformId,"platformIdentifier":build.platformIdentifier}
	if not session.connect_to_server(host,port,identity,metadata,helper):fail(session.error);return
	print("NWN79 Godot direct login started")

func _process(_delta: float)->bool:
	if session==null:return false
	var result: Dictionary=session.poll()
	if result.has("error"):fail(str(result.error));return false
	if result.get("admitted",false):
		if not request_status:
			print("NWN79 Godot direct login admitted")
			cleanup();quit(0)
		elif not status_requested:
			if not session.send_game_message(PackedByteArray([112,1,0])):fail("Native status request failed");return false
			status_requested=true;status_deadline=Time.get_ticks_msec()+5000
		elif result.get("records",[]).size()>0:
			var uncompressed:=0;var compressed:=0;var game_envelopes:=0;var kinds: Array[String]=[]
			for record in result.records:
				var bytes: PackedByteArray=record.bytes
				if bytes.size()<12:continue
				if int(bytes[7]) & 4:compressed+=1
				else:
					uncompressed+=1
					if bytes.size()>=15 and bytes[12]==80:
						game_envelopes+=1;kinds.append(str(bytes[13])+"/"+str(bytes[14]))
						if capture_status and bytes[13]==1 and bytes[14]==3:
							var folder:=ProjectSettings.globalize_path("res://.cache/nwn79")
							DirAccess.make_dir_recursive_absolute(folder)
							var output:=FileAccess.open(folder.path_join("arelith-resource-record.bin"),FileAccess.WRITE)
							if output!=null:output.store_buffer(bytes);output.close()
						if bytes[13]==1 and bytes[14]==3 and not inspect_resource_admission(bytes):return false
						if bytes[13]==1 and bytes[14]==3 and request_character_list:
							if not session.send_game_message(PackedByteArray([112,17,1])):fail("Server character-list request failed");return false
							list_requested=true;status_deadline=Time.get_ticks_msec()+5000
							return false
					if bytes.size()>=15 and bytes[12]==80 and bytes[13]==17 and bytes[14]==2 and list_requested:
						var characters: Dictionary=Characters.decode_record(bytes)
						if characters.has("error"):fail("Server character list is invalid: "+str(characters.error));return false
						print("NWN79 Godot direct server character list received: count=",characters.characters.size())
						cleanup();quit(0);return false
			if list_requested:return false
			print("NWN79 Godot direct game record received: uncompressed=",uncompressed," compressed=",compressed," game_envelopes=",game_envelopes," kinds=",",".join(kinds))
			cleanup();quit(0)
		elif Time.get_ticks_msec()>status_deadline:fail("Native status response timed out");return false
	return false

func inspect_resource_admission(record: PackedByteArray)->bool:
	var requirements: Dictionary=Requirements.decode_record(record)
	if requirements.has("error"):fail("Native resource requirements are invalid");return false
	var documents:=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var profile:=documents.path_join("Neverwinter Nights.0")
	var store:=NWSyncStore.new()
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	if not store.configure(profile.path_join("replacement-client/server-content"),profile.path_join("nwsync"),helper):fail("Installed NWSync reader is unavailable");return false
	var resolution: Dictionary=Admission.resolve_cached(requirements,store,client_language,[profile])
	store.close()
	if resolution.has("error") or not resolution.get("ready",false):
		fail("Required server content is unavailable: "+str(resolution.get("error","missing="+str(resolution.get("missing",[]).size())+" blobs="+str(resolution.get("missing_blob_count",0)))))
		return false
	print("NWN79 Godot direct resource admission ready: manifests=",resolution.catalogs.size()," named=",resolution.named.size()," missing_blobs=",resolution.missing_blob_count)
	return true

func cleanup()->void:
	if session!=null:session.close();session=null
	if identity!=null:identity.dispose();identity=null
	if settings!=null:settings.close();settings=null

func fail(stage: String)->void:
	printerr("NWN79 Godot direct login failed: "+stage)
	cleanup();quit(1)
