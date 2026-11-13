extends SceneTree
const Owner=preload("res://tools/native_parity/ui/actor-alpha-owner.gd")
const Enhanced=preload("res://systems/native_render/native_model_material.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func window_state() -> Dictionary:return {"screen":root.current_screen,"primary":DisplayServer.get_primary_screen(),"focused":root.has_focus(),"unfocusable":root.unfocusable,"mouse_mode":Input.get_mouse_mode()}
func wait_draw() -> void:
	for index in 4:await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output):quit(2);return
	var window:=window_state();check(window.screen==2 and window.screen!=window.primary and not window.focused and window.unfocusable and window.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Actual alpha smoke stays secondary/unfocused with visible mouse")
	var world:=Node3D.new();root.add_child(world)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(0.08,0.12,0.2);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_sky_contribution=0;world.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.0;camera.position=Vector3(0,0,8);world.add_child(camera);camera.current=true
	var base:=StandardMaterial3D.new();base.albedo_color=Color(0.8,0.3,0.1)
	var enhanced:=Enhanced.new();enhanced.configure(base,[1.0,1.0,1.0],[0.0,0.0,0.0])
	Palette.ambient(Vector3.ONE) # This isolated fixture has no area-light owner.
	var owners: Array=[];var meshes: Array=[];var sample_positions: Array=[]
	for row in 2:
		for column in 3:
			var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new();mesh.mesh.size=Vector2(1.5,1.5);mesh.material_override=base if row==0 else enhanced;mesh.position=Vector3((column-1)*2.1,1.1-row*2.2,0);world.add_child(mesh)
			var owner:=Owner.new();check(owner.enroll(mesh,0),"Pixel smoke enrolls actor-private material")
			check(owner.set_alpha([0.0,0.5,1.0][column]),"Pixel smoke applies native global factor")
			meshes.append(mesh);owners.append(owner);sample_positions.append(mesh.global_position)
	await wait_draw()
	var image:=root.get_texture().get_image();image.save_png(output.trim_suffix(".json")+"-alpha.png")
	var background: Color=image.get_pixel(15,15);var samples: Array=[]
	for position in sample_positions:
		var pixel: Vector2=camera.unproject_position(position);var colour:=image.get_pixel(int(pixel.x),int(pixel.y));samples.append([colour.r,colour.g,colour.b,colour.a])
	for row in 2:
		var zero: Array=samples[row*3];var half: Array=samples[row*3+1];var full: Array=samples[row*3+2]
		check(not meshes[row*3].visible and Vector3(zero[0],zero[1],zero[2]).distance_to(Vector3(background.r,background.g,background.b))<0.0001,"Zero alpha emits no visible surface pixels")
		check(full[0]>half[0] and half[0]>zero[0]+0.01,"Half alpha visibly blends with background instead of replacing pooled opaque colour")
		check(meshes[row*3+1].material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Partial actor is in the actual blended shader/material pass")
		check(meshes[row*3+2].material_override.albedo_color.a==1 and meshes[row*3+2].visible,"Opaque peer remains unaffected")
	check(base.albedo_color.a==1 and enhanced.albedo_color.a==1,"Both original shared input materials remain untouched after rendering")
	# With native area ambient explicitly zero, the Enhanced full peer is dark
	# unless RefreshHilite's independent additive selfillum path is published.
	Palette.ambient(Vector3.ZERO)
	for index in [0,2,3,5]:owners[index].set_vector(3,[0.25,0.5,0.75])
	await wait_draw()
	var vector_image:=root.get_texture().get_image();vector_image.save_png(output.trim_suffix(".json")+"-vector.png")
	var vector_samples: Array=[]
	for position in sample_positions:
		var pixel: Vector2=camera.unproject_position(position);var colour:=vector_image.get_pixel(int(pixel.x),int(pixel.y));vector_samples.append([colour.r,colour.g,colour.b,colour.a])
	for row in 2:
		check(vector_samples[row*3+2][2]>0.4 and meshes[row*3+2].material_override.emission_enabled,"Actual channel vector includes native additive selfillum rather than diffuse-only tint")
		check(not meshes[row*3].visible and Vector3(vector_samples[row*3][0],vector_samples[row*3][1],vector_samples[row*3][2]).distance_to(Vector3(background.r,background.g,background.b))<0.0001,"Vector changes do not resurrect zero-alpha geometry")
	for index in [0,2,3,5]:owners[index].set_vector(3,null)
	Palette.ambient(Vector3.ONE);await wait_draw()
	var clear_image:=root.get_texture().get_image()
	for index in [2,5]:
		var pixel: Vector2=camera.unproject_position(sample_positions[index]);var colour:=clear_image.get_pixel(int(pixel.x),int(pixel.y))
		check(close_pixels(colour,samples[index]),"Clearing the channel restores original diffuse/emission pixels")
	for index in [1,4]:owners[index].set_presentation_draw_enabled(false)
	await wait_draw()
	var gated_image:=root.get_texture().get_image();gated_image.save_png(output.trim_suffix(".json")+"-draw-gate.png")
	for index in [1,4]:
		var pixel: Vector2=camera.unproject_position(sample_positions[index]);var colour:=gated_image.get_pixel(int(pixel.x),int(pixel.y))
		check(not meshes[index].visible and colour.is_equal_approx(background),"Presentation draw gate suppresses actual pixels without deleting the mesh")
	for owner in owners:owner.close()
	world.free();await process_frame;await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"window":window,"samples":samples,"vector_samples":vector_samples,"background":str(background),"publicConnections":0,"performanceClaim":false,"originalClientComparison":false,"scope":"Actual Standard/Enhanced opaque/half/zero alpha, vector additive/diffuse clear and draw-gate pixels; native clocks/temporal effects and real creature assets checked separately."},"  ")+"\n");file.close();quit(0 if failures.is_empty() else 1)
func close_pixels(value: Color,expected: Array) -> bool:
	return absf(value.r-expected[0])<0.0001 and absf(value.g-expected[1])<0.0001 and absf(value.b-expected[2])<0.0001
