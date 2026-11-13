extends Node
# Experimental engine-lit instance batches. Native retains exact corners,
# RGBA/atlas and original simulation. Godot supplies normal scene lighting,
# fog and depth to shared MultiMeshes; no per-emitter surface or callback.
const Surface=preload("res://systems/particle_instance_surface.gd")
var surfaces: Dictionary={}
var closed:=false
var failure:=""
var last_generation:=-1
var last_vertices:=0
var last_batches:=0
var priority_overflow:=false
func consume(frame: Dictionary) -> bool:
	if closed: return false
	var generation:=int(frame.get("generation",0))
	if generation<=last_generation: return true
	var occurrences: Dictionary={}; var used: Dictionary={}; var order:=0; var vertices:=0
	for row: Dictionary in frame.batches:
		var material_key:=str(row.material_key); var occurrence:=int(occurrences.get(material_key,0)); occurrences[material_key]=occurrence+1
		var key:=material_key+":"+str(occurrence); used[key]=true
		var surface: Node3D=surfaces.get(key)
		if surface==null:
			surface=Surface.new(); add_child(surface); surface.configure(row.texture,1,bool(row.additive),bool(row.two_sided),true); surfaces[key]=surface
		var count:=int(row.count); var capacity:=maxi(surface.capacity,maxi(96,count))
		if count>surface.capacity: capacity=mini(Surface.MAX_VERTICES,maxi(capacity,surface.capacity*2)); capacity=ceili(float(capacity)/6.0)*6
		var b: Array=row.bounds
		if not surface.apply_instances(1,generation,count,capacity,row.buffer,AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]))): failure="Native scene particle instance upload rejected"; return false
		# Native sorted runs retain their order inside each GPU batch. Godot has
		# 256 material priority levels; report overflow explicitly, never omit
		# runs or pretend arbitrary transparent ordering is solved.
		var priority:=clampi(order-128,-128,127)
		if surface.draw_material.render_priority!=priority: surface.draw_material.render_priority=priority
		vertices+=count; order+=1
	for key in surfaces:
		var surface: Node3D=surfaces[key]
		if not used.has(key) and surface.vertex_count>0:
			if not surface.apply_instances(1,generation,0,surface.capacity,PackedByteArray(),AABB()): failure="Native scene stale batch failed to hide"; return false
	priority_overflow=order>256; last_generation=generation; last_vertices=vertices; last_batches=order
	return true
func snapshot() -> Dictionary:
	return {"closed":closed,"failure":failure,"cached_surfaces":surfaces.size(),"active_batches":last_batches,"vertices":last_vertices,"generation":last_generation,"priority_overflow":priority_overflow}
func close() -> void:
	if closed: return
	closed=true
	for surface in surfaces.values(): surface.retire(); surface.queue_free()
	surfaces.clear()
func _exit_tree() -> void: close()
