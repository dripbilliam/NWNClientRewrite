extends RefCounted
# Explicit local diagnostic only. Never starts playback, resolves/builds a lazy
# clip, advances clocks or serializes live Nodes/Resources/Callables.
static func property(owner: Object,key: String,fallback: Variant=null) -> Variant:
	if not is_instance_valid(owner): return fallback
	for field in owner.get_property_list():
		if str(field.name)==key: return owner.get(key)
	return fallback
static func capture(world: Node,id: int,label: String="") -> Dictionary:
	if not is_instance_valid(world) or bool(property(world,"closed",false)) or bool(property(world,"retiring",false)): return {"error":"No active world"}
	var desired: Dictionary=property(world,"desired",{})
	if not desired.has(id): return {"error":"Entity is no longer in this world"}
	var source: Dictionary=desired[id].get("object",{})
	var instances: Dictionary=property(world,"instances",{})
	var actor: Node=instances.get(id)
	var wire: Dictionary=source.get("replicated",{}); var state: Dictionary={}
	for key in ["position","orientation","animation","animationSpeed","animationTime","path","walkRate","runRate","actionFlag","facingTarget","visibility"]:
		if wire.has(key): state[key]=wire[key].duplicate(true) if wire[key] is Dictionary or wire[key] is Array else wire[key]
	var result:={"version":1,"kind":"native-entity-inspection","at_unix_ms":int(Time.get_unix_time_from_system()*1000),"generation":int(property(world,"generation",-1)),"area_id":int(property(world,"area_id",-1)),"id":id,"name":label,"object_type":int(source.get("objectType",-1)),"rendered":is_instance_valid(actor),"appearance":source.get("appearance",{}).duplicate(true),"replicated":state,"models":[],"scope":"Explicit local entity diagnostic; received state and current private playback metadata, no server commands or model/clip preparation"}
	if not is_instance_valid(actor): return result
	result.scene={"visible":actor.is_visible_in_tree() if actor is Node3D else false,"can_process":actor.can_process(),"process_mode":actor.process_mode,"failure":str(property(actor,"failure",""))}
	result.model_names=property(actor,"model_names",[]).duplicate()
	result.animation_sources=property(actor,"source_dependencies",[]).duplicate(true)
	var rigs: Node=property(actor,"rigs")
	if not is_instance_valid(rigs): return result
	var entities: Dictionary=property(rigs,"entities",{})
	var entry: Dictionary=entities.get(id,{})
	var stats: Dictionary=property(rigs,"stats",{})
	result.rig={"processing":rigs.is_processing(),"animation":int(entry.get("animation",-1)),"side":int(entry.get("side",-1)),"body_type":int(entry.get("body_type",-1)),"context":entry.get("context",{}).duplicate(true),"part_count":entry.get("authored_names",[]).size(),"missing_requested_clips":stats.get("missing_requested_clips",[]).duplicate(),"failures":stats.get("failures",[]).duplicate(),"pose_frames":int(stats.get("pose_frames",0))}
	var requested:=""
	if rigs.has_method("clip_name"): requested=rigs.clip_name(id,int(entry.get("animation",-1)))
	var models: Array=entry.get("models",[])
	for index in models.size():
		var model: Dictionary=models[index]; var asset: Dictionary=model.get("asset_source",{})
		var available: Array=[]
		for clip in asset.get("clips",[]):
			var name:=str(clip.get("name",""))
			if not name.is_empty() and not available.has(name): available.append(name)
		available.sort()
		var active:=str(model.get("clip",""))
		var player: AnimationPlayer=model.get("player")
		result.models.append({"index":index,"resource":str(result.model_names[index]) if index<result.model_names.size() else str(asset.get("name","")),"follow":bool(model.get("follow",false)),"requested_clip":requested,"requested_available":available.has(requested),"active_clip":active,"active_available":available.has(active),"time":float(model.get("last_time",0)),"speed":float(model.get("speed",1)),"loop":bool(model.get("loop",false)),"serial":int(model.get("play_serial",0)),"native_owner":model.get("native_owner")!=null,"player_present":is_instance_valid(player),"player_playing":player.is_playing() if is_instance_valid(player) else false,"instantiated_clips":model.get("names",{}).keys(),"available_clips":available})
	return result
