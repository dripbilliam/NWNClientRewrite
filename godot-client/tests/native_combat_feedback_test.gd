extends SceneTree
const Feedback=preload("res://systems/native_data/combat_feedback.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Queue=preload("res://systems/server_action_queue.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var text:=Text.new(); var feedback:=Feedback.new(); feedback.text=text; feedback.controlled=42
	text.objects={42:{"objectType":5,"replicated":{"name":{"text":"Caster"}}},43:{"objectType":5,"replicated":{"name":{"text":"Target"}}}}
	text.custom_tokens={0:"persisted server token",99:"unrelated"}
	text.tables={"spells":{"orderedRows":[{"Name":"9000","AltMessage":"0","IconResRef":"spell_icon"},{"Name":"9001","AltMessage":"9002"}]},"baseitems":{"orderedRows":[{"Name":"9003"}]},"actions":{"orderedRows":[{"STRING_REF":"9010","ICONRESREF":"ir_test"}]},"damagetypes":{"orderedRows":[{"DamageTypeGroup":"0"},{"DamageTypeGroup":"1"},{"DamageTypeGroup":"0"}]},"damagetypegroups":{"orderedRows":[{"ColorR":"255","ColorG":"1","ColorB":"1","FeedbackStrref":"9011"},{"ColorR":"1","ColorG":"255","ColorB":"1","FeedbackStrref":"9012"}]}}
	text.overrides={9000:"Light",9001:"Alternate",9002:"<CUSTOM0> transforms",9003:"Potion",8127:"casts",1501:"uses",63264:"activates",1502:"an unknown spell",63265:"an unidentified <CUSTOM0>",10482:"<CUSTOM0> <CUSTOM1> <CUSTOM2>",53174:"<CUSTOM0> initiative <CUSTOM1> (<CUSTOM2> <CUSTOM3> <CUSTOM4> = <CUSTOM5>)",511:"hit",10470:"<CUSTOM0> attacks <CUSTOM1>: <CUSTOM2> (<CUSTOM3> <CUSTOM4> <CUSTOM5> = <CUSTOM6>)",10466:"<CUSTOM0> damages <CUSTOM1>: <CUSTOM2>",9010:"Authored action",9011:"<CUSTOM0> physical",9012:"<CUSTOM0> fire",8289:"Server report <CUSTOM0>",8349:"Unknown"}
	var spell:={"kind":"spell-feedback","sourceId":42,"spellId":0,"casting":1,"identified":1,"hasItem":0,"itemName":{}}
	var rows:=feedback.format(spell)
	check(rows.size()==1 and rows[0].text=="Caster casts Light","Casting uses original TLK template and server spell ID")
	check(rows[0].rich.spans.any(func(span):return span.color=="#99ffff"),"Self name retains the original feedback color")
	check(text.custom_tokens[0]=="persisted server token" and text.custom_tokens[99]=="unrelated","Per-message template tokens preserve server custom tokens")
	spell.identified=0; rows=feedback.format(spell); check(rows[0].text=="Caster casts an unknown spell","Unidentified spell feedback does not disclose its name")
	spell.hasItem=1; spell.baseItem=0; rows=feedback.format(spell); check(rows[0].text=="Caster activates an unidentified Potion","Unidentified consumed item uses the packet base type")
	spell.identified=1; spell.itemName={"text":"Named potion"}; rows=feedback.format(spell); check(rows[0].text=="Caster activates Named potion","Consumed item override is read from the server packet")
	spell.spellId=1; rows=feedback.format(spell); check(rows[0].text=="Caster transforms","Alternate spell template receives the source name")
	spell.spellId=999; check(feedback.format(spell).is_empty(),"Missing spell rows do not fabricate feedback")
	rows=feedback.format({"kind":"initiative-feedback","sourceId":42,"roll":12,"modifier":-2}); check(rows[0].text=="Caster initiative 10 (12 - 2 = 10)","Initiative displays the server roll and signed modifier")
	var attack: Dictionary=JSON.parse_string(JSON.stringify({"kind":"attack-feedback","sourceId":42,"targetId":43,"minor":5,"modifier":3,"roll":12,"result":1,"combatMode":0,"offhand":0,"sneakAttack":0,"deathAttack":0,"specialMinus534":0,"coupDeGrace":0,"threatened":0,"debug":null}))
	rows=feedback.format(attack); check(rows[0].text=="Caster attacks Target: hit (12 + 3 = 15)","Attack displays the received result and original TLK tokens")
	text.overrides[61953]="Confirmation <CUSTOM0>"; text.overrides[62337]="Concealment <CUSTOM0>%"; text.overrides[10470]+=" <CUSTOM7>"
	attack.threatened=1; attack.confirmation=14.0; attack.result=8; attack.concealmentChance=50.0
	var before:=attack.duplicate(true); rows=feedback.format(attack)
	check(rows[0].text=="Caster attacks Target: Concealment 50% (12 + 3 = 15) Confirmation 14 + 3 = 17" and attack==before,"JSON-float roll, concealment and confirmation tokens are whole numbers without changing combat data")
	rows=feedback.format({"kind":"damage-feedback","sourceId":42,"targetId":43,"damage":[3,4,2],"debug":null})
	check(rows[0].text=="Caster damages Target: 9 (5 physical 4 fire)","Damage groups and total follow original active tables")
	check(feedback.floating.size()==2 and feedback.floating[0].rich.text=="5" and feedback.floating[1].objectId==43,"Grouped damage floats on the server target")
	rows=feedback.format({"kind":"combat-feedback","type":94,"data":{"objects":{"0":42},"strings":{"0":{"text":"Assign a slot"}},"integers":{"0":0}}})
	check(rows.is_empty() and feedback.floating.size()==1 and feedback.floating[0].rich.text=="Assign a slot","Script prompts appear overhead without forced chat history")
	rows=feedback.format({"kind":"combat-feedback","type":94,"data":{"objects":{"0":42},"strings":{"0":{"text":"Visible history"}},"integers":{"0":1}}})
	check(rows[0].text=="Visible history","Script history flag adds the same prompt to chat")
	rows=feedback.format({"kind":"combat-feedback","type":1,"data":{"integers":{"0":17}}}); check(rows[0].text=="Server report 17","Original general feedback descriptor copies numeric tokens")
	var rules:=Rules.new(); rules.text=text; var queue:=rules.queued_actions([{"type":0,"group":7,"widgetSerial":12,"target":43}])
	check(queue.size()==1 and queue[0].label=="Authored action" and queue[0].icon=="ir_test" and queue[0].group==7,"Action description preserves wire IDs and uses original action art/name")
	check(rules.queued_actions([{"type":19,"spell":999,"group":1,"widgetSerial":13}]).is_empty(),"Special spell queue rows with missing metadata remain hidden")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"scope":"Authored native presentation contracts. Real server actions are verified separately.","publicConnections":0}
	text.close(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
