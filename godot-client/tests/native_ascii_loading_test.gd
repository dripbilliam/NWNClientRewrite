extends SceneTree
const Recorded=preload("res://systems/native_data/recorded_catalog.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Geometry=preload("res://systems/native_data/ascii_model.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("catalog") or not args.has("baseline") or not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var actor_path:=str(args.baseline).path_join("systems/native_data/actor_model.gd"); var geometry_path:=str(args.baseline).path_join("systems/native_data/ascii_model.gd")
	var actor_script:=GDScript.new(); actor_script.source_code=FileAccess.get_file_as_string(actor_path)
	var geometry_script:=GDScript.new(); geometry_script.source_code=FileAccess.get_file_as_string(geometry_path)
	check(actor_script.reload()==OK and geometry_script.reload()==OK,"Verified authored baseline parser sources compile")
	var catalog:=Recorded.new(); check(catalog.mount(str(args.catalog)),"Private recorded ASCII source corpus mounts")
	var samples: Array=[]
	for name in ["pme0","c_nulltail","h_ba_med_weap","h_ba_custom"]:
		var bytes:=catalog.get_resource(name,2002); var text:=Binary.new(bytes).text(0,bytes.size())
		check(catalog.failure.is_empty(),"Original ASCII model is present: "+name)
		var old=geometry_script.new(); var geometry:=Geometry.new()
		var a: Dictionary=old.parse(text); var b:=geometry.parse(text)
		check(old.failure.is_empty() and geometry.failure.is_empty() and Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b)),"Every static hierarchy/geometry/property matches baseline: "+name)
		var original=actor_script.new(); var current:=Actor.new()
		var began:=Time.get_ticks_usec(); a=original.parse(bytes); var old_ms:=(Time.get_ticks_usec()-began)/1000.0
		began=Time.get_ticks_usec(); b=current.parse(bytes); var new_ms:=(Time.get_ticks_usec()-began)/1000.0
		check(original.failure.is_empty() and current.failure.is_empty() and Cache.digest(var_to_bytes(a))==Cache.digest(var_to_bytes(b)),"Every ASCII skin/controller/clip/key/event matches baseline: "+name)
		samples.append({"name":name,"bytes":bytes.size(),"source_sha256":Cache.digest(bytes),"clips":b.animations.size(),"old_ms":old_ms,"new_ms":new_ms})
	var regex:=RegEx.new(); regex.compile("\\s+")
	check(Binary.ascii_tokens(" a\t b\r\n c\u00a0d ",regex)==regex.sub(" a\t b\r\n c\u00a0d "," ",true).split(" ",false),"CP1252 non-ASCII whitespace retains fallback scanner behavior")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"samples":samples,"baseline_actor_sha256":FileAccess.get_sha256(actor_path),"baseline_geometry_sha256":FileAccess.get_sha256(geometry_path),"publicConnections":0},"\t")); file.close()
	quit(0 if failures.is_empty() else 1)
