extends SceneTree
const Requirements=preload("res://systems/native_data/native_resource_requirements.gd")
const Admission=preload("res://systems/native_data/native_resource_admission.gd")
const Store=preload("res://systems/native_data/nwsync_store.gd")
const Sources=preload("res://systems/native_data/native_resource_sources.gd")
const SessionCatalog=preload("res://systems/native_data/session_catalog.gd")
const Session=preload("res://systems/native_data/native_network_session.gd")

func _initialize()->void:
	var packet:=FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://.cache/nwn79/arelith-resource-record.bin"))
	var requirements: Dictionary=Requirements.decode_record(packet)
	if requirements.has("error"):fail("Original Arelith resource record unavailable");return
	var profile:=OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("Neverwinter Nights.0")
	var install:=ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")
	var cache:=profile.path_join("replacement-client/server-content")
	var native_directory:=profile.path_join("nwsync")
	var helper:=ProjectSettings.globalize_path("res://../tooling/native/content-reader/nwn-content-reader.exe")
	var store:=Store.new()
	if not store.configure(cache,native_directory,helper):fail("Installed content index unavailable");return
	var roots: Array[String]=[profile,install]
	var resolved: Dictionary=Admission.resolve_cached(requirements,store,0,roots)
	if not resolved.get("ready",false):fail("Original Arelith content is not admitted");store.close();return
	var sources: Dictionary=Sources.build(resolved,install,profile,cache,native_directory,helper)
	if sources.has("error") or sources.nwsync.is_empty():fail("Godot catalog descriptor rejected admitted server content");store.close();return
	for manifest in sources.nwsync:
		if not FileAccess.file_exists(cache.path_join("manifests").path_join(manifest.hash)):
			fail("Admitted manifest is missing from the Godot catalog descriptor");store.close();return
	for archive in sources.archives:
		if not FileAccess.file_exists(archive.path):fail("Admitted file archive is missing");store.close();return
	if OS.get_cmdline_user_args().has("--mount"):
		var mounted: Dictionary=SessionCatalog.prepare(sources)
		if not str(mounted.get("error","")).is_empty():fail("Godot catalog rejected admitted resources: "+str(mounted.error));store.close();return
		for name in ["baseitems","classes","visualeffects","skills"]:
			if mounted.catalog.get_resource(name,2017).is_empty():fail("Mounted server catalog omitted "+name);store.close();return
		var session:=Session.new();root.add_child(session)
		session.catalog_serial=1
		session.accept_catalog(1,mounted.catalog,"",{})
		if session.catalog!=mounted.catalog or session.object_rules==null:fail("Godot session did not attach mounted object rules");session.close();store.close();return
		session.close()
	print("NWN79 Godot server catalog descriptor PASS: manifests=",sources.nwsync.size()," archives=",sources.archives.size())
	store.close();quit(0)

func fail(reason: String)->void:
	printerr("NWN79 Godot resource-source handoff failed: "+reason)
	quit(1)
