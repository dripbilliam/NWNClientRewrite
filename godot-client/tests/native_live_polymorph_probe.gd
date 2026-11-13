extends "res://tests/native_live_quickbar_probe.gd"
# Physical native controls -> existing host -> actual original server. Never
# edits received actor/effect/appearance state or treats a local layout as ACK.
func appearance() -> int:return int(probe.current().get("appearance",{}).get("appearance",-1))
func self_shape_menu(expected: bool,activate: bool=false) -> bool:
	var position: Array=probe.current().get("replicated",{}).get("position",[])
	if not probe.check(position.size()==3,"Actual controlled position supplies the self-wheel world context"):return false
	desktop.open_radial({"id":desktop.actor_id,"position":Vector3(position[0],position[2],-position[1]),"origin":"world"},Vector2(700,300));await probe.get_tree().process_frame
	var source: Dictionary=desktop.radial_entries.get(4,{})
	var flags:=int(probe.current().get("playerState",{}).get("playerFlags",0))
	if not probe.check(desktop.radial.active and (source.get("action","")=="world-cancel-polymorph")==expected,"Received playerFlags select the original self-wheel Cancel Polymorph role",{"flags":flags,"role":source,"expected":expected}):return false
	if activate:
		if not probe.check(expected and source.label=="Cancel Polymorph" and source.icon=="IR_SKILLSELF","Actual self-wheel cancellation uses the original source caption/icon"):return false
		return await choose(4)
	await click(desktop.radial.center.get_global_rect().get_center())
	return probe.check(not desktop.radial.active,"Physical center dismisses the inspected self wheel without cancellation")
func query_state(expected: int,label: String) -> bool:
	var sequence: int=probe.ui.chat.sequence
	probe.ui.chat.submit("-native-poly-state")
	return await probe.wait_for(func():return probe.ui.chat.rows.any(func(row):return int(row.get("chat_sequence",0))>sequence and str(row.get("text","")).contains("NATIVE_POLY_STATE:"+str(expected))),label)
func use(index: int) -> bool:
	if not await open(index):return false
	if not probe.check(desktop.radial_entries.size()==2 and desktop.radial_entries.has(3) and desktop.radial_entries[3].label=="Cancel Polymorph" and desktop.radial_entries[3].icon=="IR_SKILLSELF","Original bound43 menu exposes actual Cancel Polymorph source caption/icon and Clear"):return false
	return await choose(3)
func run(owner) -> void:
	probe=owner;desktop=probe.desktop
	if not probe.check(DisplayServer.get_name()=="headless","Polymorph acceptance uses the owned headless native UI"):return
	if not await probe.wait_for(func():return desktop.quick_bindings.size()==36 and desktop.quickbar_frame.layout_ready and appearance()>=0,"Actual controlled actor appearance and source quickbar geometry are received"):return
	var index:=35;var previous: Dictionary=desktop.quick_bindings[index].duplicate(true);var baseline:=appearance();var actor: int=desktop.actor_id;var epoch: int=desktop.generation;var form:=int(probe.session.args.get("polymorph-test-appearance","-1"))
	if not probe.check(form>=0 and form!=baseline,"Owned active-polymorph table supplies a distinct physical appearance",{"baseline":baseline,"form":form,"actorId":actor}):return
	desktop.assign(index,{"type":43,"intParam":0})
	if not await probe.wait_for(func():return int(desktop.quick_bindings[index].get("type",0))==43,"Protocol owner reflects the client-owned43 scratch layout"):return
	if not await query_state(baseline,"Original server reports the baseline appearance before cancellation"):return
	if not await self_shape_menu(false):return
	if not await use(index):return
	if not await query_state(baseline,"Original server remains in baseline shape when no polymorph exists"):return
	if not probe.check(appearance()==baseline and desktop.actor_id==actor,"No-effect cancellation preserves actual received control and shape"):return
	probe.ui.chat.submit("-native-poly-unlocked")
	if not await probe.wait_for(func():return appearance()==form,"Original EffectPolymorph changes the actual received actor appearance"):return
	if not await probe.wait_for(func():var flags:=int(probe.current().get("playerState",{}).get("playerFlags",0));return (flags&1024)!=0 and (flags&131072)==0,"Original player update discloses unlocked shape eligibility independently of appearance"):return
	if not await query_state(form,"Independent original-server GetAppearanceType confirms the unlocked form"):return
	var began:=Time.get_ticks_usec()
	if not await self_shape_menu(true,true):return
	if not await probe.wait_for(func():return appearance()==baseline,"Physical native self-wheel action causes original-server appearance reversion"):return
	probe.check(true,"Shape reversion retains native input-to-publication timing",{"elapsedUsec":Time.get_ticks_usec()-began,"baseline":baseline,"form":form,"actorId":actor})
	if not await query_state(baseline,"Independent original-server GetAppearanceType confirms restored baseline"):return
	if not probe.check(desktop.actor_id==actor and desktop.generation==epoch,"Polymorph/reversion keeps the same authoritative controlled object and area lifetime"):return
	probe.ui.chat.submit("-native-poly-locked")
	if not await probe.wait_for(func():return appearance()==form,"Original server applies the locked polymorph test effect"):return
	if not await probe.wait_for(func():return (int(probe.current().get("playerState",{}).get("playerFlags",0))&131072)!=0,"Original player update discloses the shape lock bit"):return
	if not await self_shape_menu(false):return
	if not await use(index):return
	if not await query_state(form,"Original server lock guard retains shape after the same native43 request"):return
	if not probe.check(appearance()==form and desktop.actor_id==actor,"Locked cancellation cannot predict a local shape restoration"):return
	desktop.assign(index,previous)
	if not await probe.wait_for(func():return desktop.quick_bindings[index]==previous,"Client-owned scratch layout restores every previous binding field"):return
	probe.check(true,"Polymorph source menu CPU timings retained",{"menus":desktop.shortcut_timings.duplicate(true),"scope":"Headless source control/input/received original-server state; original pixels, animation rendering and FPS are separate gates."})
