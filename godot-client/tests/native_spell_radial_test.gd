extends SceneTree
const Spell=preload("res://systems/native_data/spell_radial.gd")
const Ability=preload("res://systems/native_data/ability_radial.gd")
const Feats=preload("res://systems/native_data/feat_radial.gd")
const Rules=preload("res://systems/native_data/game_ui_rules.gd")
const Desktop=preload("res://systems/native_game_desktop.gd")
class Text extends RefCounted:
	var tables: Dictionary={}
	func raw(value: Dictionary) -> String: return str(value.get("strRef",""))
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String,actual: Variant=null,expected: Variant=null) -> void:
	checks+=1
	if not ok and failures.size()<15: failures.append({"label":label,"actual":actual,"expected":expected}); print("FAIL: ",label," ",JSON.stringify(actual)," expected ",JSON.stringify(expected))
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for at in a.size():
			if not same(a[at],b[at]): return false
		return true
	return float(a)==float(b) if (a is float or a is int) and (b is float or b is int) else a==b
func expected_entry(row: Dictionary) -> Dictionary:
	var packed:=int(row.packed)
	if row.has("spellId"):
		return {"slot":int(row.slot),"binding":{"type":2,"intParam":int(row.spellId),"classIndex":((packed>>28)&3)|((packed>>36)&4),"metamagic":(packed>>31)&63,"domainLevel":(packed>>24)&15,"spontaneous":(packed>>37)&1},"disabled":row.disabled,"uses":row.uses}
	return {"slot":int(row.slot),"menu":{"kind":"spell-page","classIndex":((packed>>28)&3)|((packed>>36)&4),"metamagic":(packed>>31)&63,"level":(packed>>24)&15,"cursor":packed&65535},"disabled":false}
func project(row: Dictionary) -> Dictionary:
	if row.has("binding"): return {"slot":int(row.slot),"binding":row.binding,"disabled":row.disabled,"uses":row.uses}
	var menu: Dictionary=row.menu.duplicate(); menu.erase("title"); menu.erase("center")
	return {"slot":int(row.slot),"menu":menu,"disabled":false}
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2: args[pair[0]]=pair[1]
	if not args.has("report") or FileAccess.file_exists(args.report): quit(2); return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/native-radial-spell-page-oracle-v3.json"))
	var text:=Text.new(); var rules:=Rules.new(); rules.text=text; var feats:=Feats.new(); feats.rules=rules; var abilities:=Ability.new(); abilities.rules=rules; abilities.feats=feats; var helper:=Spell.new(); helper.rules=rules; helper.abilities=abilities
	check(fixture.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Instruction oracle is pinned to the original executable")
	for at in fixture.cases.size():
		var sample: Dictionary=fixture.cases[at]; var c: Dictionary=sample.case; var spells: Array=c.spells.duplicate(true)
		for id in c.get("denied",[]): spells[int(id)].TargetType=0
		text.tables={"spells":{"orderedRows":spells},"classes":{"orderedRows":[{}, {}, {"Name":55,"Icon":"class","SpellCaster":1,"MemorizesSpells":int(c.get("prepared",true)),"SpellTableColumn":"Custom","CanCastSpontaneously":int(c.get("conversion",false)),"SpellbookRestricted":int(c.get("restricted",false)),"SpellcastingAbil":"CHA","SpellGainTable":"custom_gain"}]}}
		var cls: Array=[]
		for index in maxi(1,int(c.get("index",0))+1): cls.append({"id":2,"level":10})
		var known: Array=[]
		for ids in c.get("known",{}).values(): known.append_array(ids)
		var actor:={"id":99,"objectType":5,"replicated":{"stats":{"classes":cls,"racialType":0}},"clientAbilityCache":{"base":[30,30,30,30,30,30],"current":[30,30,30,30,30,30]},"playerState":{"spellbooks":{str(int(c.get("index",0))):{"memorized":c.get("memory",{}),"known":known,"usesLeft":c.get("usesLeft",{})}}}}
		text.tables.racialtypes={"orderedRows":[{"CHAAdjust":0}]}; text.tables.custom_gain={"orderedRows":[]}
		var gain:={"NumSpellLevels":10}
		for level in 10: gain["SpellLevel"+str(level)]=1
		for level in 40: text.tables.custom_gain.orderedRows.append(gain)
		var ctx:={"actor":actor,"owned":{},"assignment":c.get("assignment",false),"targetBit":1}
		var actual:=helper.page(ctx,int(c.get("index",0)),int(c.get("meta",0)),int(c.get("level",1)),int(c.get("cursor",0))).map(project)
		var expected: Array=sample.entries.map(expected_entry)
		check(same(actual,expected),"Original prepared traversal, physical cursor, uses and packed class/meta fields "+str(at),actual,expected)
	var actor:={"id":99,"objectType":5,"replicated":{"stats":{"classes":[{"id":2,"level":10}]}},"playerState":{}}
	var ctx:={"actor":actor,"owned":{},"assignment":false,"targetBit":1}
	for row in fixture.levels.entries:
		var descriptor: Dictionary=helper.menu(ctx,{"kind":"spell-levels","classIndex":6,"metamagic":32})[int(row.slot)]
		check(descriptor.icon==row.icon and descriptor.label==str(int(row.labelRef)) and int(descriptor.menu.classIndex)==6 and int(descriptor.menu.metamagic)==32,"Original level icon/label/physical slot preserves class index6 and Still "+str(row.slot))
	for ring in fixture.metamagic:
		ctx.owned={}
		for id in ring.case.feats: ctx.owned[int(id)]=true
		var actual:=helper.menu(ctx,{"kind":"spell-meta","classIndex":4})
		check(actual.size()==ring.entries.size(),"Only received normal/bonus metamagic feats create branches")
		for at in actual.size():
			var expected: Dictionary=ring.entries[at]; var packed:=int(expected.packed)
			check(int(actual[at].slot)==int(expected.slot) and actual[at].label==str(int(expected.labelRef)) and actual[at].icon==expected.icon and int(actual[at].menu.metamagic)==((packed>>31)&63),"Original metamagic positions and mask "+str(at))
	# Current server data may define entirely different classes and families.
	var spells: Array=[]
	for id in 16: spells.append({"Name":1000+id,"IconResRef":"spell","Custom":1,"TargetType":1,"MetaMagic":63,"Master":id})
	spells[0].SubRadSpell1=1; spells[0].SubRadSpell2=99; spells[0].SubRadSpell3=2; spells[1].Master=0; spells[2].Master=0; spells[2].TargetType=2
	text.tables={"spells":{"orderedRows":spells},"classes":{"orderedRows":[{"Name":1,"Icon":"class","SpellCaster":1,"SpellTableColumn":"Custom","MemorizesSpells":1,"CanCastSpontaneously":1}]}}
	actor.replicated.stats.classes=[{"id":0,"level":10}]; actor.playerState.spellbooks={"0":{"known":[15],"memorized":{"1":[{"spell":0,"ready":1,"domain":0,"metamagic":0}]}}}; ctx.owned={}; ctx.actor=actor
	var root:=helper.menu(ctx,{"kind":"spell-root"})
	check(root.map(func(row):return row.slot)==[5,6],"A single custom caster occupies its native class slot and exposes spellcasting options")
	ctx.owned={11:true}; root=helper.root(ctx)
	check(root.map(func(row):return row.slot)==[5,7,6],"Owned metamagic adds the native per-class branch")
	helper.always_subradial=true; root=helper.root(ctx)
	check(root.map(func(row):return row.slot)==[4,0,6],"Grouped spell preference keeps native Cast/Metamagic slots")
	var page:=helper.page(ctx,0,0,1)
	check(page.size()==1 and page[0].has("menu") and page[0].menu.kind=="spell-family","Prepared family appears from actual slots, rather than unrelated known spells")
	var family:=helper.menu(ctx,page[0].menu)
	check(family.size()==2 and int(family[0].slot)==0 and int(family[1].slot)==2,"Missing child data retains its physical slot hole")
	check(int(family[0].binding.intParam)==1 and int(family[0].uses)==1 and not family[0].disabled and family[1].disabled,"Child uses and class resource survive while target masks remain distinct",family)
	ctx.assignment=true; family=helper.menu(ctx,page[0].menu)
	check(family.all(func(row):return not row.disabled and row.canDrag),"Shortcut assignment allows each child without issuing a cast")
	ctx.assignment=false; text.tables.classes.orderedRows[0].PickDomains=1; actor.replicated.stats.classes[0].domains=[0]; text.tables.domains={"orderedRows":[{"Level_1":0}]}
	actor.playerState.spellbooks["0"].memorized["2"]=[{"spell":0,"ready":1,"domain":1,"metamagic":2}]
	var domain_page:=helper.page(ctx,0,2,2); var domain_family:=helper.menu(ctx,domain_page[0].menu)
	check(domain_family[0].binding.domainLevel==1 and domain_family[0].binding.metamagic==2 and domain_family[0].uses==1,"Domain family retains its base domain level and exact selected metamagic resource")
	ctx.assignment=false; spells[0].SpontaneouslyCast=1; spells[1].SpontaneouslyCast=0; actor.playerState.spellbooks["0"].memorized["1"][0].ready=0; actor.playerState.spellbooks["0"].memorized["1"].append({"spell":3,"ready":1,"domain":0,"metamagic":0})
	var value:=helper.spell_entry(ctx,0,1,{"type":2,"intParam":0,"classIndex":0,"metamagic":0,"domainLevel":0},0,1)
	check(value.uses=="S" and int(value.binding.spontaneous)==1 and not value.disabled,"Family child conversion uses parent metadata and a ready non-domain slot")
	actor.playerState.spellbooks["0"].memorized["1"][1].domain=1
	check(helper.spell_entry(ctx,0,1,{"type":2,"intParam":0,"classIndex":0},0,1).disabled,"A domain slot cannot supply spontaneous conversion")
	spells[3].SpontaneouslyCast=1; actor.playerState.spellbooks["0"].memorized["1"][1].domain=0; actor.playerState.spellbooks["0"].memorized["1"][1].spell=4
	var shortcut:=helper.shortcut(actor,{"type":2,"intParam":3,"classIndex":0,"domainLevel":0,"metamagic":0})
	check(shortcut.uses=="S" and shortcut.enabled and int(shortcut.binding.spontaneous)==1,"Received type2 shortcuts regain their native spontaneous flag from current state")
	actor.playerState.spellbooks["0"].memorized["1"][1].ready=0
	check(not helper.shortcut(actor,{"type":2,"intParam":3,"classIndex":0}).enabled,"Spent conversion shortcut disables when no ordinary resource remains")
	var options:=helper.menu(ctx,{"kind":"spell-options"})
	check(options[0].disabled and not options[1].disabled and options[0].binding=={"type":10,"intParam":5},"Counterspell distinguishes self from other creatures and retains native activity shortcut type")
	for flags in [0,1,2,3,512,515,32768,32771,33283]:
		actor.playerState.playerFlags=flags
		check(int(abilities.activity(actor,0).labelRef)==(4849 if flags&1 else 4848) and int(abilities.activity(actor,1).labelRef)==(4851 if flags&2 else 4850),"Search and Stealth labels follow original received active bits "+str(flags))
		check(helper.menu(ctx,{"kind":"spell-options"})[1].label==str(1765 if flags&32768 else 1762),"Defensive casting label follows original received active bit "+str(flags))
		check(helper.menu(ctx,{"kind":"spell-options"})[0].label==str(8118 if flags&512 else 693),"Counterspell label follows the original server's mode4 bit9 "+str(flags))
	# Original override root9a10e0 exposes exactly three fixed physical slots,
	# bypassing class grouping, family expansion, target/resource filters.
	for mask in 8:
		actor.playerState.playerFlags=1024
		actor.playerState.fields9E8=[0 if mask&1 else -1,2 if mask&2 else -1,15 if mask&4 else -1]
		var override_root:=helper.root(ctx); var expected_slots: Array=[]
		for at in 3:
			if mask&(1<<at): expected_slots.append(at+1)
		check(override_root.map(func(row):return row.slot)==expected_slots,"Original override preserves physical slot holes "+str(mask))
		check(override_root.all(func(row):return row.has("binding") and not row.has("menu") and not row.disabled and row.uses==null and row.canDrag and row.binding.classIndex==0 and row.binding.metamagic==0),"Override entries remain direct native actions, including family parents and mismatched targets "+str(mask))
	var override_shortcut:=helper.shortcut(actor,{"type":2,"intParam":3,"classIndex":0,"spontaneous":1})
	check(override_shortcut.uses=="*" and override_shortcut.enabled and override_shortcut.binding.spontaneous==0,"Original override quickbar is unlimited and clears the normal conversion bit")
	actor.playerState.playerFlags=0
	check(helper.root(ctx).map(func(row):return row.slot)==[4,0,6] and not helper.shortcut(actor,{"type":2,"intParam":3,"classIndex":0}).enabled,"Removing override mode restores ordinary class hierarchy and authoritative resource checks")
	check(helper.errors.is_empty(),"Verified prepared data produces no incomplete-read errors",helper.errors)
	var file:=FileAccess.open(args.report,FileAccess.WRITE); file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"publicConnections":0,"scope":"Complete original instruction traversal with captured data/presentation boundaries versus native Godot prepared pages, metamagic and levels; custom server family/resource/target/shortcut checks. Graphical and server outcomes require separate receipts."},"  ")); file.close(); quit(0 if failures.is_empty() else 1)
func _initialize() -> void: call_deferred("run")
