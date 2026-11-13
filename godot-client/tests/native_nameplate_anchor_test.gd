extends "res://tests/native_nameplate_geometry_test.gd"
const Anchor=preload("res://systems/native_data/nameplate_anchor.gd")
func source_checks(plate,catalog) -> void:
	super.source_checks(plate,catalog)
	var path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--anchor-oracle="): path=arg.trim_prefix("--anchor-oracle=")
	var evidence: Variant=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check(evidence is Dictionary and evidence.get("target","")=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Anchor observations come from the pinned unchanged original binary")
	if not evidence is Dictionary: return
	for row in evidence.heights:
		# JSON decimal parsing is binary64; compare the original stored FLOAT bits.
		var stored:=PackedFloat32Array([float(row.height)])
		check(Anchor.height_for_head(bool(row.found),float(row.head))==stored[0],"Original model-hook height at "+str([row.found,row.head]))
	for row in evidence.rows:
		var input: Dictionary=row.input
		var position:=Vector3(input.position[0],input.position[2]+input.height,-input.position[1]); var camera:=Vector3(input.camera[0],input.camera[2],-input.camera[1]); var expected:=Vector3(row.projected[0],row.projected[2],-row.projected[1])
		check(Anchor.lift(position,camera).distance_to(expected)<0.000001,"Original camera-distance lift "+str([input.position,input.camera,input.height]))
		check(Anchor.screen(Vector2(input.screen[0],input.screen[1]))==Vector2(row.screen[0],row.screen[1]),"Original projected pixel rounding "+str(input.screen))
	var model: Dictionary={"nodes":[{"name":"root","parent":-1},{"name":"HEADCONJURE","parent":0}],"rig_asset":{"defaults":[{"position":[0,1,0],"quaternion":[0,0,0,1],"scale":[2,2,2]},{"position":[0,0.5,0],"quaternion":[0,0,0,1],"scale":[1,1,1]}]}}
	check(Anchor.model_height(model)==Anchor.height_for_head(true,2),"Physical hook height includes its original parent transforms and ignores naming case")
	model.nodes[1].name="weapon"; check(Anchor.model_height(model)==Anchor.height_for_head(false,0),"Missing original headconjure uses the native fixed fallback instead of mesh bounds")
	var registry:=Registry.new(); plate.get_parent().add_child(registry); var actor:=Node3D.new(); registry.add_child(actor); actor.position=Vector3(3,1,-4); actor.set_meta("native_nameplate_height",1.75)
	registry.entities={42:{"type":5}}; registry.native_owners[42]=actor; registry.native_bounds[42]=AABB(Vector3(-20,-1,-20),Vector3(40,100,40))
	var camera:=Vector3(0,6,10); var expected:=Anchor.lift(Vector3(3,2.75,-4),camera)
	check(registry.nameplate_position(42,camera).distance_to(expected)<0.000001,"Registry uses installed creature hook height rather than a tall weapon/wing bounding box")
	registry.native_bounds[42]=AABB(Vector3(-100,-50,-100),Vector3(200,500,200))
	check(registry.nameplate_position(42,camera)==expected,"Changing animated or attached mesh bounds cannot move the source creature label anchor")
	actor.position.x+=5
	check(registry.nameplate_position(42,camera).distance_to(Anchor.lift(Vector3(8,2.75,-4),camera))<0.000001,"Moving the actual actor updates its source anchor without rebuilding model data")
	registry.entities[42].type=9
	check(registry.nameplate_position(42,camera)==registry.label_position(42),"This creature source correction does not silently substitute a prop anchor policy")
	registry.queue_free()
