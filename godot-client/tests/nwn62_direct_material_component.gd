extends "res://tests/nwn62_direct_material_test.gd"
const CurrentPool=preload("res://systems/native_render/resource_pool.gd")
func summarize(values: Array)->Dictionary:
	var ordered:=values.duplicate();ordered.sort();var total:=0.0
	for value in ordered:total+=float(value)
	return {"samples":ordered.size(),"mean_us":total/maxi(1,ordered.size()),"median_us":ordered[ordered.size()/2],"p95_us":ordered[mini(ordered.size()-1,int(ceil(ordered.size()*0.95))-1)],"maximum_us":ordered.back()}
func batch(pool,rows: Array)->Dictionary:
	pool.materials.clear();pool.resource_order.material.clear()
	var before:=int(pool.stats.materials_created);var hits_before:=int(pool.stats.material_hits);var direct_before:=int(pool.stats.get("direct_native_materials",0));var valid:=true
	var began:=Time.get_ticks_usec()
	for row in rows:
		var material: Material=pool.material(row.part,row.raster)
		if material==null:valid=false
	var elapsed:=Time.get_ticks_usec()-began
	return {"us":elapsed,"valid":valid,"created":int(pool.stats.materials_created)-before,"hits":int(pool.stats.material_hits)-hits_before,"direct":int(pool.stats.get("direct_native_materials",0))-direct_before}
func run()->void:
	# Exact frozen Pool with its matching frozen NativeMaterial dependency. Only
	# the path is adapted; texture upload and material construction stay actual.
	var source:=FileAccess.get_file_as_string("res://.cache/nwn62/direct-material-before/resource_pool.gd")
	source=source.replace("preload(\"res://systems/native_render/native_model_material.gd\")","preload(\"res://.cache/nwn62/direct-material-before/native_model_material.gd\")")
	var before_path:="res://.cache/nwn62/direct-material-before/pool-component-view.gd";var file:=FileAccess.open(before_path,FileAccess.WRITE);file.store_string(source);file.close();var before_script=load(before_path)
	var original=FileAccess.open("res://.cache/nwn70/counts-b/tcn01_a01_01-original.var",FileAccess.READ).get_var(false)
	var original_rows: Array=[]
	for part in original.value.nodes:
		if part.mesh.is_empty() or part.mesh.indices.is_empty() or not part.mesh.render:continue
		var raster: Dictionary={};var names: Array=part.mesh.textures
		if not names.is_empty() and not str(names[0]).is_empty() and str(names[0]).to_lower()!="null":raster=original.textures[str(names[0]).to_lower()]
		original_rows.append({"part":part,"raster":raster})
	var varied: Array=[]
	for index in 64:
		var row: Dictionary=original_rows[index%original_rows.size()].duplicate(true)
		row.part.mesh.diffuse=[float(index+1)/65.0,0.25,0.75];row.part.alpha=0.5 if index%3==0 else 1.0;row.part.mesh.transparency_hint=index%4==0;varied.append(row)
	var seed:=CurrentPool.new();var textures: Dictionary={}
	for name in original.textures:
		var raster: Dictionary=original.textures[name];var texture:=seed.texture(raster);check(texture!=null,"Original raster prewarm succeeds outside component measurement");textures[str(raster.sha256)]=texture
	var cases:={"original-tile-materials":original_rows,"diverse-original-policy64":varied};var rows: Array=[];var repetitions:=32
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--repetitions="):repetitions=maxi(1,int(argument.trim_prefix("--repetitions=")))
	for name in cases:
		for mode in ["before","after","after","before"]:
			var pool=before_script.new() if mode=="before" else CurrentPool.new();pool.native_lighting=true;pool.native_surface_output=true;pool.textures=textures.duplicate()
			for warmup in 3:batch(pool,cases[name])
			var samples: Array=[];var last: Dictionary={}
			for repetition in repetitions:last=batch(pool,cases[name]);check(last.valid,"Actual native material construction succeeds");samples.append(last.us)
			rows.append({"case":name,"mode":mode,"timing":summarize(samples),"requests":cases[name].size(),"created_per_sample":last.created,"cache_hits_per_sample":last.hits,"direct_per_sample":last.direct});pool.clear()
	seed.clear()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"rows":rows,"scope":"Normal-engine headless ABBA material-publication CPU component only. Actual frozen/current Pool and matching NativeMaterial bodies. Original decoded tile policies/rasters, textures and shader caches prewarmed outside measurement; final material construction/cache hits and unused temporary destruction inside measured call. No GPU pixels, frame/FPS or whole-entry claim."}
	var path:="res://.cache/nwn62/checks/direct-material-component-a.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):path=argument.trim_prefix("--report=")
	file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close();print(JSON.stringify({"success":failures.is_empty(),"checks":checks,"rows":rows}));quit(0 if failures.is_empty() else 1)
