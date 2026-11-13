extends RefCounted
# One connection/draft-owned first-level CG_SPELLS session. The existing draft
# owns published books; this temporary native chooser owns counters/baseline.
const State=preload("res://systems/native_data/creation_spells_state.gd")
const Snapshot=preload("res://systems/native_data/creation_spells_snapshot.gd")
const Validation=preload("res://systems/native_data/creation_spells_validation.gd")
const Recommendations=preload("res://systems/native_data/creation_spell_recommendations.gd")
const Plan=preload("res://systems/native_data/creation_spell_recommendation_plan.gd")
const Skills=preload("res://systems/native_data/pregame_skills.gd")
const Writer=preload("res://systems/native_data/gff_writer.gd")
var state:=State.new()
var scope: Array=[]
var owner: WeakRef
var text_owner
var text_revision: Variant=null
var table_refs: Dictionary={}
var receipt: Dictionary={}
func begin(rules,text,identity: Array) -> Dictionary:
	close()
	var snapshot:=Snapshot.compose(rules,text)
	if not snapshot.ready:return snapshot
	var result:=state.configure(snapshot.source)
	if not result.ready:return result
	var context:=Validation.signature(rules)
	if context.is_empty() or not rules.draft.get("memorized") is Dictionary:return {"ready":false,"reason":"The first-level native spell draft is incomplete."}
	owner=weakref(rules);scope=identity.duplicate();text_owner=text;text_revision=text.get("revision")
	receipt={"signature":context,"scope":scope.duplicate(),"initialKnown":state.baseline.duplicate(true),"initialMemorized":rules.draft.memorized.duplicate(true),"events":[],"completed":false}
	capture_tables(rules);publish(rules)
	return state.view()
func capture_tables(rules) -> void:
	table_refs={}
	var names: Array=["classes","racialtypes","ruleset","spells","packages","spellschools"]
	for key in ["SpellGainTable","SpellKnownTable"]:
		var name:=Skills.table_name(rules.cls(),key)
		if not name.is_empty():names.append(name)
	var plan:=Plan.compose(rules,state.source)
	if plan.get("name") is String and not plan.name.is_empty():names.append(plan.name)
	names.append_array(plan.get("dependencies",[]))
	for name in names:table_refs[str(name)]=rules.tables.get(str(name))
func current(rules,text,identity: Array) -> bool:
	return state.ready and owner!=null and owner.get_ref()==rules and text_owner==text and scope==identity and not receipt.is_empty() and receipt.signature==Validation.signature(rules)
func ensure(rules,text,identity: Array) -> Dictionary:
	if not current(rules,text,identity):return {"ready":false,"reason":"The native spell chooser belongs to another draft context."}
	var actual:=Validation.books(rules.draft.get("known"))
	if not actual.ready or actual.books!=state.known:return {"ready":false,"reason":"The owned spell book changed outside this native selection."}
	var changed:=false
	for name in table_refs:
		if not is_same(table_refs[name],rules.tables.get(name)):changed=true;break
	if changed:
		var refreshed:=Validation.replay(rules,text,receipt)
		if not refreshed.get("ready",false):return refreshed
		if not refreshed.get("valid",false):return {"ready":false,"reason":str(refreshed.get("reason","Active spell rules changed."))}
		if refreshed.state.known!=actual.books:return {"ready":false,"reason":"Active rule changes require reopening native spell selection."}
		var level:=state.selected_level;state=refreshed.state
		if level>=0 and level<10 and state.tabs[level]:state.show_level(level)
		capture_tables(rules)
	if changed or text_revision!=text.get("revision"):
		var writer:=Writer.new()
		for id in state.definitions:
			var definition: Dictionary=state.definitions[id]
			if definition.has("title"):definition.name=text.raw({"strRef":int(definition.title)&0xffffffff})
			state.name_keys[id]=writer.text(str(definition.get("name","")))
		if not writer.failure.is_empty():return {"ready":false,"reason":writer.failure}
		state.show_level(state.selected_level);text_revision=text.get("revision")
	return {"ready":true}
func read(rules,text,identity: Array) -> Dictionary:
	var result:=ensure(rules,text,identity)
	return state.view() if result.ready else result
func edit(operation: String,id: int,rules,text,identity: Array) -> Dictionary:
	var valid:=ensure(rules,text,identity)
	if not valid.ready:return valid
	var accepted:=false
	if operation=="level":accepted=state.select_level(id)
	elif operation=="add":accepted=state.add(id)
	elif operation=="remove":accepted=state.remove(id)
	elif operation=="reset":accepted=state.reset_choices()
	elif operation=="recommend":
		var plan:=Plan.compose(rules,state.source)
		if not plan.ready:return plan
		var result:=Recommendations.apply(state,plan)
		if not result.ready:return result
		accepted=true
	if not accepted:return {"ready":false,"reason":"The active native spell choice is unavailable."}
	if operation=="reset":receipt.events=[{"operation":"reset"}]
	else:
		var event:={"operation":operation}
		if operation in ["level","add","remove"]:event.id=id
		receipt.events.append(event)
	receipt.completed=false;publish(rules)
	return state.view()
func commit(rules,text,identity: Array) -> Dictionary:
	var valid:=ensure(rules,text,identity)
	if not valid.ready:return valid
	if not state.can_accept():return {"ready":true,"accepted":false,"reason":"Select every available native spell choice."}
	var prepared:=Validation.preparations(rules,state,receipt)
	if not prepared.ready:return prepared
	var memorized: Dictionary={}
	for level in 10:memorized[level]=prepared.books[level].duplicate()
	rules.draft.memorized=memorized;receipt.completed=true;publish(rules)
	var check:=Validation.verify(rules,text,receipt)
	if not check.get("ready",false) or not check.get("valid",false):receipt.completed=false;publish(rules);return check
	return {"ready":true,"accepted":true,"code":0x8011}
func publish(rules) -> void:
	var books: Dictionary={}
	for level in 10:books[level]=state.known[level].duplicate()
	rules.draft.known=books;rules.draft.sourceSpellChoices=true
	rules.creation_spell_selection=receipt.duplicate(true);rules.creation_spell_text=text_owner
func close() -> void:
	state=State.new();scope=[];owner=null;text_owner=null;text_revision=null;table_refs={};receipt={}
