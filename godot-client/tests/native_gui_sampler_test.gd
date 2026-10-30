extends SceneTree
const Info=preload("res://systems/native_data/gui_texture_info.gd")
const Sampler=preload("res://systems/native_render/gui_sampler.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); print("FAIL ",label)
func color(x: int,y: int,axes: int) -> Color:
	x=clampi(x,0,1) if axes&1 else posmod(x,2); y=clampi(y,0,1) if axes&2 else posmod(y,2)
	return [Color.RED,Color.GREEN,Color.BLUE,Color.WHITE][y*2+x]
func expected(uv: Vector2,axes: int,linear: bool) -> Color:
	var point:=uv*2
	if not linear: return color(int(floor(point.x)),int(floor(point.y)),axes)
	point-=Vector2(0.5,0.5); var lo:=point.floor(); var weight:=point-lo
	return color(int(lo.x),int(lo.y),axes).lerp(color(int(lo.x)+1,int(lo.y),axes),weight.x).lerp(color(int(lo.x),int(lo.y)+1,axes).lerp(color(int(lo.x)+1,int(lo.y)+1,axes),weight.x),weight.y)
func pixels(output: String) -> void:
	var surface:=SubViewport.new(); surface.size=Vector2i(80,80); surface.own_world_3d=true; surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(surface)
	var camera:=Camera3D.new(); surface.add_child(camera); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2; camera.position=Vector3(0,0,3); camera.current=true
	var image:=Image.create(2,2,false,Image.FORMAT_RGBA8)
	for y in 2:
		for x in 2: image.set_pixel(x,y,color(x,y,3))
	var source:=StandardMaterial3D.new(); source.albedo_texture=ImageTexture.create_from_image(image); source.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; source.cull_mode=BaseMaterial3D.CULL_DISABLED; source.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; source.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
	var arrays: Array=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-1,1,0),Vector3(1,1,0),Vector3(1,-1,0),Vector3(-1,-1,0)]); arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(-0.5,-0.5),Vector2(1.5,-0.5),Vector2(1.5,1.5),Vector2(-0.5,1.5)]); arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	var mesh:=MeshInstance3D.new(); mesh.mesh=ArrayMesh.new(); mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); surface.add_child(mesh)
	for linear in [false,true]:
		for axes in 4:
			mesh.material_override=Sampler.material(source,{"filter":linear,"mipmap":false,"clamp":axes})
			await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var actual:=surface.get_texture().get_image(); var errors: Array=[]
			for y in [9,25,49,70]:
				for x in [9,25,49,70]:
					var want:=expected(Vector2((x+0.5)/80.0*2-0.5,(y+0.5)/80.0*2-0.5),axes,linear); var got:=actual.get_pixel(x,y).srgb_to_linear()
					if Vector3(want.r,want.g,want.b).distance_to(Vector3(got.r,got.g,got.b))>0.075: errors.append({"point":[x,y],"expected":want,"actual":got})
			check(errors.is_empty(),"Actual native GUI pixels preserve independent clamp/repeat edges: "+str([linear,axes])+" "+str(errors.slice(0,2)))
			actual.save_png(output.trim_suffix(".json")+"-"+str(linear)+"-"+str(axes)+".png")
	# A supplied1x1 final mip has a distinct color. Strong minification must
	# sample it for both standard and mixed-axis materials, with either filter.
	var bytes:=image.get_data(); bytes.append_array(PackedByteArray([102,51,204,255])); var mip_image:=Image.create_from_data(2,2,true,Image.FORMAT_RGBA8,bytes); source.albedo_texture=ImageTexture.create_from_image(mip_image)
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2(-64,-64),Vector2(64,-64),Vector2(64,64),Vector2(-64,64)]); mesh.mesh=ArrayMesh.new(); mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	for axes in 4:
		mesh.material_override=Sampler.material(source,{"filter":true,"mipmap":false,"clamp":axes,"mip_levels":2}); await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var actual:=surface.get_texture().get_image().get_pixel(40,40)
		check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3.ONE)<0.075,"Original filter-on/mipmap-off uses nearest minification despite linear magnification: "+str(axes)+" "+str(actual))
	for linear in [false,true]:
		for axes in 4:
			mesh.material_override=Sampler.material(source,{"filter":linear,"mipmap":true,"clamp":axes,"mip_levels":2}); await process_frame; await process_frame; await RenderingServer.frame_post_draw
			var actual:=surface.get_texture().get_image().get_pixel(40,40); var want:=Color(0.4,0.2,0.8)
			check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(want.r,want.g,want.b))<0.075,"Native GUI minification selects the supplied mip: "+str([linear,axes])+" "+str(actual))
	surface.free()
func run() -> void:
	var output:=""; var oracle_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
		if arg.begins_with("--oracle="): oracle_path=arg.substr(9)
	if output.is_empty() or oracle_path.is_empty() or FileAccess.file_exists(output): quit(2); return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Sampler reference comes from the pinned original binary")
	for row in oracle.fields:
		var parsed:=Info.parse(str(row.text).to_ascii_buffer()); check(parsed.filter==row.filter and parsed.mipmap==row.mipmap and parsed.clamp==row.clamp,"Native TXI field parsing matches original instructions: "+str(row.text))
	for row in oracle.samplers:
		check(row.calls.any(func(item):return int(item[1])==0x2802 and int(item[2])==(0x812f if int(row.clamp)&1 else 0x2901)) and row.calls.any(func(item):return int(item[1])==0x2803 and int(item[2])==(0x812f if int(row.clamp)&2 else 0x2901)) and row.calls.any(func(item):return int(item[1])==0x2800 and int(item[2])==Sampler.mag_filter(row)) and row.calls.any(func(item):return int(item[1])==0x2801 and int(item[2])==Sampler.min_filter(row)),"GUI sampler policy matches captured original GL S/T/mag/min calls: "+str([row.target,row.filter,row.mipmap,row.clamp]))
	if DisplayServer.get_name()!="headless": await pixels(output)
	var window_state:={"focused":root.has_focus(),"unfocusable":root.unfocusable,"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"mouse_mode":Input.mouse_mode}
	await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window_state,"publicConnections":0,"fullUiParity":false,"scope":"Unchanged original sampler/TXI instruction observations, actual native GUI clamp/filter edge and mip pixels. Original-game GPU comparison, anisotropy and remaining TXI effects are separate."},"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
