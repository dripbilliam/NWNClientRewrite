extends "res://tests/native_projectile_lifetime_test.gd"
const LiveWorld=preload("res://systems/native_render/live_world.gd")
const NativeModel=preload("res://systems/native_render/actor_instance.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
func run() -> void:
	var output:=""; var install:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--install="): install=arg.substr(10)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var catalog:=Catalog.new(); check(catalog.mount_install(install),"Original vision source catalog mounts read-only")
	var world:=LiveWorld.new(); world.catalog=catalog; world.generation=1; world.area_id=1; world.controlled_id=0x80000001; world.pool.native_lighting=true; root.add_child(world); world.set_process(false)
	if OS.get_cmdline_user_args().has("--standard-lighting"):
		world.model_environment=preload("res://systems/native_render/model_environment.gd").new(); world.add_child(world.model_environment); world.model_environment.configure(catalog,world.pool)
		check(world.model_environment.enabled and world.pool.native_standard,"Native vision fixture selects the verified retail standard-material profile")
	var owner:=Effects.new(); world.add_child(owner); owner.configure(world); world.effects=owner
	check(await wait_for(func():return owner.tables_ready() and owner.ensure_models({"c_ydrowiz":true})),"Original vision tables and source actor prepare")
	var actor:=NativeModel.new(); world.add_child(actor)
	check(actor.install([{"bundle":owner.bundles.c_ydrowiz,"anchor":"","follow":true}],world.pool,world.controlled_id,{}),"Original controlled actor installs under its real native ID")
	world.instances[world.controlled_id]=actor
	var object:={"id":world.controlled_id,"objectType":5,"nativeLifetime":1,"appearance":{"appearance":201,"gender":1},"replicated":{"position":[0,0,0],"stats":{}}}
	world.desired[world.controlled_id]={"key":"one","object":object}; world.installed[world.controlled_id]="one"
	var focus=world.focus_lighting; focus.set_area([0,0,0],[0,0,0]); focus.focus=Vector3.ZERO; focus.set_controlled(actor)
	owner.reserve(world.controlled_id,1,{"visualId":182,"sourceId":0x7f000000,"bodyPart":0,"delivery":{"instant":0,"sourcePart":0,"targetPart":0,"point":[0,0,0]}},false)
	check(await wait_for(func():return owner.entries.values().any(func(entry):return entry.runtime!=null and entry.runtime.state.attached114)),"Data-selected Darkvision attaches through the real native effect selector")
	if owner.entries.is_empty(): world.close(); world.free(); quit(1); return
	var entry: Dictionary=owner.entries.values()[0]; var runtime=entry.runtime
	check(int(runtime.state.field110)==1 and int(runtime.state.programType10d)==4,"Actual active progfx row requests the original light gate")
	for model in runtime.models.values():
		model.rigs.set_process(false); model.rigs.entities[0].models[0].native_owner.advance(.5)
	await process_frame; await process_frame; focus.refresh()
	var dark: Dictionary=focus.snapshot()
	check(dark.excluded>0 and dark.sample==[0.0,0.0,0.0],"Attached vision lamps are excluded from their own CPU focus sample")
	check(focus.view_gate() and runtime.state.attached114,"Own vision light does not switch itself back off")
	var props: Array=[]
	for light in actor.get_tree().get_nodes_in_group("native_original_model_lights"):
		if world.is_ancestor_of(light): props.append(light.get_meta("native_model_light_properties"))
	check(props.any(func(row):return Vector3(row.color[0],row.color[1],row.color[2]).length()>.1 and float(row.radius)>0),"The actual original vision animation produces a live illumination source")
	focus.set_area([1.0,1.0,1.0],[0.0,0.0,0.0]); focus.refresh(); owner.select_actor(world.controlled_id,0)
	check(not focus.gate.active and (runtime.state.closedEc or not runtime.state.attached114),"Bright area lighting stops gated vision through original selection/clock behavior")
	focus.set_area([.4,.4,.4],[0,0,0]); focus.refresh(); check(not focus.view_gate(),"Intermediate light retains the off hysteresis state")
	focus.set_area([0,0,0],[0,0,0]); focus.refresh(); owner.select_actor(world.controlled_id,0)
	check(focus.gate.active and runtime.state.attached114 and not runtime.state.closedEc,"Returning to darkness restarts the original vision model")
	focus.set_area([.4,.4,.4],[0,0,0]); focus.refresh(); check(focus.view_gate(),"Intermediate light retains the on hysteresis state")
	var other:=PointLight.new(); other.configure({"color":[1,1,1],"radius":8}); world.add_child(other); focus.refresh()
	check(not focus.view_gate() and focus.sampled_lights>focus.excluded_lights,"A real external lamp can suppress gated vision")
	other.free(); focus.set_area([0,0,0],[0,0,0]); focus.refresh(); owner.select_actor(world.controlled_id,0)
	check(focus.view_gate(),"Retired external lamp cannot leave stale illumination")
	check(not owner.diagnostics.has("visual.view-gate-unimplemented:native view context pending"),"Native effect selector uses the actual scene light gate")
	var families: Array=[]
	for visual in [243,242,244,247]:
		for identity in owner.entries.keys(): owner._forget(int(identity),"retired")
		await process_frame; await process_frame
		focus.set_area([0,0,0],[0,0,0]); focus.refresh()
		owner.reserve(world.controlled_id,1,{"visualId":visual,"sourceId":0x7f000000,"bodyPart":0,"delivery":{"instant":0,"sourcePart":0,"targetPart":0,"point":[0,0,0]}},false)
		var ready:=await wait_for(func():return owner.entries.values().any(func(item):return item.runtime!=null and item.runtime.state.attached114))
		check(ready,"Original vision-family model attaches "+str(visual))
		if not ready: continue
		var member=owner.entries.values()[0].runtime
		var gated:=bool(member.state.field110)
		check(gated==(visual!=244),"Active original progfx Param5 controls gating "+str(visual))
		for model in member.models.values():
			model.rigs.set_process(false); model.rigs.entities[0].models[0].native_owner.advance(.5)
		var lamps: Array=[]
		for light in world.get_tree().get_nodes_in_group("native_original_model_lights"):
			if world.is_ancestor_of(light): lamps.append(light.get_meta("native_model_light_properties").duplicate(true))
		focus.set_area([1,1,1],[0,0,0]); focus.refresh(); owner.select_actor(world.controlled_id,0)
		check(bool(member.state.closedEc) or not member.state.attached114 if gated else bool(member.state.attached114) and not member.state.closedEc,"Original family obeys its bright-scene gate choice "+str(visual))
		families.append({"visual":visual,"gated":gated,"lamps":lamps})
	var state: Dictionary=focus.snapshot(); world.close()
	check(focus.closed and focus.members.is_empty() and not focus.view_gate(),"World retirement clears focus light bindings and disables future requests")
	world.free(); await process_frame; await process_frame
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"focus":state,"families":families,"publicConnections":0,"scope":"Installed native vision tables and actual private vision models through LiveWorld/effect selection: own attached-light exclusion, real external lamp, bright/dark hysteresis, original stop/restart, table-driven family gates and retirement. Current Godot light registry inputs; original BSP admission/fade history, BlindLights scene suppression and matched-room parity remain open."}
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); quit(0 if result.success else 1)
