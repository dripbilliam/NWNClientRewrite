extends SceneTree
const Snapshot=preload("res://systems/native_data/level_up_feat_snapshot.gd")
const State=preload("res://systems/native_data/level_up_feat_state.gd")
const Capacity=preload("res://systems/native_data/level_up_feat_capacity.gd")
const SpellsSnapshot=preload("res://systems/native_data/level_up_spells_snapshot.gd")
const SpellsState=preload("res://systems/native_data/level_up_spells_state.gd")
class Text extends RefCounted:
	var revision:=0
	func raw(value: Dictionary) -> String:return "Active "+str(int(value.strRef))
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func tables() -> Dictionary:
	var feats: Array=[]
	for at in 8:feats.append({"Feat":str(100+at),"AllClassesCanUse":"1","Icon":"custom_"+str(at)})
	feats[3].MinAttackBonus="31";feats[4].MinFortSave="6";feats[5].PreReqFeat1="2"
	return {"classes":{"orderedRows":[{"FeatsTable":"classfeats","SkillsTable":"classskills","AttackBonusTable":"custombab","BonusFeatsTable":"custombonus"},{"FeatsTable":"otherfeats","SkillsTable":"otherskills","AttackBonusTable":"otherbab"}]},"racialtypes":{"orderedRows":[{"NormalFeatEveryNthLevel":"3","NumberNormalFeatsEveryNthLevel":"2","ConAdjust":"2"}]},"ruleset":{"orderedRows":[]},"skills":{"orderedRows":[{"Untrained":"0","AllClassesCanUse":"1"}]},"feat":{"orderedRows":feats},"classfeats":{"orderedRows":[{"FeatIndex":"2","GrantedOnLevel":"21","List":"3"},{"FeatIndex":"2","GrantedOnLevel":"20","List":"3"},{"FeatIndex":"6","GrantedOnLevel":"20","List":"3"},{"FeatIndex":"7","GrantedOnLevel":"25","List":"3"}]},"classskills":{"orderedRows":[{"SkillIndex":"0"}]},"otherfeats":{"orderedRows":[]},"otherskills":{"orderedRows":[]},"custombab":{"orderedRows":range(60).map(func(_at):return {"BAB":"30"})},"otherbab":{"orderedRows":[{"BAB":"257"}]},"custombonus":{"orderedRows":range(60).map(func(at):return {"Bonus":"1" if at==20 else "0"})}}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not oracle is Dictionary or oracle.get("binarySha256")!="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a" or oracle.get("rows",[]).size()!=52:quit(2);return
	for index in oracle.rows.size():
		var row: Dictionary=oracle.rows[index];var cls_rows: Array=[];var active: Dictionary={}
		for slot in row.case.bonus.size():
			var name:="bab"+str(slot);cls_rows.append({"AttackBonusTable":name});active[name]={"orderedRows":row.case.bonus[slot].map(func(value):return {"BAB":str(int(value))})}
		active.classes={"orderedRows":cls_rows}
		var value:=Snapshot.base_attack(row.case.classes,active)
		if int(row.case.cache)==255:check(value.ready and int(value.value)==int(row.result),"Unchanged original multi-class BYTE BAB sum/level bounds "+str(index))
		else:check(int(row.result)==int(row.case.cache),"Original valid cached BAB remains its distinct pre-invalidation path "+str(index))
	var active:=tables();var received:={"race":0,"classes":[{"id":0,"level":20},{"id":1,"level":1}],"baseAbilities":[12,12,14,14,12,12],"feats":[0,60000],"skills":[1]}
	var before:=received.duplicate(true);var ranks: Array=[3];var context:={"baseFortitude":3}
	var composed:=Snapshot.compose(received,0,2,ranks,active,context)
	check(composed.ready and composed.source.baseAttack==31,"Mode1 recomputes new-level active BAB without creation/min20 approximation")
	check(composed.ready and composed.source.fortitude==6,"Private copied base Fortitude plus new effective CON modifier, without importing class-save table")
	check(composed.source.owned==[0,60000,2] and composed.source.classes[0].level==21,"Exact current-class new-level first-record grant, preserving received IDs/order")
	check(not composed.source.owned.has(6) and not composed.source.owned.has(7),"No retroactive/future class grants or duplicate-record early grant")
	check(composed.source.normal==0 and composed.source.bonus==1 and composed.source.skills[0].rank==3,"Mode1 uses new total/current class slot counters and private skill ranks")
	check(received==before and ranks==[3] and context=={"baseFortitude":3},"Feat projection never writes received snapshot/private caller inputs")
	var wire_received: Dictionary=JSON.parse_string(JSON.stringify(received));wire_received.feats.append(2.0);var wire_before:=wire_received.duplicate(true)
	var wire_private:=Snapshot.compose(wire_received,0,2,ranks,active,context)
	check(wire_private.ready and wire_private.source.owned==[0,60000,2] and wire_private.source.owned.all(func(id):return typeof(id)==TYPE_INT),"Received JSON WORD IDs become detached integer IDs without duplicating an already owned class grant")
	check(wire_private.ready and wire_private.source.owned.has(0) and wire_private.source.owned.has(2),"Private original feat membership sees received numeric IDs")
	wire_private.source.owned.append(7);check(wire_received==wire_before,"Private typed feat storage cannot mutate received JSON arrays")
	for invalid in [null,"2",2.5,-1,65536]:
		var malformed:=wire_received.duplicate(true);malformed.feats.append(invalid);check(not Snapshot.compose(malformed,0,2,ranks,active,context).ready,"Received feat normalization never truncates or invents malformed WORD IDs")
	check(not Snapshot.compose(received,0,2,ranks,active,{}).ready,"Absent received private base-save context remains pending")
	for invalid in [null,128,-129,"3"]:check(not Snapshot.compose(received,0,2,ranks,active,{"baseFortitude":invalid}).ready,"Malformed private base-save context remains pending")
	var failed:=active.duplicate(true);failed.custombab={"orderedRows":[{"BAB":"9"}]}
	check(Snapshot.base_attack([{"id":0,"level":21}],failed).value==0,"Original failed physical BAB read becomes zero, not table DEFAULT")
	failed.custombab={"orderedRows":[{"BAB":"****"}],"defaultValue":"99"}
	check(Snapshot.base_attack([{"id":0,"level":1}],failed).value==0,"Explicit missing BAB read ignores nonzero failure output")
	failed.custombab={"orderedRows":[{"BAB":"0xgarbage"}]}
	check(not Snapshot.base_attack([{"id":0,"level":1}],failed).ready,"Unresolved native hexadecimal conversion remains unavailable")
	var state:=State.new();var text:=Text.new();state.configure(received,0,2,ranks,context)
	# Current-class list2 entries consume the one bonus slot. Their TLK/icon
	# and group model still come through the existing original-backed core.
	active.classfeats.orderedRows.append({"FeatIndex":"3","GrantedOnLevel":"0","List":"2"})
	active.classfeats.orderedRows.append({"FeatIndex":"4","GrantedOnLevel":"0","List":"2"})
	var model:=state.model(active,text)
	check(model.ready and model.available.map(func(row):return int(row.id))==[3,4],"Actual shared feat list core uses mode1 BAB/Fort eligibility and class reservations")
	check(model.available[0].name=="Active 103" and model.available[0].icon=="custom_3","Active custom physical feat ID/TLK/icon remain unchanged")
	model=state.act("add",3,active,text);check(model.ready and state.selected==[3] and model.remaining==0 and state.validate(active,text).valid,"One mode1 bonus selection consumes its real slot and validates")
	var revisions:=text.revision;text.revision+=1;check(state.model(active,text).ready and text.revision==revisions+1,"Active text publication can rebuild mode1 list")
	var replacement:=active.duplicate(true);replacement.custombab.orderedRows[20].BAB="0"
	check(not state.validate(replacement,text).valid,"Replaced active attack table invalidates the selected physical feat")
	state.act("remove",3,active,text);check(state.selected.is_empty() and not state.validate(active,text).valid,"Removing choice restores required bonus selection without changing received feats")
	var spell_active:=active.duplicate(true);spell_active.feat.orderedRows[3].MinSpellLvl="2"
	check(not state.model(spell_active,text).ready,"Missing original mode1 spell-capacity owner cannot silently deny/allow prerequisites")
	state.configure(received,0,2,ranks,context,func(_source,level):return {"ready":true,"allowed":level==2})
	check(state.model(spell_active,text).ready,"Explicit scoped spell-capacity boundary is separate from first-level composition")
	var caster_tables:=active.duplicate(true)
	caster_tables.classes.orderedRows[0].merge({"SpellCaster":"0","StatGainTable":"other_gain","ArcSpellLvlMod":"0","DivSpellLvlMod":"0"},true)
	caster_tables.classes.orderedRows[1].merge({"SpellCaster":"1","MemorizesSpells":"0","SpellbookRestricted":"1","LearnScroll":"0","SpellcastingAbil":"INT","SpellGainTable":"caster_gain","SpellKnownTable":"caster_known","Arcane":"1"},true)
	caster_tables.other_gain={"orderedRows":[{"Int":"4"}]};caster_tables.caster_gain={"orderedRows":[{"NumSpellLevels":"3","SpellLevel0":"2","SpellLevel1":"0","SpellLevel2":"0"}]};caster_tables.caster_known={"orderedRows":[{"SpellLevel0":"2","SpellLevel1":"0","SpellLevel2":"1"}]}
	var caster_received:=received.duplicate(true);caster_received.baseAbilities[3]=11
	var caster_snapshot:=Snapshot.compose(caster_received,0,-1,ranks,caster_tables,context)
	var answer:=Capacity.evaluate(caster_snapshot,2,caster_tables)
	check(answer.ready and not answer.allowed and caster_snapshot.vitals.scores[3]==15,"Nonmemorizing prerequisite uses that caster class's own gain, not other-class bonus/effective cache")
	caster_tables.classes.orderedRows[1].StatGainTable="own_gain";caster_tables.own_gain={"orderedRows":[{"Int":"1"}]}
	caster_snapshot=Snapshot.compose(caster_received,0,-1,ranks,caster_tables,context);answer=Capacity.evaluate(caster_snapshot,2,caster_tables)
	check(answer.ready and answer.allowed,"Current nonmemorizing class's own cumulative gain can meet its original known-spell ability gate")
	caster_tables.classes.orderedRows[1].erase("StatGainTable")
	caster_snapshot=Snapshot.compose(caster_received,0,3,ranks,caster_tables,context);answer=Capacity.evaluate(caster_snapshot,2,caster_tables)
	check(answer.ready and answer.allowed,"Private raw level-up ability selection participates in original per-class capacity")
	caster_tables.classes.orderedRows[1].merge({"MemorizesSpells":"1","PickSchool":"0"},true)
	caster_snapshot=Snapshot.compose(caster_received,0,-1,ranks,caster_tables,context);answer=Capacity.evaluate(caster_snapshot,2,caster_tables)
	check(answer.ready and answer.allowed,"Memorizing branch reuses original getter with complete private multiclass cache and constructor-zero effect bonuses")
	caster_tables.classes.orderedRows[1].PickSchool="1"
	check(not Capacity.evaluate(caster_snapshot,2,caster_tables).ready,"Missing copied school for a school-dependent class remains pending")
	caster_tables.classes.orderedRows[1].PickSchool="0";caster_tables.classes.orderedRows[0].erase("ArcSpellLvlMod")
	check(not Capacity.evaluate(caster_snapshot,2,caster_tables).ready,"Missing prestige metadata cannot silently default to zero advancement")
	caster_tables.classes.orderedRows[0].ArcSpellLvlMod="0"
	caster_tables.classes.orderedRows[1].merge({"PlayerClass":"1","LearnScroll":"1","PickSchool":"1","SpellTableColumn":"ServerCaster"},true)
	caster_tables.spells={"orderedRows":[{"Name":"300","SpellDesc":"400","ServerCaster":"0","School":"A","IconResRef":"server_spell0"},{"Name":"301","SpellDesc":"401","ServerCaster":"1","School":"V","IconResRef":"server_spell1"}]}
	var new_received:=received.duplicate(true);new_received.classes=[{"id":0,"level":20}];new_received.spellbooks={}
	var new_private:=Snapshot.compose(new_received,1,-1,ranks,caster_tables,context)
	var spells:=SpellsSnapshot.compose(new_received,new_private,caster_tables,text)
	check(spells.ready and spells.newClassRecord and spells.source.school==0 and spells.source.known.all(func(book):return book.is_empty()),"Only appended private class uses proven constructor School0/ten empty known lists")
	var choices:=SpellsState.new();check(choices.configure(new_received,new_private,caster_tables,text).ready and choices.state.remaining==7 and choices.state.known[0]==[0],"Original new-class1 scroll initialization receives its private multiclass INT bonus and automatic cantrip")
	var existing:=new_received.duplicate(true);existing.classes.append({"id":1,"level":1})
	caster_tables.caster_gain.orderedRows.append(caster_tables.caster_gain.orderedRows[0].duplicate())
	caster_tables.caster_known.orderedRows.append(caster_tables.caster_known.orderedRows[0].duplicate())
	var existing_private:=Snapshot.compose(existing,1,-1,ranks,caster_tables,context)
	check(not SpellsSnapshot.compose(existing,existing_private,caster_tables,text).ready,"Copied owned class never receives constructor fallback for an absent school")
	existing.classes[1].school=0;existing_private=Snapshot.compose(existing,1,-1,ranks,caster_tables,context)
	check(not SpellsSnapshot.compose(existing,existing_private,caster_tables,text).ready,"Copied owned class never receives invented empty known storage")
	existing.spellbooks={"1":{"known":[1,0]}};spells=SpellsSnapshot.compose(existing,existing_private,caster_tables,text)
	check(spells.ready and not spells.newClassRecord and spells.source.classLevel==2 and spells.source.known==[[0],[1],[],[],[],[],[],[],[],[]],"Existing mode1 book groups copied physical IDs with active custom class spell levels")
	check(received==before,"Shared chooser operations preserve all received snapshot fields")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalBabCases":52,"gpu":false,"serverConnections":0,"runtimeIntegrated":false,"scope":"Unchanged original BAB getter differential plus private mode1 feat adapter/list/selection under controlled active rules; no integrated controls, producer/save, server or pixels."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
