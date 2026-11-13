extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Wave=preload("res://systems/native_data/wave_data.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var catalog=Catalog.new()
	var install="C:/Users/Niflheim/Desktop/Tools/Local Tools/FullDecomp/NwnRootInstall"
	if not catalog.mount_install(install): print("MOUNT ",catalog.failure); quit(1); return
	for name in ["gui_button","gui_open","gui_close","gui_select","mus_theme_main"]:
		for kind in [4,8]:
			var bytes: PackedByteArray=catalog.get_resource(name,kind)
			if bytes.is_empty(): continue
			var parser=Wave.new(); var decoded: Dictionary=parser.parse(bytes)
			print(name," type=",kind," bytes=",bytes.size()," magic=",bytes.slice(0,8).get_string_from_ascii()," codec=",decoded.get("codec","")," error=",parser.failure)
	quit()
