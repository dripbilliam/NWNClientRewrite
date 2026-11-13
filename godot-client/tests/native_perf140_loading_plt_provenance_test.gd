extends SceneTree
const Palette=preload("res://systems/native_data/palette_texture.gd")
const GuiPalette=preload("res://systems/native_data/gui_palette_texture.gd")
const Raster=preload("res://systems/native_data/texture_data.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
const Identity=preload("res://systems/native_data/scoped_processor_identity.gd")
const Store=preload("res://systems/native_data/preparation_store.gd")
class Reader:
	extends RefCounted
	var values: Dictionary={}
	var failure:=""
	var store:=Store.new()
	func preparation_cache(): return store
	func get_resource(name: String,type: int) -> PackedByteArray:
		var key:=name+":"+str(type); failure="" if values.has(key) else "Missing owned fixture resource: "+key
		return values.get(key,PackedByteArray()).duplicate()
var checks:=0
var failures: Array=[]
func check(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
func arg(prefix: String) -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(prefix): return value.trim_prefix(prefix)
	return ""
func _initialize() -> void: call_deferred("run")
func tga() -> PackedByteArray:
	var raw:=PackedByteArray(); raw.resize(18+256*2*4); raw[2]=2; raw.encode_u16(12,256); raw.encode_u16(14,2); raw[16]=32
	for index in 512:
		raw[18+index*4]=index%256; raw[19+index*4]=(index/256)*77; raw[20+index*4]=255-index%256; raw[21+index*4]=255
	return raw
func plt(gui: bool) -> PackedByteArray:
	var raw: PackedByteArray="PLT V1  ".to_ascii_buffer(); raw.resize(24+(2 if not gui else 1)*2); raw.encode_u32(8,11); raw.encode_u32(16,1 if gui else 2); raw.encode_u32(20,1); raw[24]=5; raw[25]=0
	if not gui: raw[26]=17; raw[27]=1
	return raw
func snapshots(directory: String) -> Dictionary:
	var result: Dictionary={}
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".bin"): result[name]=FileAccess.get_sha256(directory.path_join(name))
	return result
func run() -> void:
	var failed_engine:=arg("--mode=")=="failed-engine"
	if failed_engine: Identity.engine_initialized=true; Identity.engine_sha256=""; Identity.engine_error="fixture-unavailable"
	var reader:=Reader.new(); var palette_bytes:=tga(); var body:=plt(false); var gui:=plt(true)
	reader.values={"body_plt:6":body,"gui_cg_color_tmp:6":gui,"pal_skin01:3":palette_bytes,"pal_hair01:3":palette_bytes}
	var palette:=Raster.new().parse(palette_bytes,3); var rows: Array=[]
	for index in 10: rows.append(0)
	var expected_body:=Palette.new().decode(body,{"pal_skin01":palette,"pal_hair01":palette},rows)
	var body_source:=Cache.digest(body); var body_identity:=Cache.digest(var_to_bytes(["plt-original-1",body_source,[["pal_skin01",Cache.digest(palette_bytes)],["pal_hair01",Cache.digest(palette_bytes)]],rows]))
	var selected_row: PackedByteArray=palette.mips[0].data.slice(1024,2048); var gui_identity:=Cache.digest(var_to_bytes(["original-gui-packed-palette-v1",Cache.digest(gui),1,Cache.digest(palette_bytes),Cache.digest(selected_row)]))
	var expected_gui:=Palette.new().decode(gui,{"pal_skin01":{"format":"rgba8","width":256,"height":1,"mips":[{"width":256,"height":1,"data":selected_row}]}},[0])
	var cache:=Cache.new(); check(cache.configure(arg("--cache-root=")),"owned lower PLT cache configures")
	var legacy_body:=Cache.key(body_identity,"plt-original"); var legacy_gui:=Cache.key(gui_identity,"gui-packed-palette-v1")
	check(cache.save_data(legacy_body,body_identity,"plt-original",{"legacy_marker":99}),"legacy body PLT poison saved")
	check(cache.save_data(legacy_gui,gui_identity,"gui-packed-palette-v1",{"legacy_marker":99}),"legacy GUI PLT poison saved")
	var before:=snapshots(cache.directory)
	for round_index in 2:
		var actual_body:=Palette.new().prepare(reader,"body_plt",rows,arg("--cache-root=")); var actual_gui:=GuiPalette.prepare(reader,{"resource":"gui_cg_color_tmp","palette":[1]},arg("--cache-root="))
		check(str(actual_body.get("error","")).is_empty() and actual_body.value==expected_body,"body pixels never come from stale legacy PLT data")
		check(actual_gui.ready and actual_gui.value==expected_gui,"packed GUI selector pixels never come from stale legacy PLT data")
		check(bool(actual_body.cache_hit)==(round_index==1 and not failed_engine),"body lower cache reuse requires actual processor/engine proof")
		check(bool(actual_gui.cache_hit)==(round_index==1 and not failed_engine),"GUI lower cache reuse requires actual processor/engine proof")
		check(actual_body.sha256==body_identity and actual_body.source_sha256==body_source,"original body source/row identity packet remains unchanged")
		check(actual_gui.sha256==gui_identity and actual_gui.selector==1,"original GUI source/WORD selector identity packet remains unchanged")
	check(cache.load_data(legacy_body,body_identity,"plt-original").get("legacy_marker")==99 and cache.load_data(legacy_gui,gui_identity,"gui-packed-palette-v1").get("legacy_marker")==99,"original untrusted legacy artifacts are preserved, not overwritten or reused")
	if failed_engine:
		check(snapshots(cache.directory)==before,"failed actual-engine proof writes no lower PLT derivative")
		check(Identity.resolve("actor-model").is_empty() and Identity.resolve("gui-icon-v1").is_empty(),"failed engine proof yields no lower processor namespace")
	else:
		var actor: String=Identity.identities["actor-model"]; var icon: String=Identity.identities["gui-icon-v1"]; Identity.identities["actor-model"]=""; Identity.identities["gui-icon-v1"]=""
		var current:=snapshots(cache.directory); var no_proof_body:=Palette.new().prepare(reader,"body_plt",rows,arg("--cache-root=")); var no_proof_gui:=GuiPalette.prepare(reader,{"resource":"gui_cg_color_tmp","palette":[1]},arg("--cache-root="))
		check(not no_proof_body.cache_hit and no_proof_body.value==expected_body,"unavailable model processor refuses an otherwise valid saved body PLT")
		check(not no_proof_gui.cache_hit and no_proof_gui.value==expected_gui,"unavailable GUI processor refuses an otherwise valid saved GUI PLT")
		check(snapshots(cache.directory)==current,"unavailable processor proofs publish no new PLT bytes")
		Identity.identities["actor-model"]=actor; Identity.identities["gui-icon-v1"]=icon
		var changed_rows:=rows.duplicate(); changed_rows[0]=1; var changed:=Palette.new().prepare(reader,"body_plt",changed_rows,arg("--cache-root="))
		check(not changed.cache_hit and changed.sha256!=body_identity and changed.value!=expected_body,"actual body color-row change retains original invalidation")
		var changed_gui:=GuiPalette.prepare(reader,{"resource":"gui_cg_color_tmp","palette":[0]},arg("--cache-root="))
		check(not changed_gui.cache_hit and changed_gui.sha256!=gui_identity and changed_gui.value!=expected_gui,"actual GUI WORD selector change retains original invalidation")
	reader.store.clear()
	var proof:={"success":failures.is_empty(),"mode":arg("--mode="),"checks":checks,"failures":failures,"identity_status":Identity.status(),"scope":"Actual lower body/GUI PLT legacy poison, original pixels/source/selector identities, warm reuse and failed engine/processor refusal. No GPU/server/latency claim."}
	var file:=FileAccess.open(arg("--report="),FileAccess.WRITE); file.store_string(JSON.stringify(proof)); file.close(); print(JSON.stringify({"success":proof.success,"checks":checks,"mode":proof.mode,"failures":failures})); quit(0 if proof.success else 1)
