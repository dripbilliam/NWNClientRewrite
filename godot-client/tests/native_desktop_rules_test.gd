extends SceneTree
const GameRules=preload("res://systems/native_data/game_ui_rules.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
const Session=preload("res://native_session_world.gd")
const Text=preload("res://systems/native_data/talk_text.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void: call_deferred("run")
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures.append(label)
func run() -> void:
	var output:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output=arg.substr(9)
	if output.is_empty() or FileAccess.file_exists(output): quit(2); return
	var text:=Text.new(); var rules:=GameRules.new(); rules.text=text
	text.tables={"classes":{"orderedRows":[{"Label":"Wizard","SpellCaster":"1","SpellbookRestricted":"1","MemorizesSpells":"1","SpellTableColumn":"Wiz"}]},"spells":{"orderedRows":[{"Label":"Protection family","Wiz":"1","SubRadSpell1":"1","SubRadSpell2":"2"},{"Label":"Protection good","Wiz":"1","Master":"0"},{"Label":"Protection evil","Wiz":"1","Master":"0"}]},"portraits":{"orderedRows":[{"BaseResRef":"auth_portrait_"}]},"racialtypes":{"orderedRows":[{"Label":"Human"}]},"feat":{"orderedRows":[{"Label":"Feat","FEAT":"0","UsesPerDay":"1"}]},"skills":{"orderedRows":[{"Label":"Skill"}]}}
	var actor:={"id":42,"objectType":5,"replicated":{"name":{"text":"Authored caster"},"portrait":0,"hitPoints":{"current":7,"fieldE8":2,"maximum":12},"stats":{"racialType":0,"classes":[{"id":0,"level":3}]}},"playerState":{"abilities":{"current":[12,11,10,16,10,8]},"feats":[0],"featUses":{"0":3},"spellbooks":{"0":{"known":[0],"slots":{"1":2},"memorized":{"1":[{"spell":0,"ready":true,"metamagic":0},null]}}}},"inventoryStats":{"field94":3000,"skills":[{"index":0,"flag":true,"value":4}]}}
	text.objects={42:actor}
	var party:=rules.party(text.objects,42,[{"id":99},{"id":42}])
	check(party.size()==2 and party[0].self and party[0].health.current==9 and party[0].health.maximum==12,"Party uses received HP/temporary HP and suppresses duplicate self")
	check(not party[1].available,"Missing party members remain unavailable without invented world objects")
	check(rules.portrait(actor)=="po_auth_portrait_l","Portrait derives original table resource naming")
	var sheet:=rules.record(actor,"test")
	check(sheet.abilities[3].score==16 and sheet.abilities[3].modifier==3 and sheet.experience==3000,"Character record derives display values from received state")
	check(sheet.armorClass==null,"Unreceived armor class is unknown, not fabricated")
	check(rules.record_entries(actor,1)[0].value==4 and rules.record_entries(actor,2)[0].id==0,"Skill and feat menus use server lists")
	check(rules.spell_children(0)==[1,2] and rules.spell_children(0,[1])==[2],"Spell families use active SubRadSpell columns and reject ancestor cycles")
	check(rules.spell_uses(actor,1,0)==1,"A family child uses its parent's received prepared spell")
	var book:=rules.spellbook(actor,0,1,0,[0])
	check(book.known.size()==1 and book.known[0].family and not book.known[0].canDrag and book.memory.size()==2,"Family parents cannot be dragged as castable leaf spells; memory slots retain empty entries")
	check(book.family.size()==2 and book.family[0].canDrag and book.family[0].binding.intParam==1,"Child variants carry their own native shortcut spell ID")
	check(book.family[0].uses==1 and book.family[0].canCast,"Family leaf availability follows server preparation")
	actor.playerState.feats.append(11); actor.playerState.spellbooks["0"].memorized["3"]=[{"spell":0,"ready":1,"metamagic":1}]; text.tables.spells.orderedRows[0].MetaMagic="63"
	var empowered:=rules.spellbook(actor,0,3,1)
	check(empowered.metas.size()==2 and empowered.known.size()==1 and empowered.known[0].metamagic==1 and empowered.known[0].uses==1,"Owned metamagic feats expose their original higher-level preparation and integer ready flags")
	check(rules.spell_uses(actor,1,0,1)==1 and rules.meta_cost(1)==2,"Family children use parent preparations at the original metamagic level cost")
	check(rules.flag(1) and rules.flag(true) and not rules.flag(0) and not rules.flag(false),"Wire integer and control boolean flags share explicit native conversion")
	text.tables.domains={"orderedRows":[{"Level_1":"0"}]}; actor.replicated.stats.classes[0].domains=[0]
	var domain_family:=rules.spellbook(actor,0,1,0,[0],true)
	check(domain_family.family[0].domain and domain_family.family[0].binding.domainLevel==1 and domain_family.family[0].uses==1,"Spell family drag choices retain their domain preparation context")
	var result:={"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Authored native UI projection contracts; original art/live gameplay checked separately"}
	text.close(); var file:=FileAccess.open(output,FileAccess.WRITE); file.store_string(JSON.stringify(result,"  ")+"\n"); file.close(); quit(0 if failures.is_empty() else 1)
