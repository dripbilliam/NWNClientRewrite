extends "res://systems/native_render/actor_instance.gd"
# Private animated physical Parts for received door state. No optimistic open
# state or local rule result is written back into the authoritative object.
const Names=preload("res://systems/native_data/object_animation.gd")
var received_state:=-1
var received_animation:=-1
var pending_rest:=-1
var remaining:=0.0
var door_stats:={"updates":0,"transitions":0,"missing_clips":[]}
func install_door(bundle: Dictionary,shared_pool,id: int,state: Dictionary) -> bool:
	var map: Dictionary={}
	for code in [0,14,22,50,51,72,77,99,100,213,214,215,216,300,301,302,303,304]: map[str(code)]=Names.name(10,code,int(state.get("destroyedModel",0)))
	var initial:=int(state.get("animation",{0:22,1:50,2:51,3:72}.get(Names.door_state(state),22)))
	if not install([{"bundle":bundle,"anchor":"","follow":true}],shared_pool,id,{"0":map},initial): return false
	observe_door(state); return true
func play_door(code: int,loop: bool) -> float:
	var length: float=rigs.clip_length(object_id,code)
	if length<=0:
		var clip:=Names.name(10,code)
		if not door_stats.missing_clips.has(clip): door_stats.missing_clips.append(clip)
		return 0
	rigs.set_playback(object_id,code,1.0,loop,true)
	return length
func observe_door(state: Dictionary) -> void:
	if retired or rigs==null: return
	var next:=Names.door_state(state); var animation:=int(state.get("animation",-1))
	if next==received_state and animation==received_animation: return
	var previous:=received_state; received_state=next; received_animation=animation; door_stats.updates+=1
	if animation in [300,301,302,303,304]:
		pending_rest={300:50,301:51,302:22,303:22,304:72}[animation]; remaining=play_door(animation,false); return
	if next<0: return
	var rest: int={0:22,1:50,2:51,3:72}[next]
	if previous>=0 and previous!=next and next in [0,1,2] and previous in [0,1,2]:
		var transition: int=(303 if previous==2 else 302) if next==0 else (301 if next==2 else 300)
		remaining=play_door(transition,false); pending_rest=rest; door_stats.transitions+=1
		if remaining>0: return
	pending_rest=-1; play_door(rest,true)
func _process(delta: float) -> void:
	if retired or pending_rest<0: return
	remaining-=delta
	if remaining<=0:
		var rest:=pending_rest; pending_rest=-1; play_door(rest,true)
