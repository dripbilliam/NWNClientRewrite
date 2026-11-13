extends RefCounted
# Original mode1 child order. The caller owns private values, rule preparation
# and the typed server transaction; this cursor never writes an actor/send ACK.
const Post=preload("res://systems/native_data/creation_post_feats.gd")
const Tables=preload("res://systems/native_data/creation_feat_tables.gd")
const Vitals=preload("res://systems/native_data/level_up_vitals.gd")
var post:=Post.new()
var scope: Array=[]
var ticket: Array=[]
var serial:=0
var stage:=""
var class_id:=-1
var class_level:=0
var total_level:=0
var wanted:=false
var submitted:=false
var result_received:=false
func result(ready: bool=true,reason: String="") -> Dictionary:return {"ready":ready,"reason":reason,"stage":stage,"ticket":ticket.duplicate(),"submitted":submitted}
func enter(value: String) -> Dictionary:
	stage=value;serial+=1;ticket=scope+[serial,stage];return result()
func begin(identity: Array) -> Dictionary:
	close();scope=identity.duplicate();wanted=not scope.is_empty();submitted=false;result_received=false
	return enter("class") if wanted else result(false,"Private level-up identity is unavailable.")
func owns(value: Array,expected: String) -> bool:return wanted and stage==expected and ticket==value and not ticket.is_empty()
func after_class(value: Array,advanced: Dictionary) -> Dictionary:
	if not owns(value,"class"):return result(false,"Retired level-up class callback.")
	if not advanced.get("ready",false) or not advanced.get("classes") is Array or not Vitals.Class.integer(advanced.get("current"),0,7) or int(advanced.current)>=advanced.classes.size() or not Vitals.Class.integer(advanced.get("level"),1,2040):return result(false,"Private advanced class source is unavailable.")
	var cls: Variant=advanced.classes[int(advanced.current)]
	if not cls is Dictionary or not Vitals.Class.integer(cls.get("id"),0,254) or not Vitals.Class.integer(cls.get("level"),1,255):return result(false,"Private current class is malformed.")
	class_id=int(cls.id);class_level=int(cls.level);total_level=int(advanced.level)
	return enter("attributes" if (total_level&255)%4==0 else "skills")
func after_attributes(value: Array,selected: int) -> Dictionary:
	if not owns(value,"attributes"):return result(false,"Retired level-up attribute callback.")
	if selected<0 or selected>5:return result(false,"Spend the original one ability increase.")
	return enter("skills")
func after_skills(value: Array,slots: Dictionary,tables: Dictionary) -> Dictionary:
	if not owns(value,"skills"):return result(false,"Retired level-up skill callback.")
	if not Vitals.Class.integer(slots.get("normal"),0,255) or not Vitals.Class.integer(slots.get("bonus"),0,255):return result(false,"Original mode1 feat counters are unavailable.")
	if int(slots.normal)!=0 or int(slots.bonus)!=0:return enter("feats")
	return continue_post(tables)
func after_feats(value: Array,valid: Dictionary,tables: Dictionary) -> Dictionary:
	if not owns(value,"feats"):return result(false,"Retired level-up feat callback.")
	if not valid.get("ready",false) or not valid.get("valid",false):return result(false,"Private feat choices are incomplete or unavailable.")
	return continue_post(tables)
func post_source(tables: Dictionary) -> Dictionary:
	var table: Dictionary=tables.get("classes",{});var source:={"present":true,"mode":1,"level":class_level}
	if class_id<0 or class_id>=(table.get("orderedRows",[]).size()&255):return {}
	for field in ["PickDomains","PickSchool","SpellbookRestricted","SkipSpellSelection","MinAssociateLevel","Arcane"]:
		var read:=Tables.integer(table,class_id,field)
		if read.ready and read.ok:source[field]=(int(read.value)&255) if field=="MinAssociateLevel" else int(read.value) if field=="Arcane" else int(int(read.value)!=0)
	return source
func continue_post(tables: Dictionary) -> Dictionary:
	var next:=post.advance(post_source(tables),0x8010)
	if not next.ready:
		if stage!="post":enter("post")
		return result(false,"Active mode1 child metadata is unavailable: "+str(next.get("field","")))
	return enter(str(next.child) if next.activated else "summary")
func after_child(value: Array,tables: Dictionary) -> Dictionary:
	if stage not in ["domains","school","spells","associate"] or not owns(value,stage):return result(false,"Retired level-up child callback.")
	return continue_post(tables)
func retry_post(value: Array,tables: Dictionary) -> Dictionary:
	return continue_post(tables) if owns(value,"post") else result(false,"Retired level-up preparation callback.")
func submit(value: Array) -> Dictionary:
	if not owns(value,"summary") or submitted:return {"send":false,"serverAcknowledged":false}
	submitted=true;return {"send":true,"serverAcknowledged":false,"ticket":ticket.duplicate()}
func cancel(value: Array) -> Dictionary:
	if not wanted or value!=ticket:return {"cancel":false}
	var pending:=submitted and not result_received;close();return {"cancel":true,"submissionPending":pending,"serverAcknowledged":false}
func close() -> void:
	wanted=false;scope=[];ticket=[];stage="";class_id=-1;class_level=0;total_level=0;result_received=false;serial+=1;post.reset()
