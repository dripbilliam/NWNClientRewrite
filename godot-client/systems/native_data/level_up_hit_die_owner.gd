extends RefCounted
# One real Summary entry owns one private die result. The process random
# stream advances even when Summary is cancelled or later preparation fails.
const Roll=preload("res://systems/native_data/level_up_hit_die.gd")
const Vitals=preload("res://systems/native_data/creation_vitals.gd")
const Scalars=preload("res://systems/native_data/level_up_class_state.gd")
const Values=preload("res://systems/native_data/character_record_values.gd")
var scope: Array=[]
var stream
var entry: Array=[]
var plan: Dictionary={}
var receipt: Dictionary={}
var last_serial:=-1
static func pending(reason: String) -> Dictionary:return {"ready":false,"reason":reason}
static func context(snapshot: Dictionary,tables: Dictionary,application: Dictionary) -> Dictionary:
	if not snapshot.get("ready",false) or not tables.has_all(["classes","ruleset"]):return pending("Private finalization class/rule context is unavailable.")
	if not application.get("forceMaximum") is bool or not application.get("hideHitPointGain") is bool:return pending("Received level-up display rules are still being prepared.")
	var source: Dictionary=snapshot.source;var index:=int(source.current)
	if index<0 or index>=source.classes.size():return pending("Private finalization current class is unavailable.")
	var cls: Dictionary=source.classes[index];var owned: Array=source.owned+source.selected;var die: Variant=Vitals.starting_hitdie(int(cls.id),owned,tables)
	if die==null:return pending("Active original hit-die metadata is unavailable.")
	var total:=0
	for value in source.classes:total=(total+int(value.level))&255
	return {"ready":true,"die":int(die),"total":total,"threshold":Values.cfg(tables,"MIN_LEVEL_FOR_MAX_HP",3),"forceMaximum":application.forceMaximum,"hideHitPointGain":application.hideHitPointGain,"classId":int(cls.id)}
func begin(identity: Array,random_stream: RefCounted) -> bool:
	retire()
	if identity.size()!=4 or identity.any(func(value):return not Scalars.integer(value,0,9007199254740991)) or random_stream==null:return false
	scope=identity.duplicate();stream=random_stream;return true
func owns(ticket: Array) -> bool:
	return not scope.is_empty() and ticket.size()==scope.size()+2 and ticket.slice(0,scope.size())==scope and Scalars.integer(ticket[-2],0,9007199254740991) and ticket[-1]=="summary"
func current(ticket: Array,snapshot: Dictionary,tables: Dictionary,application: Dictionary) -> bool:
	return owns(ticket) and ticket==entry and not receipt.is_empty() and receipt.get("ready",false) and context(snapshot,tables,application)==plan
func roll(ticket: Array,snapshot: Dictionary,tables: Dictionary,application: Dictionary) -> Dictionary:
	if not owns(ticket) or stream==null or OS.get_thread_caller_id()!=OS.get_main_thread_id():return pending("Retired native hit-die owner.")
	var prepared:=context(snapshot,tables,application)
	if not prepared.ready:return prepared
	if entry==ticket:return receipt.duplicate(true) if prepared==plan else pending("Active level-up die/display rules changed.")
	if int(ticket[-2])<=last_serial:return pending("Retired native Summary entry.")
	if not stream.initialized:return pending("Native application random state is unavailable.")
	var result:=Roll.roll_byte(int(prepared.die),int(prepared.total),int(prepared.threshold),prepared.forceMaximum,int(stream.state))
	if int(result.get("randomCalls",0))!=0:
		var drawn: Dictionary=stream.take()
		if not drawn.get("ready",false):return drawn
		if drawn.seedAfter!=result.seedAfter:return pending("Native hit-die random sequence changed.")
	if not result.get("ready",false) and int(result.get("randomCalls",0))==0:return result
	entry=ticket.duplicate();last_serial=int(ticket[-2]);plan=prepared.duplicate();receipt=result.duplicate(true);receipt.entry=entry.duplicate();receipt.seedKind=str(stream.seed_kind);receipt.drawCount=int(stream.draws)
	if receipt.get("ready",false):receipt.hitDie=int(receipt.value);receipt.classId=int(prepared.classId);receipt.totalLevel=int(prepared.total)
	return receipt.duplicate(true)
func retire() -> void:
	scope=[];stream=null;entry=[];plan={};receipt={};last_serial=-1
