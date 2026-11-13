extends RefCounted
const Geometry=preload("res://systems/native_data/gui_model_geometry.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const MeshSampler=preload("res://systems/native_data/animated_mesh.gd")
const Bitmap=preload("res://systems/native_data/portrait_chooser_layout.gd")
static func parse(model: Dictionary) -> Dictionary:
	var geometry:=Geometry.model(model)
	if not str(geometry.error).is_empty(): return geometry
	var states: Dictionary={}; var resources: Dictionary={}
	for state in ["up","hilite"]:
		var posed:=Pose.nodes(model,[{"clip":state,"time":0.0}])
		if not str(posed.error).is_empty(): return posed
		var source: Dictionary=posed.model.duplicate(true)
		for clip in model.animations:
			if str(clip.name)!=state: continue
			for track in clip.get("mesh_tracks",[]):
				var sample:=MeshSampler.sample(track.data,0)
				for node in source.nodes:
					if str(node.name)!=str(track.node): continue
					if sample.has("positions"): node.mesh.vertices=sample.positions
					if sample.has("uv"): node.mesh.uv=[sample.uv]
		var parts: Array=[]
		for node in source.nodes:
			var mesh: Dictionary=node.get("mesh",{})
			if not mesh.get("render",false): continue
			if mesh.get("textures",[]).size()!=1: return {"error":"Original chat reply texture layers are unsupported"}
			var isolated: Dictionary=source.duplicate(true)
			for entry in isolated.nodes:
				if str(entry.name)!=str(node.name): entry.mesh={}
				else: entry.mesh.textures=["gui_replace01"]
			var plane:=Bitmap.bitmap(isolated)
			if not str(plane.error).is_empty(): return plane
			plane.rect.position-=geometry.bounds.position; plane.resource=str(mesh.textures[0]); plane.id=str(node.name); parts.append(plane); resources[plane.resource]=true
		states[state]=parts
	return {"error":"","bounds":geometry.bounds,"states":states,"resources":resources.keys()}
