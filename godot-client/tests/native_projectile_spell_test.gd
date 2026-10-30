extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Spell=preload("res://systems/native_data/projectile_spell.gd")
const Effects=preload("res://systems/native_render/effect_world.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Read-only original resource mount")
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog); var result: Dictionary={}
	assets.completed.connect(func(_id,data):result.merge(data)); assets.request("spells",2017,"2da")
	var deadline:=Time.get_ticks_msec()+15000
	while result.is_empty() and Time.get_ticks_msec()<deadline: await process_frame
	check(str(result.get("error","unfinished")).is_empty(),"Active original spells table prepares natively")
	if result.has("value"):
		var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
		for row in oracle.rows:
			var actual:=Spell.prepare(result.value,int(row.id)); var difference: Array=[]
			for key in row.expected:
				if not actual.has(key) or actual[key]!=row.expected[key]: difference.append({"field":key,"actual":actual.get(key),"expected":row.expected[key]})
			check(actual.size()==row.expected.size() and difference.is_empty(),"Original-derived spell projectile metadata "+str(row.id)+" "+JSON.stringify(difference))
	var authored:={"columns":["Proj","ProjType","ProjModel","ProjSpwnPoint","ProjOrientation"],"orderedRows":[{"Proj":"1","ProjType":"ballistic","ProjModel":"custom_missile","ProjSpwnPoint":"monster8","ProjOrientation":"target"}],"defaultValue":"****"}
	var custom:=Spell.prepare(authored,0)
	check(custom.model=="custom_missile" and custom.projectilePath==2 and custom.spawn==11 and custom.facing==1,"Server table overrides determine model/path/physical spawn/facing")
	check(Spell.prepare(authored,-1).is_empty() and Spell.prepare(authored,1).is_empty(),"Invalid physical spell rows remain unavailable")
	var effects:=Effects.new(); effects.free(); assets.close(); assets.free(); await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Default native effect/projectile scripts parse and native spell selection matches retained original-derived metadata; not live projectile acceptance"},"\t")); file.close()
	print("NATIVE_PROJECTILE_SPELL ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
