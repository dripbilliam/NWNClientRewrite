extends "res://tests/native_particle_schedule_test.gd"
const Indicators=preload("res://systems/native_data/party_indicators.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Talk=preload("res://systems/native_data/talk_text.gd")
const Frame=preload("res://systems/native_party_frame.gd")
const Party=preload("res://systems/server_party.gd")
const Plan=preload("res://systems/native_data/party_bar_layout.gd")
const Catalog=preload("res://systems/native_data/resource_catalog.gd")
const Actor=preload("res://systems/native_data/actor_model.gd")
const Pose=preload("res://systems/native_data/gui_pose.gd")
const Painter=preload("res://systems/native_gui_painter.gd")
const Art=preload("res://systems/native_ui_art.gd")
const Icons=preload("res://systems/native_item_icons.gd")
const Cache=preload("res://systems/native_data/prepared_cache.gd")
var portraits: Array=[]
class HeadlessFonts extends Node:
	signal loaded(name: String)
	var bindings: Dictionary={}
	var metrics: Dictionary={}
	func bind(control: Control,name: String) -> void: bindings[control.get_instance_id()]=name; control.set_meta("native_font_applied",name)
	func unbind(control: Control) -> void: bindings.erase(control.get_instance_id())
	func close() -> void: bindings.clear()
class QueuedModels extends Node:
	var textures: Dictionary={}
	var requests: Array=[]
	static func model_key(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String:
		return preload("res://systems/native_item_icons.gd").model_key(name,clip,overrides,turn,layer,poses,region)
	func request_model(name: String,clip: String="up",overrides: Dictionary={},turn: int=0,layer: String="",poses: Array=[],region: Rect2=Rect2()) -> String:
		requests.append([name,clip,poses]); return preload("res://systems/native_item_icons.gd").model_key(name,clip,overrides,turn,layer,poses,region)
	func close() -> void: requests.clear(); textures.clear()
class QueuedRasters extends Node:
	signal completed(id: int,result: Dictionary)
	var serial:=0
	func request(_name: String,_type: int,_decoder: String) -> int: serial+=1; return serial
	func close() -> void: pass
class RasterCatalog extends RefCounted:
	func raster_location(_name: String) -> Dictionary: return {"type":3}
	func has_resource(_name: String,type: int) -> bool: return type in [3,2033]
func object(id: int,leader: bool=false,singleton: bool=false,flags: int=1,mode: int=0) -> Dictionary:
	return {"id":id,"areaId":55,"objectType":5,"replicated":{"name":{"firstName":{"text":"Member"},"lastName":{"text":str(id)}},"field8D4":flags,"field8D6":mode,"party":{"leader":leader,"singleton":singleton}}}
func frames(count: int=2) -> void:
	for index in count: await process_frame
func oracle_checks(data: Dictionary) -> void:
	check(data.target==BINARY_SHA and data.status.size()==1320 and data.leader.size()==108,"Pinned original member/leadership instruction observations")
	for row in data.status:
		if not row.present: continue
		check(Indicators.state_clip(int(row.flags),int(row.mode))==str(row.clip).to_lower(),"Unchanged original member state "+str([row.flags,row.mode,row.current]))
	for row in data.leader:
		var projected:=Indicators.leadership(int(row.old),42,int(row.target),int(row.leader),int(row.singleton),bool(row.present))
		var calls: Array=row.calls.filter(func(call):return call[0]!="scene")
		check(int(projected.leader)==int(row.selected) and int(projected.result)==int(row.result) and same(projected.calls,calls).is_empty(),"Unchanged original shared leader attachment "+str([row.old,row.target,row.leader,row.singleton,row.present]))
	check(Indicators.state_clip(1,258)=="combat" and Indicators.state_clip(65536,28)=="dead","Original word/byte widths remain explicit")
func projection_checks(rules) -> void:
	var objects:={42:object(42,true,false),43:object(43,false,false,1,28)}
	var rows: Array=rules.party(objects,42,[43])
	check(rows[0].indicators.leader and rows[1].indicators.state=="resting","Actual native party projector carries source role and member state")
	objects[43].replicated.party.leader=true; rows=rules.party(objects,42,[43])
	check(not rows[0].indicators.leader and rows[1].indicators.leader,"A newly received leader replaces the old shared crest")
	for index in 20: rows=rules.party(objects,42,[43])
	check(rows[1].indicators.leader,"Repeated full snapshots do not replay an unchanged old leader flag")
	objects[42].replicated.party.leader=false; rows=rules.party(objects,42,[43])
	check(rows[1].indicators.leader,"A late revocation for the old leader cannot remove the new crest")
	rows=rules.party({},42,[43]); check(rows[1].indicators.leader and rows[1].indicators.state=="resting","Area-only object absence retains received party role/state for the retained roster")
	rows=rules.party(objects,42,[]); check(not rows[0].indicators.leader and rules.party_indicators.states.size()==1,"Roster removal retires cached role/state and detaches the crest")
	objects[42].replicated.party={"leader":true,"singleton":true}; rows=rules.party(objects,42,[])
	check(not rows[0].indicators.leader,"Original singleton does not place a shared leader crest on the controlled portrait")
	rules.party_indicators.reset(); rows=rules.party({43:{"id":43,"objectType":5}},42,[43]); check(rows[1].indicators.state.is_empty() and not rows[1].indicators.leader,"Fresh unknown status/role fields remain undisclosed")
	rows=rules.party({42:object(42,true,false)},42,[43]); rows=rules.party({44:object(44)},44,[])
	check(not rows[0].indicators.leader and rules.party_indicators.controlled==44,"A controlled-actor change retires the previous leadership context")
	rules.party_indicators.reset()
func present(panel,rules,objects: Dictionary,serial: int) -> void:
	panel.receive({"kind":"party-view","viewId":serial,"actorId":42,"rows":rules.party(objects,42,[43]),"actions":[]})
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or not args.has("install") or not args.has("oracle") or FileAccess.file_exists(args.report): quit(2); return
	var observations: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle)); oracle_checks(observations)
	var text:=Talk.new(); var rules:=Rules.new(); rules.text=text; projection_checks(rules)
	var catalog:=Catalog.new(); check(catalog.mount_install(args.install),"Original installed catalog opens read-only")
	var models: Dictionary={}
	for name in Plan.RESOURCES:
		var parser:=Actor.new(); models[name]=parser.parse(catalog.get_resource(name,2002)); check(parser.failure.is_empty(),"Read actual original party model "+name)
	var definition:=Plan.parse(models); check(str(definition.error).is_empty(),"Actual source party geometry includes role/status hooks and models")
	var parser:=Actor.new(); var rig:=parser.rig_asset(models.pb_mbr_state); var variants: Dictionary={}
	for clip in ["default","combat","resting","dead"]:
		var pose:=Pose.compose(rig,[{"clip":clip,"time":0.333332985639572}]); variants[Cache.digest(var_to_bytes(pose.meshes))]=true; check(str(pose.error).is_empty(),"Actual original member-state pose decodes "+clip)
	check(variants.size()==4,"All four original member-state clips retain distinct native mesh/UV data")
	var surface:=SubViewport.new(); surface.size=Vector2i(1000,700); surface.gui_disable_input=false; surface.handle_input_locally=true; surface.render_target_update_mode=SubViewport.UPDATE_DISABLED; root.add_child(surface); surface.notify_mouse_entered()
	var art:=Art.new(); root.add_child(art); art.models=QueuedModels.new(); art.add_child(art.models); art.catalog=RasterCatalog.new(); art.assets=QueuedRasters.new(); art.add_child(art.assets)
	var fonts:=HeadlessFonts.new(); root.add_child(fonts)
	var painter:=Painter.new(); root.add_child(painter); painter.art=art; painter.fonts=fonts
	var ui_root:=Control.new(); surface.add_child(ui_root); ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var panel:=Party.new(); ui_root.add_child(panel); panel.setup(); panel.portrait_selected.connect(func(index,_point):portraits.append(index))
	var frame:=Frame.new(); frame.requested=true; root.add_child(frame); frame.configure(panel,catalog,str(args.report)+".cache",text,painter); frame.models=models; frame.definition=definition; frame.activate()
	var objects:={42:object(42,true,false),43:object(43,false,false,1,2)}
	present(panel,rules,objects,1); await frames()
	var card: Control=panel.cards[1]; var indicator: TextureRect=card.get_node("Box/NativeState"); var leader: TextureRect=frame.leader
	check(indicator.visible and str(indicator.get_meta("native_state"))=="combat","Actual native member control receives the source combat clip")
	check(indicator.position.distance_to(Vector2(40,30))<0.001 and indicator.size.distance_to(Vector2(18,22))<0.001,"Member-state image retains its original Properties hook and18x22 geometry")
	check(leader.visible and leader.get_parent()==panel.cards[0].get_node("Box") and leader.position.distance_to(Vector2(12,88))<0.001 and leader.size==Vector2(32,16),"Single original leader crest attaches to controlled portrait root at authored size")
	check(art.models.requests.any(func(value):return value[0]=="pb_mbr_state" and value[1]=="combat"),"Source member state binds to the active native art owner")
	var identity:=indicator.get_instance_id(); var crest_identity:=leader.get_instance_id(); var request_count: int=art.models.requests.size()
	for index in 30: present(panel,rules,objects,2+index)
	check(indicator.get_instance_id()==identity and leader.get_instance_id()==crest_identity and art.models.requests.size()==request_count,"Unchanged received views reuse controls, state imagery and the shared crest")
	objects[43].replicated.party.leader=true; objects[42].replicated.party.leader=false; objects[43].replicated.field8D6=28; present(panel,rules,objects,40)
	check(leader.get_instance_id()==crest_identity and leader.get_parent()==card.get_node("Box") and leader.position.distance_to(Vector2(6,37))<0.001,"Received leader promotion reparents the same source crest to the member portrait root")
	check(indicator.get_meta("native_state")=="resting" and indicator.get_instance_id()==identity,"Same-HP received state changes reuse the actual member control")
	var stale_key:=Icons.model_key("pb_mbr_state","combat"); var raster:=ImageTexture.create_from_image(Image.create(32,32,false,Image.FORMAT_RGBA8))
	art.deliver(stale_key,raster); check(indicator.texture==null and art.stale_bindings>0,"Late combat publication cannot replace the current resting artwork")
	art.deliver(Icons.model_key("pb_mbr_state","resting"),raster); check(indicator.texture==raster,"Current resting publication reaches the active indicator")
	objects[43].replicated.field8D4=0; present(panel,rules,objects,41); check(indicator.get_meta("native_state")=="dead","Original dead-state flag takes priority over the received resting action")
	var portrait: Button=card.get_node("Box/Portrait"); var point: Vector2=portrait.get_global_transform_with_canvas()*(portrait.size-Vector2(4,4))
	var motion:=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; surface.push_input(motion,true); await frames()
	var event:=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.button_mask=MOUSE_BUTTON_MASK_LEFT; surface.push_input(event,true); await frames(); event.pressed=false; event.button_mask=0; surface.push_input(event,true); await frames()
	check(portraits==[1] and leader.mouse_filter==Control.MOUSE_FILTER_IGNORE and indicator.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Actual portrait click remains connected beneath passive role/status images")
	panel.reset(); check(not leader.visible and leader.get_parent()==frame.stage and not art.bindings.has(str(indicator.get_instance_id())+":texture"),"Roster reset detaches the shared crest and releases its member-state listener before the card retires")
	await frames(); art.deliver(Icons.model_key("pb_mbr_state","dead"),raster); check(not leader.visible and panel.cards.is_empty(),"A retired member-state completion cannot restore the roster or crest")
	frame.close(); panel.queue_free(); frame.queue_free(); painter.queue_free(); art.close(); art.queue_free(); fonts.close(); fonts.queue_free(); surface.queue_free(); text.close(); catalog=null; await frames()
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"graphical":false,"publicConnections":0,"scope":"Original state/leadership instruction corpora, actual native party projector, source models/poses, native frame and headless pointer/retirement with controlled art publications. No original GUI pixels, live authority, locator or complete party/UI acceptance."}
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify(result,"\t")); file.close(); print("NATIVE_PARTY_INDICATORS ",checks," checks, ",failures.size()," failures"); quit(0 if result.success else 1)
