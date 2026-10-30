extends SceneTree
const Actor=preload("res://systems/native_data/actor_model.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Wave=preload("res://systems/native_data/wave_data.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func storage(node: Dictionary) -> Dictionary:
	var values: Array=[]
	for row in node.controllers78: values.append_array([row.displacement0,row.columnsA,row.rows4,row.timeIndex6,row.valueIndex8])
	return {"id":int(node.id34),"flags":int(node.flags98),"controllers":Cache.digest(PackedInt32Array(values).to_byte_array()),"values":Cache.digest(PackedFloat32Array(node.values88).to_byte_array())}
func tree(node: Dictionary) -> Dictionary:
	var data:=storage(node); data.children=[]
	for child in node.children68: data.children.append(tree(child))
	return data
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a==b
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("oracle") or not FileAccess.file_exists(args.oracle): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); var catalog:=Catalog.new()
	check(catalog.mount_install(ProjectSettings.globalize_path("res://../../FullDecomp/NwnRootInstall")),"Original installed resource catalog opens read-only")
	for row in fixture.models:
		var bytes: PackedByteArray=catalog.get_resource(row.name,2002); check(Cache.digest(bytes)==row.sha256,str(row.name)+" original resource identity")
		var parser:=Actor.new(); var model:=parser.parse(bytes); var native:=parser.native_animation(model)
		check(parser.failure.is_empty() and not native.is_empty(),str(row.name)+" native raw controller data available")
		if native.is_empty(): continue
		check(int(native.root)==int(row.root) and native.parts.size()==row.parts.size(),str(row.name)+" physical root/part count")
		for index in native.parts.size():
			var part: Dictionary=native.parts[index]; var actual:=storage(part.node); actual.type=part.type; actual.children=part.children
			check(same(actual,row.parts[index]),str(row.name)+" physical controller storage "+str(index))
		var clips: Dictionary={}
		for name in native.clips:
			if native.clips[name].has("root"): clips[name]=tree(native.clips[name].root)
			else: clips[name]=native.clips[name]
		check(same(clips,row.clips),str(row.name)+" original clip hierarchy/controller values")
	for row in fixture.waves:
		var parser:=Wave.new(); var data:=parser.parse(Marshalls.base64_to_raw(row.bytes))
		check(parser.failure.is_empty() and not data.is_empty(),str(row.label)+" authored IMA decode")
		if data.is_empty(): continue
		check(int(data.channels)==int(row.channels) and int(data.frames)==int(row.frames) and int(data.sampleRate)==int(row.sampleRate) and Cache.digest(data.pcm)==row.sha256,str(row.label)+" exact PCM samples and format")
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":fixture.scope},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
