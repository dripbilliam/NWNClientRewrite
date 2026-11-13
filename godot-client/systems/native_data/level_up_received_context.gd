extends RefCounted
# Staged only. Read the opaque received actor shape; never compute a save or
# update a canonical snapshot. Offers a local explicit retry, never a packet.
const Scalar=preload("res://systems/native_data/level_up_class_state.gd")
var armed:=false
var ready:=false
var edited:=false
var matched:=false
var identity: Array=[]
var token:=-1
var menu_serial:=-1
var native_lifetime: Variant=null
var known_lifetime: Variant=null
var original: Dictionary={}
var latest: Variant=null
var reason:=""
static func pending(message: String) -> Dictionary:return {"ready":false,"reason":message}
static func native_true(value: Variant) -> bool:
	# NativeMessageReader.readBool preserves its one-bit wire value as0/1;
	# Godot JSON materializes it as a number. Authored bools remain supported.
	return value if value is bool else Scalar.integer(value,0,1) and value==1
static func fortitude(actor: Dictionary) -> Variant:
	var stats: Variant=actor.get("inventoryStats");var value: Variant=stats.get("field9c") if stats is Dictionary else null
	return int(value) if Scalar.integer(value,-128,127) else null
static func snapshot(actor: Dictionary) -> Dictionary:
	# Exact serialized shape of networkLevelUpSnapshot: omitted undefined keys
	# remain omitted; explicit nulls remain null; levelUp spreads last.
	var player: Variant=actor.get("playerState");var stats: Variant=actor.get("replicated",{}).get("stats") if actor.get("replicated") is Dictionary else null
	if not player is Dictionary or not stats is Dictionary or not player.get("combat") is Dictionary or not native_true(player.combat.get("canLevelUp")) or not player.get("levelUp") is Dictionary or not stats.get("classes") is Array or stats.classes.is_empty():return pending("Received level-up comparison fields are unavailable.")
	var base: Variant=actor.get("clientAbilityCache",{}).get("base") if actor.get("clientAbilityCache") is Dictionary else null
	if base==null:base=player.get("abilities",{}).get("base") if player.get("abilities") is Dictionary else null
	if not base is Array or base.size()!=6 or base.any(func(value):return not Scalar.integer(value,-9007199254740991,9007199254740991)):return pending("Received base ability storage is unavailable.")
	var feats: Variant=player.get("feats");var books: Variant=player.get("spellbooks")
	if feats!=null and not feats is Array:return pending("Received feat storage is malformed.")
	if books!=null and not books is Dictionary:return pending("Received spellbook storage is malformed.")
	var value:={"classes":stats.classes.duplicate(true),"baseAbilities":base.duplicate(),"feats":feats.duplicate(true) if feats is Array else [],"spellbooks":books.duplicate(true) if books is Dictionary else {}}
	if actor.has("id"):value.actorId=actor.id
	for pair in [["racialType","race"],["fieldDE4","goodEvil"],["fieldDE6","lawChaos"]]:
		if stats.has(pair[0]):value[pair[1]]=stats[pair[0]]
	value.merge(player.levelUp.duplicate(true),true)
	return {"ready":true,"value":value}
static func actor_valid(actor: Dictionary,scope: Array) -> bool:
	if scope.size()!=3 or not Scalar.integer(scope[0],0,9007199254740991) or not Scalar.integer(scope[1],0,4294967295) or not Scalar.integer(scope[2],0,4294967295):return false
	return Scalar.integer(actor.get("id"),0,4294967295) and Scalar.integer(actor.get("areaId"),0,4294967295) and Scalar.integer(actor.get("objectType"),0,255) and actor.id==scope[2] and actor.areaId==scope[1] and actor.objectType==5 and actor.get("replicationRemoved",false) is bool and not actor.get("replicationRemoved",false) and Scalar.integer(actor.get("nativeLifetime"),1,9007199254740991) and Scalar.integer(actor.get("clientKnownLifetime"),1,9007199254740991)
func capture(begin: Dictionary,scope: Array,serial: int,actor: Dictionary) -> Dictionary:
	if armed and identity==scope and menu_serial==serial and token==begin.get("token"):return pending("This draft already has a received-context candidate.")
	close()
	if not Scalar.integer(begin.get("token"),0,9007199254740991) or not begin.get("snapshot") is Dictionary or not actor_valid(actor,scope) or begin.snapshot.get("actorId")!=scope[2]:return pending("Level-up context identity is unavailable.")
	var context: Variant=begin.get("draftContext")
	if not context is Dictionary or not context.has("baseFortitude") or context.baseFortitude!=null:return pending("The begin result does not have missing received Fortitude.")
	# Initially exclude the ambiguous already-present path. This candidate
	# proves an absent→received value in the same native/disclosure lifetime.
	if fortitude(actor)!=null:return pending("Received metadata ordering requires a fresh begin result.")
	armed=true;identity=scope.duplicate();token=int(begin.token);menu_serial=serial;native_lifetime=actor.nativeLifetime;known_lifetime=actor.clientKnownLifetime;original=begin.duplicate(true)
	var current:=snapshot(actor);matched=current.ready and current.value==original.snapshot
	reason="Waiting for received level-up context.";return {"ready":false,"armed":true,"reason":reason}
func observe(scope: Array,current_token: int,serial: int,actor: Dictionary,user_edited: bool,waiting: bool,submitted: bool) -> Dictionary:
	ready=false
	if not armed:return pending("No received-context retry is active.")
	if identity!=scope or token!=current_token or menu_serial!=serial or not actor_valid(actor,scope) or native_lifetime!=actor.nativeLifetime or known_lifetime!=actor.clientKnownLifetime:
		close();return pending("The level-up context lifetime retired.")
	if user_edited:edited=true
	if edited:return pending("Existing choices must be preserved.")
	if submitted:close();return pending("A level-up proposal was already sent.")
	if waiting:return pending("A level-up operation is pending.")
	var value: Variant=fortitude(actor)
	if value==null:return pending("Received Fortitude is unavailable.")
	var current:=snapshot(actor)
	if not current.ready:
		if matched:close()
		return current
	if current.value!=original.snapshot:
		if matched:close();return pending("The received level-up comparison changed.")
		return pending("Waiting for the matching received level-up row.")
	matched=true;ready=true;latest=int(value);return {"ready":true,"action":"Reload choices","serverAcknowledged":false,"sends":0}
func retry(scope: Array,current_token: int,serial: int,actor: Dictionary,user_edited: bool,waiting: bool,submitted: bool) -> Dictionary:
	var admitted:=observe(scope,current_token,serial,actor,user_edited,waiting,submitted)
	if not admitted.ready:return admitted
	var value:=original.duplicate(true);value.draftContext.baseFortitude=int(latest)
	close();return {"ready":true,"result":value,"serverAcknowledged":false,"sends":0}
func close() -> void:
	armed=false;ready=false;edited=false;matched=false;identity=[];token=-1;menu_serial=-1;native_lifetime=null;known_lifetime=null;original={};latest=null;reason=""
