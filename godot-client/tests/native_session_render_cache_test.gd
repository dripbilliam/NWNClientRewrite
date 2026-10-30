extends "res://tests/native_template_cache_test.gd"
const World=preload("res://systems/native_render/live_world.gd")
func raster(color: Array) -> Dictionary:
	var bytes:=PackedByteArray(color)
	return {"sha256":Cache.digest(bytes),"value":{"format":"rgba8","width":1,"height":1,"mips":[{"width":1,"height":1,"data":bytes}]}}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var text:=source("auth_shared").replace("endmodelgeom auth_shared\n","node emitter source\nparent root\nupdate Fountain\nrender Normal\nblend Normal\nxgrid 1\nygrid 1\nbirthrate 8\nlifeexp 1\nsizestart 0.1\nsizeend 0.1\nalphastart 1\nalphaend 1\nendnode\nendmodelgeom auth_shared\n")
	var parser:=ActorData.new(); var value:={"value":parser.parse(text.to_utf8_buffer()),"sha256":Cache.digest(text.to_utf8_buffer()),"textures":{},"error":"","animation_sources":[]}
	check(parser.failure.is_empty(),"Authored mesh/emitter data parses without JS")
	var shared:=Pool.new(); shared.picking=true
	var template=shared.model_template(value)
	check(template!=null,"Shared native template builds")
	if template==null: quit(1); return
	var old:=World.new(); root.add_child(old); old.set_process(false); old.pool=shared; old.owns_pool=false
	var first=template.create(); old.add_child(first); old.instances[1]=first
	var old_emitter=first.find_child("native_emitter",true,false); old_emitter.set_process(false)
	old_emitter.state.accumulator198=0.875; first.parts[0].position=Vector3(7,8,9)
	var next:=World.new(); root.add_child(next); next.set_process(false); next.pool=shared; next.owns_pool=false
	var warm=shared.model_template(value); var second=warm.create(); next.add_child(second); next.instances[2]=second
	var fresh_emitter=second.find_child("native_emitter",true,false); fresh_emitter.set_process(false)
	check(warm==template and shared.stats.templates_created==1 and shared.stats.template_hits==1,"A new world reuses the immutable model template")
	check(first.parts[0]!=second.parts[0] and first.meshes[0].mesh==second.meshes[0].mesh,"Worlds share immutable GPU geometry and retain private physical nodes")
	check(old_emitter!=fresh_emitter and fresh_emitter.state.accumulator198==0 and second.parts[0].position==Vector3.ZERO,"New world effect state and rest pose are independent")
	var tracked: WeakRef=weakref(first); old.close(); old.queue_free(); await process_frame; await process_frame
	check(tracked.get_ref()==null and is_instance_valid(second) and not second.retired,"Retiring one world cannot retire another world's instance")
	check(shared.templates.size()==1 and shared.meshes.size()==1,"Retired shared world does not empty the session cache")
	var camera:=Camera3D.new(); next.add_child(camera); camera.position=Vector3(0,3,6); camera.look_at(Vector3.ZERO); camera.current=true
	fresh_emitter.tick(0.2)
	check(fresh_emitter.failure.is_empty() and fresh_emitter.frames==1 and fresh_emitter.allocated>0,"New private emitter still simulates after the old world closes")
	var no_pick:=Pool.new(); var unpicked=no_pick.model_template(value); var unpicked_mesh=unpicked.create(); no_pick.picking=true
	var picked=no_pick.model_template(value); var picked_mesh=picked.create()
	check(unpicked!=picked and unpicked_mesh.meshes[0].mesh!=picked_mesh.meshes[0].mesh,"Picking publication settings separate template and geometry keys")
	check(not unpicked_mesh.meshes[0].mesh.has_meta("native_pick_shape") and picked_mesh.meshes[0].mesh.has_meta("native_pick_shape"),"Warm unpickable geometry cannot hide later native hit shapes")
	unpicked_mesh.free(); picked_mesh.free(); no_pick.clear()
	var bounded:=Pool.new(); bounded.maximum_templates=1; bounded.maximum_meshes=1; bounded.maximum_materials=1; bounded.maximum_textures=1; bounded.picking=true
	var a:=raster([255,0,0,255]); var b:=raster([0,255,0,255])
	var red=bounded.texture(a); var green=bounded.texture(b)
	check(bounded.textures.size()==1 and bounded.stats.texture_evictions==1 and red!=green,"Texture bindings are bounded and retain distinct content")
	var part: Dictionary=value.value.nodes[0]; var red_material=bounded.material(part,a); var green_material=bounded.material(part,b)
	check(bounded.materials.size()==1 and bounded.stats.material_evictions==1 and red_material.albedo_texture!=green_material.albedo_texture,"Material cache eviction preserves live original material/texture references")
	var original_mesh=bounded.geometry(value.sha256,0,part.mesh); var other_mesh=bounded.geometry("a".repeat(64),0,part.mesh)
	check(bounded.meshes.size()==1 and bounded.pick_shapes.size()==1 and bounded.stats.mesh_evictions==1,"Geometry eviction drops its cached picking-shape binding")
	check(original_mesh.get_surface_count()==1 and original_mesh.has_meta("native_pick_shape") and other_mesh.get_surface_count()==1,"Eviction does not mutate live GPU geometry or its hit shape")
	bounded.model_template(bundle("auth_one")); bounded.model_template(bundle("auth_two"))
	check(bounded.templates.size()==1 and bounded.stats.template_evictions==1,"Shared templates retain the bounded recent-use policy")
	var retained:=shared.snapshot(); var bounded_metrics:=bounded.snapshot()
	for frame in 4: await process_frame
	var image_path:=""
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw; image_path=str(args.report).trim_suffix(".json")+".png"; root.get_texture().get_image().save_png(image_path)
	next.close(); next.queue_free(); await process_frame; await process_frame
	check(shared.templates.size()==1,"Last shared world closes without destroying retained source templates")
	shared.clear(); bounded.clear()
	check(shared.snapshot().retained.values().all(func(n):return n==0) and shared.resource_order.values().all(func(order):return order.is_empty()),"Session shutdown releases every cache binding and recency entry")
	var private:=World.new(); root.add_child(private); private.set_process(false); private.pool.model_template(bundle("auth_private")); private.close()
	check(private.pool.templates.is_empty() and private.owns_pool,"Standalone worlds keep their existing private-cache cleanup")
	private.queue_free(); await process_frame; await process_frame
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"retained_before_release":retained,"bounded":bounded_metrics,"rendered_image":image_path,"publicConnections":0,"scope":"Authored actual native templates/private emitters, two world owners, bounded resource bindings, picking identity and cleanup. Manual pool injection here; separate default/authoritative transition checks verify production injection. No full effects, exact original eviction or FPS acceptance."},"\t")); file.close()
	print("NATIVE_SESSION_RENDER_CACHE ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
