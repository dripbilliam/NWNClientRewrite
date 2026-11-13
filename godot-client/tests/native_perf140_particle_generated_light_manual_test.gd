extends SceneTree
# Source-only fixture, not yet executed. No world/server, GPU or FPS claim.
const Rigs=preload("res://systems/model_rigs.gd")
const Model=preload("res://systems/native_render/effect_model.gd")
const Placeables=preload("res://systems/native_render/placeable_lights.gd")
const PointLight=preload("res://systems/native_render/model_point_light.gd")
const Palette=preload("res://systems/native_render/native_light_palette.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures.append(message)
func set_mode(retained: bool) -> void:
	OS.set_environment("NWN_GENERATED_LIGHT_MANUAL","retained" if retained else "")
func make_row(scene: Node3D,retained: bool,q: Quaternion=Quaternion.IDENTITY,s: Vector3=Vector3.ONE) -> Dictionary:
	var publisher:=Placeables.new();scene.add_child(publisher);publisher.set_process(false)
	var model:=Model.new();publisher.add_child(model);model.set_process(false);model.installed=true
	model.model_names=["FX_PLACEABLE01"];model.reference_graphs=[null];model.set_meta("native_model_name","fx_placeable01");model.set_meta("native_generated_placeable_id",17)
	var rig:=Rigs.new();model.add_child(rig);rig.set_process(false);model.rigs=rig
	var holder:=Node3D.new();model.add_child(holder);var part:=Node3D.new();holder.add_child(part);part.scale=s
	var nodes: Array[Node3D]=[part]
	var entry:={"root":holder,"nodes":nodes,"parents":[-1],"models":[{"player":null,"asset_source":{},"part_source":{},"clip":"","last_time":0.0}],"animated_models":[],"manual_poses":{},"attachments":[],"skins":[],"model_parts":[[0]],"authored_names":["root"],"clip_map":{},"side_maps":{},"side":0,"loop_map":{},"animation":-1,"counts":{}}
	rig.entities[0]=entry
	check(rig.set_manual_pose(0,part,Vector3(0.25,0.5,0.75),q),"Actual ModelRigs immediate manual publication accepts fixture")
	var light:=PointLight.new();light.set_meta("native_enhanced_light",true);light.set_meta("native_model_light_properties",{"radius":6.0,"multiplier":0.8,"color":[1.0,0.8,0.3],"shadow":1.0});part.add_child(light);light.position=Vector3(0.2,1.0,0.3)
	var anchor:=Node3D.new();scene.add_child(anchor)
	check(model.attach_to(anchor),"Actual generated-light ancestor follower attaches")
	publisher.instances[17]=model
	set_mode(retained);var enrolled: bool=rig.enroll_generated_manual(0,model,publisher)
	return {"publisher":publisher,"model":model,"rig":rig,"part":part,"entry":entry,"light":light,"anchor":anchor,"retained":retained,"enrolled":enrolled}
func enroll(row: Dictionary) -> bool:
	set_mode(row.retained)
	return row.rig.enroll_generated_manual(0,row.model,row.publisher)
func bytes(values: Array) -> PackedByteArray:return PackedFloat32Array(values).to_byte_array()
func transform_bits(t: Transform3D) -> PackedByteArray:
	var values: Array=[]
	for vector in [t.basis.x,t.basis.y,t.basis.z,t.origin]:values.append_array([vector.x,vector.y,vector.z])
	return bytes(values)
func sample(row: Dictionary) -> Dictionary:
	# Force the ACTUAL model-light notification/Palette.update consumer, then
	# compare its published CPU palette entry without relying on setter counts.
	row.light.force_update_transform()
	var local: Transform3D=row.part.transform;var global: Transform3D=row.part.global_transform
	var q: Quaternion=global.basis.orthonormalized().get_rotation_quaternion();var scale: Vector3=global.basis.get_scale()
	var position: Vector3=global.origin
	var light_position: Vector3=row.light.global_position
	return {"local":transform_bits(local),"global":transform_bits(global),"scale":bytes([scale.x,scale.y,scale.z]),"particle_pose":bytes([position.x,-position.z,position.y,q.w,q.x,-q.z,q.y]),"light":bytes([light_position.x,light_position.y,light_position.z,row.light.omni_range,row.light.light_energy]),"palette_shape":Palette.image.get_pixel(0,row.light.native_slot),"palette_policy":Palette.image.get_pixel(1,row.light.native_slot),"pose_frames":row.rig.stats.pose_frames}
func cold_revision_cases(scene: Node3D) -> void:
	var row:=make_row(scene,false)
	check(not row.entry.has("generated_manual_publication") and not row.entry.has("generated_manual_revision"),"Ordinary immediate manual/follower setup acquires no token or revision key")
	var before: Dictionary=row.entry.duplicate(true)
	row.rig.revoke_generated_manual(0,"ordinary_no_token")
	row.rig.revoke_generated_manual(999,"missing_entity")
	check(row.entry==before,"No-token and missing-entity invalidation perform no record write")
	# An old serialized/debug revision does not establish an observer. Only an
	# actual acquired token requires subsequent mutation revisions.
	row.entry.generated_manual_revision=41
	before=row.entry.duplicate(true)
	row.rig.revoke_generated_manual(0,"no_token_existing_revision")
	check(row.entry==before,"No-token invalidation leaves a preexisting revision unchanged")
	row.entry.erase("generated_manual_revision")
	var latest:=Vector3(0.6,0.8,1.1)
	check(row.rig.set_manual_pose(0,row.part,latest,Quaternion.IDENTITY),"Cold ordinary authored mutation remains immediate")
	row.rig.play_native(0,0,"missing",1.0,0,0.0)
	row.rig.set_playback(0,999)
	row.rig.set_model_colour_scope(0,0,0,null)
	row.rig.configure(null,{}, {})
	check(not row.entry.has("generated_manual_publication") and not row.entry.has("generated_manual_revision"),"Ordinary manual/native/authored/colour/configure boundaries do not manufacture revision state")
	check(row.part.position==latest and row.entry.manual_poses[0].position==latest,"No-token early return leaves actual authored record and immediate node publication current")
	row.retained=true
	check(enroll(row),"Cold enrollment acquires from the current authored record without mutation history")
	var first: RefCounted=row.entry.generated_manual_publication
	check(first.revision==0 and not row.entry.has("generated_manual_revision"),"First acquired token uses the explicit cold revision default without writing the record")
	row.rig._update(0.0);row.rig._update(0.0)
	check(first.active and first.armed and row.part.position==latest,"Cold enrollment warms from current authored pose and two original publications")
	var original_omitted: int=first.omitted_publications
	row.rig.set_manual_pose(0,row.part,latest,Quaternion.IDENTITY)
	check(int(row.entry.generated_manual_revision)==1 and not first.active and not first.armed,"Acquired equal-value command increments revision and revokes before setters")
	row.rig.revoke_generated_manual(0,"already_revoked")
	check(int(row.entry.generated_manual_revision)==2 and not first.active,"An acquired but already revoked token still receives every mutation revision")
	check(enroll(row),"Revoked owner can explicitly acquire a fresh token")
	var replacement: RefCounted=row.entry.generated_manual_publication
	check(replacement!=first and replacement.revision==2 and replacement.active and not replacement.armed,"Replacement token captures the current acquired revision and must warm again")
	check(not first.omit(row.rig,row.entry,0),"Retained stale token cannot omit after replacement")
	first.published(row.rig,row.entry,0)
	check(not first.active and not first.armed and first.omitted_publications==original_omitted,"Stale publication cannot rearm an old acquired token")
	row.rig._update(0.0);row.rig._update(0.0)
	check(replacement.armed,"Replacement warms only through actual original updates")
	# Exercise the real synchronous signal callback boundary without inventing
	# an animated owner (which this narrow lease deliberately excludes).
	var next:=Vector3(0.9,1.2,1.5)
	var callback_state:={"called":false,"saw_revoked":false,"enrolled":false}
	var callback: Callable=func(_id: int,_model: int,_event: String,_serial: int):
		callback_state.called=true
		row.rig.set_manual_pose(0,row.part,next,Quaternion.IDENTITY)
		callback_state.saw_revoked=not replacement.active and int(row.entry.generated_manual_revision)==3
		callback_state.enrolled=enroll(row)
	row.rig.model_event.connect(callback)
	row.rig.model_event.emit(0,0,"fixture_callback_boundary",1)
	row.rig.model_event.disconnect(callback)
	var reentered: RefCounted=row.entry.generated_manual_publication
	check(callback_state.called and callback_state.saw_revoked and callback_state.enrolled,"Synchronous callback mutation revokes acquired state before explicit re-enrollment")
	check(reentered!=replacement and reentered.revision==3 and not reentered.armed and row.part.position==next,"Reentrant replacement observes current immediate pose and cannot inherit old warmup")
	check(not replacement.omit(row.rig,row.entry,0),"Old callback-held token cannot omit after reentrant replacement")
	row.rig._update(0.0)
	check(reentered.original_publications==1 and reentered.omitted_publications==0 and not reentered.armed,"First post-callback update preserves the original full manual publication")
	row.rig._update(0.0)
	check(reentered.armed and row.part.position==next,"Second post-callback original update proves the latest pose before retention")
	row.model.retire();row.publisher.instances.clear();row.anchor.free()
	# Enrollment validates current manual data rather than trusting a historical
	# default: an unobserved pre-enrollment quaternion change must reject reuse.
	var changed:=make_row(scene,false)
	changed.rig.set_manual_pose(0,changed.part,Vector3(0.2,0.3,0.4),Quaternion(Vector3.UP,0.4))
	check(not changed.entry.has("generated_manual_revision"),"Unobserved nonidentity command still has no token revision")
	changed.retained=true
	check(not enroll(changed),"Cold enrollment reads and rejects a current unproven quaternion despite absent revision history")
	check(changed.entry.generated_manual_publication.reason=="nonidentity_manual_rotation_or_scale","Cold refusal identifies the actual current authored state")
	changed.model.retire();changed.publisher.instances.clear();changed.anchor.free()
func revocation_cases(scene: Node3D) -> void:
	var row:=make_row(scene,true)
	check(row.enrolled,"Canonical uppercase model name and null graph placeholder enroll")
	row.rig._update(0.0);row.rig._update(0.0)
	check(row.rig.generated_manual_snapshot().entries[0].armed,"Lifecycle fixture actually reaches retained state")
	row.rig.play_native(0,0,"missing",1.0,0,0.0)
	check(not row.rig.generated_manual_snapshot().entries[0].active,"Native play revokes before unavailable/new-owner work")
	check(enroll(row),"Canonical owner may explicitly re-enroll unchanged exclusive state")
	row.rig.set_playback(0,999)
	check(not row.rig.generated_manual_snapshot().entries[0].active,"Authored playback boundary revokes before lookup")
	enroll(row);row.rig.configure(null,{}, {})
	check(not row.rig.generated_manual_snapshot().entries[0].active,"Reconfigure revokes before malformed/empty replacement")
	enroll(row)
	var target:=Rigs.new();scene.add_child(target);target.set_process(false);target.adopt_entities(row.rig,[0])
	check(not row.rig.generated_manual_snapshot().entries[0].active,"Adoption revokes source ownership before aliases become visible")
	check(not enroll(row),"Adopted/shared model remains outside exclusive enrollment")
	target.forget_entity(0);target.free();row.model.retire();row.publisher.instances.clear();row.anchor.free()
	var forgotten:=make_row(scene,true);forgotten.rig.forget_entity(0)
	check(forgotten.rig.generated_manual_snapshot().entries.is_empty(),"Forgotten entity cannot retain a resolvable lease")
	forgotten.model.retire();forgotten.publisher.instances.clear();forgotten.anchor.free()
func run() -> void:
	var args: Dictionary={}
	for value in OS.get_cmdline_user_args():
		var pair:=value.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report):quit(2);return
	var scene:=Node3D.new();root.add_child(scene)
	cold_revision_cases(scene)
	revocation_cases(scene)
	var identity:=[make_row(scene,false),make_row(scene,true)]
	check(not identity[0].enrolled and identity[1].enrolled,"Only explicit canonical identity route enrolls")
	var fallback:=[make_row(scene,false,Quaternion(Vector3.UP,0.73),Vector3(-1.2,0.8,1.1)),make_row(scene,true,Quaternion(Vector3.UP,0.73),Vector3(-1.2,0.8,1.1))]
	check(not fallback[0].enrolled and not fallback[1].enrolled,"General quaternion and negative/nonuniform scale stay original")
	var rows: Array=identity+fallback
	for frame in 32:
		for row: Dictionary in rows:
			row.anchor.position=Vector3(sin(frame*0.13),frame*0.01,cos(frame*0.11));row.anchor.quaternion=Quaternion(Vector3.UP,frame*0.03);row.anchor.scale=Vector3(1.2,0.8,1.1)
			# Match priority0 manual publication before priority10 following.
			if frame in [6,12]:
				var old: Dictionary=row.entry.manual_poses[0]
				check(row.rig.set_manual_pose(0,row.part,Vector3(0.3,0.6,0.9),old.quaternion),"Every real or equal manual command revokes/wakes before immediate setters")
				enroll(row)
			if frame==18:
				row.rig.set_model_colour_scope(0,0,0,null)
				var before: Dictionary=row.rig.generated_manual_snapshot()
				if row.retained and row.model==identity[1].model:check(not before.entries[0].active,"Native owner admission boundary revokes even if unavailable")
				enroll(row)
			row.rig._update(0.016);row.model._process(0.016)
			# Exercise consumers which populate different Node3D caches.
			if frame%3==0:
				var _rotation: Vector3=row.part.rotation
			if frame%3==1:
				var _quaternion: Quaternion=row.part.quaternion
			if frame%3==2:
				var _scale: Vector3=row.part.scale
		var a:=sample(identity[0]);var b:=sample(identity[1]);check(a==b,"Exact owned identity local/global/light/palette/particle inputs "+str(frame))
		check(sample(fallback[0])==sample(fallback[1]),"Exact general fallback after nonuniform/negative/Euler reads "+str(frame))
		if frame==0:
			var first: Dictionary=identity[1].rig.generated_manual_snapshot().entries[0]
			check(first.original_publications==1 and first.omitted_publications==0 and not first.armed,"First original P/Q/S publication is preserved")
		if not failures.is_empty():break
	var witness: Dictionary=identity[1].rig.generated_manual_snapshot()
	check(witness.entries[0].omitted_publications>0 and witness.entries[0].original_publications>=2,"Narrow route actually omits later commands after original warmup")
	for row: Dictionary in rows:
		check(row.rig.stats.pose_frames==32,"Owner keeps every update/clock boundary")
		row.model.retire();row.publisher.instances.clear();row.anchor.free()
	rows.clear();identity.clear();fallback.clear();scene.free();await process_frame;await process_frame
	set_mode(false)
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"witness":witness,"server_connections":0,"gpu_execution":false,"scope":"Private explicit generated-light manual publication: actual ModelRigs setters/follower/model-light palette CPU publication and exact local/global/particle inputs; identity-only enrollment, original first updates, manual/native revocation and general quaternion/nonuniform fallback. No GPU/FPS acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close();quit(0 if failures.is_empty() else 1)
