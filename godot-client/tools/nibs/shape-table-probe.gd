extends SceneTree
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Table=preload("res://systems/native_data/two_da.gd")
const Binary=preload("res://systems/native_data/binary_data.gd")
const Appearance=preload("res://systems/native_data/creature_appearance.gd")
const Assets=preload("res://systems/native_data/asset_service.gd")
const Pool=preload("res://systems/native_render/resource_pool.gd")
const Actor=preload("res://systems/native_render/actor_instance.gd")

func _initialize()->void: call_deferred("run")
func run()->void:
	var install:=""; var cache:=""; var native:=""; var helper:=""; var hash:=""; var report:=""
	for arg in OS.get_cmdline_user_args():
		for pair in [["--install=","install"],["--cache=","cache"],["--native=","native"],["--helper=","helper"],["--hash=","hash"],["--report=","report"]]:
			if arg.begins_with(pair[0]):
				match pair[1]:
					"install": install=arg.substr(pair[0].length())
					"cache": cache=arg.substr(pair[0].length())
					"native": native=arg.substr(pair[0].length())
					"helper": helper=arg.substr(pair[0].length())
					"hash": hash=arg.substr(pair[0].length())
					"report": report=arg.substr(pair[0].length())
	var catalog:=Catalog.new()
	if not catalog.mount_install(install) or not catalog.mount_nwsync(hash,cache,native,helper):
		print(JSON.stringify({"error":catalog.failure})); quit(2); return
	var out:={"hash":hash,"appearance":[],"visuals":{},"polymorph":[],"attachments":{},"plans":[],"models":{},"assembled":[]}
	var tables: Dictionary={}
	for name in ["appearance","visualeffects","polymorph","tailmodel","wingmodel"]:
		var bytes: PackedByteArray=catalog.get_resource(name,2017)
		var parser:=Table.new(); var table: Dictionary=parser.parse(Binary.new(bytes).text(0,bytes.size()))
		if not parser.failure.is_empty(): print(JSON.stringify({"error":parser.failure,"table":name})); quit(3); return
		var rows: Array=table.get("orderedRows",[])
		tables[name]=table
		if name=="appearance":
			for index in rows.size():
				var row: Dictionary=rows[index]; var race:=str(row.get("RACE","")).to_lower()
				if "invis_cr_160" in race or "earth" in race or "elemental" in race: out.appearance.append({"id":index,"row":row})
		elif name=="polymorph":
			for index in rows.size():
				var row: Dictionary=rows[index]
				if "earth" in JSON.stringify(row).to_lower() or str(row.get("AppearanceType","")) in ["56","57","844","864","5225"]: out.polymorph.append({"id":index,"row":row})
		elif name in ["tailmodel","wingmodel"]:
			out.attachments[name]=[]
			for index in rows.size():
				var row: Dictionary=rows[index]
				if "earth" in JSON.stringify(row).to_lower() or "emon" in JSON.stringify(row).to_lower() or index==160: out.attachments[name].append({"id":index,"row":row})
		else:
			for id in [6,29,85,182,244,286,480]: out.visuals[str(id)]=rows[id] if id<rows.size() else {}
	for spec in [[844,341],[864,342]]:
		var object:={"id":42,"appearance":{"appearance":spec[0],"fieldAA4":spec[1],"equipment":[]},"replicated":{"stats":{"racialType":16}}}
		var planner:=Appearance.new(); var plan:=planner.plan(object,tables)
		out.plans.append({"appearance":spec[0],"tail":spec[1],"base":plan.get("model",""),"attachments":plan.get("attachments",[]).map(func(p):return str(p.model)),"model_present":catalog.has_resource(str(plan.get("attachments",[])[0].model),2002) if not plan.get("attachments",[]).is_empty() else false,"error":planner.failure})
	var assets:=Assets.new(); root.add_child(assets); assets.configure(catalog)
	var received: Dictionary={}; assets.completed.connect(func(id: int,result: Dictionary):received[id]=result)
	var requests: Dictionary={}
	for model in ["invis_cr_160","c_earth","c_eartheld"]: requests[assets.request(model,2002,"actor-model")]=model
	var deadline:=Time.get_ticks_msec()+30000
	while received.size()<requests.size() and Time.get_ticks_msec()<deadline: await process_frame
	for id in requests:
		var result: Dictionary=received.get(id,{})
		var nodes: Array=result.get("value",{}).get("nodes",[])
		out.models[requests[id]]={"error":str(result.get("error","unfinished")),"nodes":nodes.size(),"names":nodes.map(func(n):return str(n.get("name",""))),"types":nodes.map(func(n):return str(n.get("type","")))}
	var bundles: Dictionary={}
	for id in requests: bundles[requests[id]]=received.get(id,{})
	var host:=Node3D.new(); root.add_child(host); var pool:=Pool.new(); pool.unshaded=true
	for plan in out.plans:
		var model:=str(plan.attachments[0]) if not plan.attachments.is_empty() else ""
		if model.is_empty(): continue
		var actor:=Actor.new(); host.add_child(actor)
		var pieces: Array=[{"anchor":"","bundle":bundles[plan.base]},{"anchor":"tail","bundle":bundles[model],"follow":true,"nativeVisualScope":253}]
		var ok:=actor.install(pieces,pool,42,{},0)
		out.assembled.append({"appearance":plan.appearance,"success":ok,"error":actor.failure,"meshes":actor.meshes.size(),"models":actor.model_names.duplicate()})
		actor.retire()
	pool.clear(); host.free()
	assets.close(); assets.queue_free()
	var failures: Array=[]
	if out.plans.size()!=2 or out.assembled.size()!=2: failures.append("Both non-modular forms must be planned and assembled")
	for index in mini(out.plans.size(),out.assembled.size()):
		var plan: Dictionary=out.plans[index]; var actor: Dictionary=out.assembled[index]
		if plan.attachments.size()!=1 or not plan.model_present or not str(plan.error).is_empty(): failures.append("Server-selected tail model must be present for appearance "+str(plan.appearance))
		if not actor.success or actor.meshes<=0 or actor.models.size()!=2: failures.append("Both original models must assemble with visible meshes for appearance "+str(plan.appearance))
	out.success=failures.is_empty(); out.failures=failures; out.source_sha256=FileAccess.get_sha256("res://systems/native_data/creature_appearance.gd")
	if not report.is_empty() and not FileAccess.file_exists(report):
		var file:=FileAccess.open(report,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(out,"  ")+"\n"); file.close()
	print(JSON.stringify({"success":out.success,"failures":failures,"plans":out.plans,"assembled":out.assembled,"report":report})); quit(0 if out.success else 1)
