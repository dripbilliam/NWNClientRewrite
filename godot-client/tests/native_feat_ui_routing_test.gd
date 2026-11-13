extends SceneTree
const Desktop=preload("res://systems/native_game_desktop.gd")
const Radial=preload("res://systems/server_radial.gd")
const Feats=preload("res://systems/native_data/feat_radial.gd")
class Text extends RefCounted:
	var tables: Dictionary={}
	func raw(value: Dictionary) -> String: return "TLK "+str(int(value.get("strRef",-1)))
	func name(_value: Variant,_id: int) -> String: return "Authored actor"
class Ui extends RefCounted:
	var text:=Text.new()
	var tables_ready:=true
	var hud_ready:=false
	var inventory:=Inventory.new()
class Inventory extends RefCounted:
	var item_context:=ItemContext.new()
class ItemContext extends RefCounted:
	func cancel() -> void:pass
class Art extends Node:
	func bind(_target: Object,_resource: String,_property: String="texture",_model: bool=false,_clip: String="up",_portrait: bool=false) -> void: pass
	func close() -> void: pass
var checks:=0
var failures: Array=[]
var sent: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func feat_rows() -> Array:
	var rows: Array=[]; rows.resize(40); rows.fill({})
	for id in [2,5,17,23,28,39]: rows[id]={"FEAT":1000+id,"Label":"Feat"+str(id),"ICON":"feat"+str(id),"UsesPerDay":1 if id in [2,39] else 0,"SUCCESSOR":-1,"SpellId":0 if id==2 else -1,"TargetSelf":0}
	rows[28].TargetSelf=1
	return rows
func open_ability(desktop,target: int) -> void:
	desktop.open_radial({"id":target,"position":Vector3(1,0,2)},Vector2(600,350)); desktop.radial.choose(6)
	for index in desktop.radial_entries:
		if desktop.radial_entries[index].get("menu",{}).get("kind","")=="class-abilities":desktop.radial.choose(int(index));break
	var slot:=-1
	for index in desktop.radial_entries:
		if desktop.radial_entries[index].has("children") and desktop.radial_entries[index].label=="TLK 1002": slot=int(index); break
	check(slot>=0,"Server-defined family is offered by the live ability menu")
	if slot>=0: desktop.radial.choose(slot)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var desktop:=Desktop.new(); root.add_child(desktop); desktop.actor_id=99; desktop.area_id=42; desktop.generation=1; desktop.owner_ui=Ui.new(); desktop.rules.text=desktop.owner_ui.text; desktop.feat_rules.rules=desktop.rules
	desktop.ability_rules.rules=desktop.rules;desktop.ability_rules.feats=desktop.feat_rules;desktop.spell_rules.rules=desktop.rules;desktop.spell_rules.abilities=desktop.ability_rules
	desktop.art=Art.new(); desktop.add_child(desktop.art); desktop.radial=Radial.new(); desktop.add_child(desktop.radial); desktop.radial.request.connect(desktop.input_request)
	desktop.target_prompt=Label.new(); desktop.add_child(desktop.target_prompt); desktop.target_prompt.hide()
	desktop.owner_ui.text.tables={"feat":{"orderedRows":feat_rows()},"spells":{"orderedRows":[{"Name":2000,"SubRadSpell1":99,"SubRadSpell2":1},{"Name":2001,"FeatID":Feats.signed32((65001<<16)|25),"IconResRef":"server_child","TargetType":1}]},"skills":{"orderedRows":[]}}
	desktop.objects={99:{"id":99,"objectType":5,"replicated":{},"playerState":{"feats":[2,5,17,23,28,39],"featUses":{"2":3,"39":2}}},100:{"id":100,"objectType":5,"replicated":{}}}
	desktop.owner_ui.text.tables.classes={"orderedRows":[{"Name":3000,"FeatsTable":"fixture_feats"}]};desktop.owner_ui.text.tables.fixture_feats={"orderedRows":[{"FeatIndex":2,"OnMenu":1},{"FeatIndex":5,"OnMenu":1}]};desktop.objects[99].replicated.stats={"classes":[{"id":0,"level":1}]}
	desktop.request.connect(func(message):sent.append(message))
	open_ability(desktop,100)
	check(desktop.radial_entries.has(1) and not desktop.radial_entries.has(0),"Live family retains a physical missing-child hole")
	desktop.radial.choose(1)
	check(sent.size()==1 and sent[-1].kind=="native-feat" and sent[-1].featId==2 and sent[-1].auxiliary==65001 and sent[-1].targetId==100,"Actual native menu dispatches parent feat and variant WORD to the selected target")
	check(desktop.objects[99].playerState.featUses["2"]==3,"Menu routing never spends authoritative uses locally")
	desktop.owner_ui.text.tables.feat.orderedRows[2].TargetSelf=1; open_ability(desktop,99); desktop.radial.choose(1)
	check(sent.size()==2 and sent[-1].featId==2 and sent[-1].auxiliary==65001 and sent[-1].targetId==99 and desktop.target.is_empty(),"Self-target family retains its auxiliary and dispatches directly to self")
	open_ability(desktop,100)
	check(desktop.radial_entries[1].disabled,"Received target-self metadata disables a family leaf on another creature")
	desktop.radial.choose(1); check(sent.size()==2,"A disabled family leaf cannot dispatch a native request")
	desktop.quick_bindings=[]
	for index in 36:desktop.quick_bindings.append({"type":0})
	desktop.objects[99].playerState.featUses["2"]=0; desktop.shortcut_menu(4,Vector2(600,350)); desktop.radial.choose(6)
	for slot in desktop.radial_entries:
		if desktop.radial_entries[slot].get("menu",{}).get("kind","")=="class-abilities":desktop.radial.choose(int(slot));break
	var family:=-1
	for slot in desktop.radial_entries:
		if desktop.radial_entries[slot].label=="TLK 1002": family=int(slot); break
	if family>=0: desktop.radial.choose(family)
	check(family>=0 and desktop.radial_target==99 and not desktop.radial_entries[1].disabled,"Shortcut assignment retires a previous NPC context and allows exhausted feats")
	desktop.radial.choose(1)
	check(sent.size()==3 and sent[-1].kind=="native-quickbar-assign" and int(sent[-1].index)==4 and int(sent[-1].button.intParam)<0 and ((int(sent[-1].button.intParam)>>16)&65535)==65001 and (int(sent[-1].button.intParam)&65535)==2,"Actual assignment serializes the entire variant in the signed native quickbar INT")
	var shortcut: Dictionary=sent[-1].button; var row: Dictionary=desktop.shortcut_row(shortcut)
	check(not row.enabled and row.uses==0 and row.label=="TLK 2001" and row.icon=="server_child","Received variant shortcut shows child art/text and the parent's exhausted use counter")
	desktop.objects[99].playerState.featUses["2"]=3; desktop.activate(shortcut)
	check(sent.size()==4 and sent[-1].kind=="native-feat" and sent[-1].featId==2 and sent[-1].auxiliary==65001 and sent[-1].targetId==99,"Activating a received signed variant shortcut preserves the protocol WORDs")
	desktop.open_radial({"id":99},Vector2(600,350)); desktop.radial.choose(3); desktop.radial.choose(2)
	check(sent.size()==5 and sent[-1].kind=="native-mode" and sent[-1].modeId==3 and desktop.target.is_empty(),"Special-attack power toggle uses native mode input instead of a feat cast")
	desktop.activate(Feats.binding(28)); check(sent.size()==6 and sent[-1].kind=="native-mode" and sent[-1].modeId==3,"The same mode shortcut uses the native mode path")
	desktop.open_radial({"id":100},Vector2(600,350)); desktop.radial.choose(3)
	check(desktop.radial_entries[2].disabled and desktop.radial_entries[0].disabled,"Native special-attack mode and Parry target restrictions are visible")
	desktop.radial.choose(2); check(sent.size()==6,"Unavailable contextual mode does not dispatch or retarget")
	check(desktop.radial_entries.has(4) and (int(desktop.radial_entries[4].binding.intParam)&65535)==17,"Special attack uses the owned improved feat in its original physical slot")
	desktop.radial.choose(1)
	check(sent.size()==7 and sent[-1].kind=="native-feat" and sent[-1].featId==5 and sent[-1].auxiliary==65001 and sent[-1].targetId==100,"Original Called Shot arm entry sends the high-word variant")
	row=desktop.shortcut_row(Feats.binding(5,65000))
	check(row.enabled and row.uses==null and row.icon=="IR_CALLEDLEG" and row.label=="TLK 518","Unlimited Called Shot shortcut retains variant art without a fake100-use count")
	desktop.open_radial({"id":100},Vector2(600,350)); desktop.radial.choose(3); desktop.radial.choose(7)
	check(desktop.radial_entries.has(5) and (int(desktop.radial_entries[5].binding.intParam)&65535)==39,"More Attacks preserves the original Stunning Fist slot")
	desktop.radial.choose(5)
	check(sent.size()==8 and sent[-1].kind=="native-feat" and sent[-1].featId==39 and sent[-1].auxiliary==0,"Stunning Fist sends a real feat request from the special-attack branch")
	desktop.open_radial({"id":99},Vector2(600,350)); desktop.radial.choose(3); desktop.radial.choose(0)
	check(sent.size()==9 and sent[-1].kind=="native-mode" and sent[-1].modeId==2,"Parry sends mode2 rather than a generic skill request")
	desktop.owner_ui.text.tables.feat.orderedRows[28]={}; desktop.activate(Feats.binding(28))
	check(sent.size()==9 and desktop.target.is_empty(),"A mode shortcut requires valid active feat metadata before the hotbar's mode dispatch")
	desktop.close(); desktop.free(); await process_frame; await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored native desktop/menu/shortcut integration to exact outgoing typed requests, physical family holes and live table/use changes. No server result, original-client timing or GPU acceptance."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
