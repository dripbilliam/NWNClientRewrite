extends SceneTree
const API=preload("res://systems/client_api/client_api.gd")
const ClientAPI=preload("res://systems/client_api/access.gd")
const Detached=preload("res://systems/client_api/detached.gd")
var checks:=0
var failures: Array=[]
var objects: Dictionary={}
var motion: Dictionary={}
var events: Array=[]
var callback_observations: Array=[]
var api: Node
var binding: RefCounted
var entities: RefCounted
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func row(id: int,type: Variant=5,area: Variant=7,life: Variant=1) -> Dictionary:
	return {"id":id,"objectType":type,"areaId":area,"nativeLifetime":life,"replicated":{"name":{"text":"Actor "+str(id)},"position":[1,2,3],"stats":{"classes":[{"id":1,"level":2}]}},"appearance":{"parts":[{"id":3}]}}
func apply(rows: Array,removed: Array=[],full: bool=false,controlled: Variant=1,connection: int=1,generation: int=1,area: int=7,player: Dictionary={}) -> bool:
	if full: objects.clear()
	for id in removed: objects.erase(int(id))
	for item in rows: objects[int(item.id)]=item
	return binding.commit(connection,generation,area,{"bridgeMode":"full" if full else "delta","controlledId":controlled,"objects":rows,"removedObjectIds":removed},player)
func capture(kind: String,event: Dictionary) -> void:
	events.append({"kind":kind,"event":event})
	callback_observations.append({"kind":kind,"count":entities.list_references().size(),"controlled":entities.get_controlled().object_id})
func run() -> void:
	api=API.install(root); entities=api.entities
	check(api.name=="ClientAPI" and root.get_node("ClientAPI").entities==entities,"Discoverable ClientAPI.entities provider")
	check(ClientAPI.entities==entities,"Literal ClientAPI.entities accessor works in actual SceneTree script launch mode")
	check(API.install(root)==api,"Bootstrap is idempotent and preserves API instance/counters")
	binding=api.bind_native(func(id):return objects.get(id),func(id):return motion.get(id))
	entities.scope_changed.connect(func(event):capture("scope",event))
	entities.entity_removed.connect(func(event):capture("removed",event))
	entities.entity_added.connect(func(event):capture("added",event))
	entities.entity_updated.connect(func(event):capture("updated",event))
	entities.controlled_entity_changed.connect(func(event):capture("controlled",event))
	check(entities.get_by_id(1)==null and entities.get_reference(1)==null,"Unknown IDs are explicit null")
	check(entities.get_by_id(null)==null and entities.get_reference(1.5)==null and entities.resolve(null)==null,"Malformed/missing IDs and null references never coerce into another entity")
	check(not entities.get_controlled().available and not entities.get_player_character().available,"Control and player identity begin unavailable")
	var a:=row(1); a.inventoryStats={"skills":[{"index":3,"rank":4}],"armorClass":null}; a.playerState={"combat":{"canLevelUp":true}}; a.clientAbilityCache={"uses":{"3":2}}
	check(apply([row(9,7),row(3,6,8,3),a],[],true),"Accepted complete raw publication")
	check(events.map(func(e):return e.kind)==["scope","added","added","added","controlled"],"Initial event order is scope, ID-sorted additions, control")
	check(events.filter(func(e):return e.kind=="added").map(func(e):return e.event.object_id)==[1,3,9],"Added events sort by object ID")
	check(callback_observations.all(func(e):return e.count==3 and e.controlled==1),"All synchronous callbacks see the completely committed state")
	check(entities.list_references().size()==3,"Known entities include previsual triggers and off-area items")
	check(entities.list_references({"current_area":true}).size()==2,"Current area filter excludes off-area objects")
	check(entities.list_references({"object_type":7})[0].object_id==9,"Basic type filtering includes non-renderable entities")
	check(entities.list_references({"object_types":[5,6],"area_id":8})[0].object_id==3,"Combined area and type filters")
	check(entities.list_references({"object_types":"bad"}).is_empty() and entities.get_by_id(1.5)==null,"Invalid filters and fractional IDs cannot address a valid object")
	var reference: Dictionary=entities.get_reference(1)
	check(entities.resolve(reference).identity.object_id==1,"Current reference resolves")
	check(entities.get_controlled().reference==reference,"Controlled lookup returns the scoped reference")
	check(entities.get_player_character().reason=="identity_not_received","Controlled ID never fabricates a player-character ID")
	var snapshot: Dictionary=entities.get_by_id(1)
	check(snapshot.character.available and snapshot.character.value.inventory_stats.value.skills[0].rank==4,"Received character sources are available unchanged")
	check(snapshot.character.value.inventory_stats.value.armorClass==null,"Received null stats remain null")
	check(snapshot.client_data.ability_cache.available and snapshot.client_data.ability_cache.source=="client_initialized_ability_cache" and not snapshot.received.value.has("clientAbilityCache"),"Client ability cache has separate provenance and cannot masquerade as direct server stats")
	check(not snapshot.presentation.available,"Previsual entity is queryable with unavailable presentation")
	check(snapshot.identity.name.value.text=="Actor 1" and snapshot.appearance.value.parts[0].id==3,"Identity and appearance fields exposed")
	snapshot.received.value.replicated.stats.classes[0].level=999
	snapshot.appearance.value.parts[0].id=999
	snapshot.character.value.inventory_stats.value.skills[0].rank=999
	reference.lifetime=999
	check(objects[1].replicated.stats.classes[0].level==2 and objects[1].appearance.parts[0].id==3 and objects[1].inventoryStats.skills[0].rank==4,"Recursive snapshot mutation cannot reach canonical data")
	check(entities.get_reference(1).lifetime!=999 and entities.get_by_id(1).received.value.replicated.stats.classes[0].level==2,"Mutating returned references/snapshots cannot affect subsequent queries")
	var list: Array=entities.list_references(); list.clear()
	check(entities.list_references().size()==3,"Reference enumeration is detached")
	var scope: Dictionary=entities.get_scope(); scope.area_id=900
	check(entities.get_scope().area_id==7,"Scope views are detached")
	motion[1]={"lifetime":44,"position":Vector3(9,8,7),"render":Vector3(8,8,7),"orientation":Vector3(1,0,0),"active":true,"driveHeld":true,"path":[Vector3(9,9,7)]}
	snapshot=entities.get_by_id(1)
	check(snapshot.received.source=="client_received_read_model" and snapshot.presentation.source=="client_simulated" and snapshot.presentation.coordinates=="NWN","Received and simulated states carry explicit source/coordinate labels")
	check(snapshot.replicated.value.position==[1,2,3] and snapshot.presentation.value.position==Vector3(9,8,7) and snapshot.presentation.value.render==Vector3(8,8,7),"Presentation motion never overwrites last received server position")
	snapshot.presentation.value.path[0]=Vector3.ZERO
	check(motion[1].path[0]==Vector3(9,9,7),"Presentation nested data is detached")
	var metrics: Dictionary=entities.diagnostics(); var original: Dictionary=entities.get_reference(1)
	events.clear()
	a=row(1); a.replicated.position=[4,5,6]
	check(apply([a],[],false,9),"Accepted delta update")
	check(entities.get_reference(1)==original and entities.list_references().size()==3,"Delta preserves lifetime and untouched objects")
	check(entities.get_by_id(1).replicated.value.position==[4,5,6],"Delta reads canonical merged object row")
	check(entities.diagnostics().full_removal_visits==metrics.full_removal_visits and entities.diagnostics().source_rows==metrics.source_rows+1,"Delta work touches changed rows without a world-removal scan")
	check(events.map(func(e):return e.kind)==["updated","controlled"],"Update precedes controlled-change event")
	check(entities.get_controlled().object_id==9 and not entities.get_player_character().available,"Possession control stays distinct from unavailable player identity")
	apply([],[],false,9,1,1,7,{"available":true,"object_id":1,"provenance":"authored_explicit_player_identity"})
	check(entities.get_player_character().object_id==1 and entities.get_controlled().object_id==9,"Explicit provider identity can differ from the controlled entity")
	check(entities.get_player_character().provenance=="authored_explicit_player_identity","Player identity includes explicit provenance")
	var old9: Dictionary=entities.get_reference(9); events.clear()
	apply([row(3,6,8,3)],[],true,3)
	check(entities.resolve(old9)==null and entities.resolve(original)==null,"Complete publication retires absent entities")
	check(events.map(func(e):return e.kind)==["removed","removed","updated","controlled"],"Full removal/update/control order is deterministic")
	var old3: Dictionary=entities.get_reference(3); events.clear()
	apply([row(3,6,8,30)],[],false,3)
	check(entities.resolve(old3)==null and entities.get_reference(3).lifetime>old3.lifetime,"Same ID with new nativeLifetime invalidates the previous entity")
	check(events.map(func(e):return e.kind)==["removed","added","controlled"],"ID replacement publishes remove/add and changed controlled reference")
	old3=entities.get_reference(3); apply([], [3],false,3)
	check(entities.get_controlled().reason=="entity_not_known" and entities.get_controlled().object_id==3,"Known control ID with missing entity stays explicit")
	apply([row(3,6,8,30)],[],false,3)
	check(entities.resolve(old3)==null,"Removal/reappearance invalidates references even if transport token is unchanged")
	old3=entities.get_reference(3); var dead:=row(3,6,8,30); dead.replicationRemoved=true; apply([dead],[],false,3)
	check(entities.get_by_id(3)==null and entities.get_reference(3)==null,"Cached replicationRemoved rows are unavailable before visual removal")
	apply([row(3,6,8,30)],[],false,3)
	check(entities.resolve(old3)==null,"Recreating a replication-removed cached ID gets a fresh lifetime")
	old3=entities.get_reference(3); events.clear()
	apply([row(3,6,8,30)],[],true,3,1,2,8)
	check(entities.resolve(old3)==null and entities.get_scope().area_generation==2,"Area generation invalidates every old reference")
	check(events[0].kind=="scope" and events[1].kind=="removed" and events[2].kind=="added","Transition publishes scope before old removals and new additions")
	check(not entities.get_player_character().available,"Player identity resets across area scopes")
	old3=entities.get_reference(3); apply([row(3,6,8,30)],[],true,3,2,0,8)
	check(entities.resolve(old3)==null,"Reconnect allows a lower generation but invalidates previous connection refs")
	check(not binding.commit(1,9,8,{"objects":[],"bridgeMode":"full"}),"Older connection cannot overwrite the accepted scope")
	check(not binding.commit(2,0-1,8,{"objects":[],"bridgeMode":"full"}),"Invalid generation is rejected")
	check(not binding.commit(2,1,8,{"objects":[],"bridgeMode":"delta"}),"A changed scope requires a complete publication")
	old3=entities.get_reference(3); var before_lifetime: int=entities.diagnostics().next_lifetime; var before_scope: int=entities.get_scope().scope_id
	binding.reset(); apply([row(3,6,8,30)],[],true,3,2,0,8)
	check(entities.resolve(old3)==null and entities.get_reference(3).lifetime>=before_lifetime and entities.get_scope().scope_id>before_scope,"Reset/rejoin with identical numeric scope never resets lifetime or scope counters")
	var second_api: Node=API.new(); root.add_child(second_api)
	check(second_api.entities.resolve(entities.get_reference(3))==null,"References never cross API instances")
	second_api.free()
	var bare:={"id":21}; apply([bare],[],true,null,2,1,8)
	snapshot=entities.get_by_id(21)
	check(not snapshot.identity.object_type.available and snapshot.identity.object_type.value==null and snapshot.identity.type_name==null,"Missing type is explicit, never coerced to zero")
	check(not snapshot.character.available and snapshot.character.value==null and not snapshot.replicated.available and not snapshot.appearance.available,"Missing character/replication/appearance fields are explicit")
	var bare_ref: Dictionary=entities.get_reference(21); apply([bare],[],false,null,2,1,8)
	check(entities.resolve(bare_ref)==null,"Sources without identity tokens conservatively retire references on every publication")
	var unsafe_node:=Node.new(); var resource:=Resource.new(); var bytes:=PackedByteArray([1,2])
	var unsafe:=row(22); unsafe.extra={"node":unsafe_node,"resource":resource,"callback":func():return 1,"bytes":bytes,"nested":[{"resource":resource}]}
	apply([unsafe],[],false,null,2,1,8); snapshot=entities.get_by_id(22)
	check(snapshot.received.value.extra.node==null and snapshot.received.value.extra.resource==null and snapshot.received.value.extra.callback==null and snapshot.received.value.extra.nested[0].resource==null,"Nested Nodes/Resources/Callables never escape in data views")
	check(snapshot.unavailable_paths.size()==4,"Unsupported live values report explicit unavailable paths")
	snapshot.received.value.extra.bytes[0]=99
	check(bytes[0]==1,"Packed arrays are detached ordinary arrays")
	unsafe_node.free()
	var cyclic: Array=[]; cyclic.append(cyclic); var missing: Array=[]; var copied: Array=Detached.copy(cyclic,missing)
	check(copied[0]==null and missing.size()==1,"Cyclic source containers terminate with explicit missing paths")
	cyclic.clear()
	events.clear(); metrics=entities.diagnostics()
	check(binding.presentation_records(2,1,8,[{"id":22,"revision":2},{"id":22,"revision":2},{"id":999,"revision":2}]),"Accepted bounded movement publication")
	check(events.size()==1 and events[0].event.source=="presentation_input","Movement signals deduplicate known touched IDs")
	check(entities.diagnostics().source_rows==metrics.source_rows and entities.diagnostics().full_removal_visits==metrics.full_removal_visits,"Movement publication does not scan/copy raw world state")
	binding.presentation_records(2,1,8,[{"id":22,"revision":2},{"id":22,"revision":1}])
	check(events.size()==1,"Duplicate and stale movement revisions cannot publish false entity updates")
	check(not binding.presentation_records(1,1,8,[{"id":22,"revision":3}]),"Stale movement scope is rejected")
	var event: Dictionary=events[0].event
	check(event.is_read_only() and event.reference.is_read_only(),"Event dictionaries and nested references are immutable between listeners")
	var saved_event: Dictionary=Detached.copy(event); binding.reset()
	check(event==saved_event and entities.resolve(event.reference)==null,"Retained events are detached from subsequent lifecycle updates")
	check(entities.list_entities().is_empty() and not entities.get_scope().active,"Reset clears known identities and publishes inactive scope")
	var report:={"success":failures.is_empty(),"checks":checks,"failures":failures,"diagnostics":entities.diagnostics(),"scope":"Isolated native API/provider fixtures; complete and delta owner boundaries, detached data, lifetimes and event ordering. No server, renderer, native rebuild or live-client acceptance."}
	var report_path:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): report_path=arg.trim_prefix("--report=")
	if not report_path.is_empty():
		var file:=FileAccess.open(report_path,FileAccess.WRITE)
		if file!=null: file.store_string(JSON.stringify(report,"  ")+"\n"); file.close()
	print("ENTITY_API_RESULT ",JSON.stringify(report))
	api.free(); quit(0 if failures.is_empty() else 1)
