func extension_stamp()->ImageTexture:
	var image:=Image.create(16,16,false,Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			image.set_pixel(x,y,Color(.95,.12,.06) if (x/4+y/4)%2==0 else Color(.05,.2,.9))
	return ImageTexture.create_from_image(image)
func run_light_extension()->void:
	# Fresh world prevents earlier mesh/material/layer cases from masking a
	# missing consumer flag. Both worlds are freed through the normal engine path.
	free_capture();viewport.free();build();await settle(0,false,8)
	var key:=world.get_node("ShadowKey") as DirectionalLight3D
	var receiver:=world.get_node("Receiver") as MeshInstance3D
	key.hide();colored.hide();rigid.hide();skinned.position=Vector3.ZERO
	skinned.layers=1;receiver.layers=1;skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var spot:=SpotLight3D.new();spot.name="ConsumerSpot";spot.position=Vector3(0,6,4);spot.light_energy=7;spot.spot_range=20;spot.spot_angle=55;spot.light_color=Color(.9,.75,.5);spot.shadow_enabled=false;spot.light_size=0;world.add_child(spot);spot.look_at(Vector3(0,0,0));spot.hide()
	# Keep texture ownership across queued projector clear/free operations.
	var projector_stamp:=extension_stamp()
	await take("ordinary_cluster_lighting","nonshadow_off",0,false)
	spot.show();await take("ordinary_cluster_lighting","nonshadow_on",0,false)
	spot.position.x=1.5;spot.look_at(Vector3.ZERO);await take("ordinary_cluster_lighting","nonshadow_moved",0,false)
	spot.position.x=0;spot.look_at(Vector3.ZERO)
	skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await take("shadow_consumer_transitions","shadow_disabled",0,false)
	spot.shadow_enabled=true;await take("shadow_consumer_transitions","shadow_enabled_no_motion",0,false)
	await take("shadow_consumer_transitions","shadow_deform_a",0,false)
	await take("shadow_consumer_transitions","shadow_deform_b",.75,false)
	spot.light_size=0;await take("soft_shadow_consumer","hard_shadow",.75,false)
	spot.light_size=.8;await take("soft_shadow_consumer","soft_shadow",.75,false)
	spot.light_size=0;await take("soft_shadow_consumer","size_cleared",.75,false)
	spot.shadow_enabled=false;skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await take("projector_consumer","projector_off",0,false)
	spot.light_projector=projector_stamp;await take("projector_consumer","projector_on",0,false)
	spot.light_projector=null;await take("projector_consumer","projector_cleared",0,false)
	spot.light_cull_mask=0;await take("projector_consumer","mask_zero",0,false)
	spot.light_cull_mask=0xffffffff;await take("projector_consumer","mask_restored",0,false)
	# Existing Clustered does not re-pair geometry on a layer mutation. Build a
	# projector while the mesh is in a disjoint layer, then change only its layer.
	# Pose publication in take() preserves stable bounds and cannot create a new
	# private pair in the old path. The fix must restore the actual specialization.
	spot.free();receiver.layers=2;skinned.layers=1
	var layer_spot:=SpotLight3D.new();layer_spot.name="LayerCorrectnessSpot";layer_spot.position=Vector3(0,6,4);layer_spot.light_energy=7;layer_spot.spot_range=20;layer_spot.spot_angle=55;layer_spot.light_cull_mask=2;layer_spot.light_projector=projector_stamp;world.add_child(layer_spot);layer_spot.look_at(Vector3.ZERO)
	await take("layer_membership_correctness","layer_disjoint",0,false)
	skinned.layers=2;await take("layer_membership_correctness","layer_matches_without_motion",0,false)
	layer_spot.shadow_enabled=true;skinned.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	await take("layer_membership_correctness","shadow_after_layer_change",0,false)
	await take("layer_membership_correctness","deform_after_layer_change",.75,false)
	layer_spot.light_size=.6;await take("layer_membership_correctness","soft_after_layer_change",.75,false)
	layer_spot.free();skinned.hide();receiver.layers=1
	# A high caster outside the camera frustum still projects into the visible
	# receiver. Shadow dirty notifications must survive consumer filtering.
	var offscreen:=MeshInstance3D.new();offscreen.name="OffscreenCaster";var box:=BoxMesh.new();box.size=Vector3(2,1,2);offscreen.mesh=box;offscreen.position=Vector3(0,12,0);offscreen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;world.add_child(offscreen)
	var high_spot:=SpotLight3D.new();high_spot.name="OffscreenShadowSpot";high_spot.position=Vector3(0,16,0);high_spot.spot_range=30;high_spot.spot_angle=40;high_spot.light_energy=10;high_spot.shadow_enabled=true;world.add_child(high_spot);high_spot.look_at(Vector3.ZERO,Vector3.FORWARD)
	var camera:=world.get_node("Camera") as Camera3D
	var any_in_frustum:=false
	for x in [-1.,1.]:
		for y in [-.5,.5]:
			for z in [-1.,1.]:any_in_frustum=any_in_frustum or camera.is_position_in_frustum(offscreen.position+Vector3(x,y,z))
	check(not any_in_frustum,"Offscreen shadow caster has no box corner in camera frustum")
	await take("offscreen_shadow_membership","offscreen_shadow_a",0,false)
	offscreen.position.x=1.5;await take("offscreen_shadow_membership","offscreen_shadow_b",0,false)
	high_spot.shadow_enabled=false;await take("offscreen_shadow_membership","offscreen_shadow_disabled",0,false)
	offscreen.free();high_spot.free();skinned.show()
