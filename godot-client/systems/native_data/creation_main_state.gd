extends RefCounted
# Original CCharacterGenerationPanel8ec740/8e9be0/8e6780. UI completion and
# callback routing only; live drafts and all rule queries belong to the caller.
const TAGS=["align","abilities","class","customize","play","packages","portrait","race","gender"]
const Game=preload("res://systems/native_data/game_ui_rules.gd")
var enabled: Dictionary={}
var completed: Dictionary={}
var encouraged: Dictionary={}
var recommended:=""
var summary_mask:=0
var alignment: Array=[0,0]
var calls: Array=[]
func initialize() -> void:
	for tag in TAGS: enabled[tag]=tag=="gender"; completed[tag]=false; encouraged[tag]=tag=="gender"
	recommended="gender"; summary_mask=0; alignment=[0,0]; calls=[]
func load_state(value: Dictionary) -> void:
	enabled=value.enabled.duplicate(); completed=value.completed.duplicate(); encouraged=value.encouraged.duplicate(); recommended=str(value.recommended); summary_mask=int(value.summaryMask); alignment=[0,0]; calls=[]
static func paladin_rule_default(classes: Array) -> bool:
	if classes.size()<=6 or not classes[6] is Dictionary: return false
	var row: Dictionary=classes[6]
	return (Game.number(Game.cell(row,"AlignRestrict"),-1)&255)==21 and (Game.number(Game.cell(row,"AlignRstrctType"),-1)&255)==3 and Game.number(Game.cell(row,"InvertRestrict"),-1)==0
func encourage(tag: String) -> void:
	if not recommended.is_empty():
		if enabled[recommended] and not completed[recommended]: return
		encouraged[recommended]=false
	recommended=tag; encouraged[tag]=true
func invalidate(tags: Array) -> void:
	for tag in tags: enabled[tag]=false; completed[tag]=false
func reset_derived() -> void:
	if enabled.packages: calls.append("reset_derived")
func reset() -> void:
	calls=[]; invalidate(["align","abilities","class","customize","play","packages","portrait","race"]); enabled.gender=true
	for tag in TAGS: completed[tag]=false
	summary_mask=0; calls=["retire_draft","initialize_draft","refresh"]
func result(code: int,context: Dictionary) -> void:
	calls=[]
	code&=0xffffffff
	if code>=0x80000000: code-=0x100000000
	if code==-2147483646: return
	if int(context.get("customizeMode",0))!=0:
		if code==2: calls=["deactivate:2","delete"]; return
		if code==0x8007: calls=["finish"]; return
		if code==0x8009: calls=["appearance"]; return
	match code:
		0x8001,0x8003:
			reset_derived(); summary_mask|=16 if code==0x8001 else 8; calls.append("refresh")
			var from: String="align" if code==0x8001 else "abilities"; var target: String="abilities" if code==0x8001 else "packages"
			encouraged[from]=false; completed[from]=true
			invalidate(["abilities","packages","customize","play"] if code==0x8001 else ["packages","customize","play"])
			enabled[target]=true; encourage(target)
		3:
			calls.append("refresh"); completed.packages=false; enabled.customize=false; completed.customize=false
		0x8004:
			reset_derived(); summary_mask|=4; calls.append("refresh"); encouraged["class"]=false; completed["class"]=true
			invalidate(["align","abilities","packages","customize","play"])
			if not context.get("present",true): return
			if int(context.get("classBase",-1))==6 and context.get("paladinRuleDefault",false):
				alignment=[85,85]; enabled.align=true; enabled.abilities=true; encourage("abilities"); encouraged.align=false; completed.align=true; calls.append("refresh")
			else: enabled.align=true; encourage("align")
		0x8007:
			summary_mask|=1; calls.append("refresh"); encouraged.customize=false; completed.customize=true; enabled.play=true; encourage("play")
		0x8008,0x800e:
			calls.append("refresh"); encouraged.packages=false; completed.packages=true; enabled.customize=true; encourage("customize")
		0x8009:
			calls.append("refresh"); encouraged.portrait=false; completed.portrait=true
			var target: String="customize" if int(context.get("appMode",0))!=0 else "class"
			enabled[target]=true; encourage(target)
		0x800a:
			reset_derived(); summary_mask|=2; calls.append("refresh"); encouraged.race=false; completed.race=true
			invalidate(["class","align","abilities","packages","customize","play"]); enabled.portrait=true; encourage("portrait")
		0x800d,0x8017:
			if code==0x8017 and completed.portrait: calls.append("portrait")
			calls.append("refresh"); encouraged.gender=false; completed.gender=true; enabled.race=true; encourage("race")
		_: calls.append("refresh")
func snapshot() -> Dictionary:
	return {"enabled":enabled.duplicate(),"completed":completed.duplicate(),"encouraged":encouraged.duplicate(),"recommended":recommended,"summaryMask":summary_mask,"alignment":alignment.duplicate(),"calls":calls.duplicate()}
