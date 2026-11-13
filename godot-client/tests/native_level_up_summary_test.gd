extends SceneTree
const Summary=preload("res://systems/native_data/level_up_summary_model.gd")
class Text extends RefCounted:
	func raw(value: Dictionary) -> String:return {100:"Custom class",200:"Skill A",201:"Skill B",300:"Feat one",400:"Old spell",401:"Removed spell",402:"New spell",135:"Strength",6388:"Class",6389:"Hit Points",6390:"Feats",10587:"Skills",6391:"Spells gained",6392:"Spells removed",68687:"None"}.get(int(value.strRef),"")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["report","oracle"]) or FileAccess.file_exists(args.report):quit(2);return
	var oracle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	check(oracle.binarySha256=="3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a","Immutable original Summary instruction corpus")
	for row in oracle.rows:
		var c: Dictionary=row.case;var value:=Summary.gain(int(c.roll),int(c.effectiveModifier),int(c.newBaseModifier),int(c.oldBaseModifier),int(c.oldLevel),int(c.newLevel),int(c.classId),int(c.classLevel),c.oldFeats.map(func(id):return int(id)),c.newFeats.map(func(id):return int(id)),int(c.toughness),int(c.deathless),int(c.epicDeathless))
		check(value==int(row.displayGain),"Original signed/BYTE/retroactive CON/Toughness/Deathless arithmetic "+str(c))
		var wire_value:=Summary.gain(int(c.roll),int(c.effectiveModifier),int(c.newBaseModifier),int(c.oldBaseModifier),int(c.oldLevel),int(c.newLevel),int(c.classId),int(c.classLevel),c.oldFeats,c.newFeats,int(c.toughness),int(c.deathless),int(c.epicDeathless))
		check(wire_value==int(row.displayGain),"Actual JSON-number feat storage preserves original HP arithmetic "+str(c))
	var wire_feats: Array=JSON.parse_string("[51,235,236,237,238,239,240,256,303,354,945,7,944,946,36,40,401,25,10,11]")
	check(typeof(wire_feats[15])==TYPE_FLOAT,"Server JSON feat IDs retain their actual native reader number type")
	check(Summary.gain(3,1,2,2,15,16,10,16,wire_feats,wire_feats,1,3,5)==5,"Captured v3 Wizard die3 CON1 existing Toughness gives5 under explicit pinned private-vitals fixture")
	for invalid in [null,"40",40.5,-1,65536]:check(not Summary.has_feat([invalid],40),"Malformed feat IDs do not become received Toughness")
	var text:=Text.new();var tables:={"classes":{"orderedRows":[{"Name":"100","SpellCaster":"0","PlayerClass":"1","SpellTableColumn":"CUSTOM"}]},"skills":{"orderedRows":[{"Name":"200"},{"Name":"201"}]},"feat":{"orderedRows":[{"FEAT":"0"},{"FEAT":"300"}]},"ruleset":{"orderedRows":[]},"spells":{"orderedRows":[{"Name":"400","CUSTOM":"0"},{"Name":"401","CUSTOM":"1"},{"Name":"402","CUSTOM":"1"}]}}
	var received:={"classes":[{"id":0,"level":3}],"baseAbilities":[12,12,14,12,12,12],"feats":[0],"skills":[127,1],"spellbooks":{"0":{"known":[0,1]}}}
	var private:={"ready":true,"source":{"current":0,"classes":[{"id":0,"level":4}]},"vitals":{"raw":[13,12,14,12,12,12],"modifiers":[1,1,2,1,1,1]}}
	var before:=received.duplicate(true);var data:=tables.duplicate(true)
	var value:=Summary.compose(received,private,[128,3],[0,1,65535],null,8,false,tables,text)
	var expected:="Class : Custom class\n\nStrength: +1\n\nHit Points : +10\n\nFeats :\nFeat one\n\nSkills :\nSkill A+-255\nSkill B+2\n"
	check(value.ready and value.summary==expected and value.hitDie==8 and value.displayHitPointGain==10 and not value.serverAcknowledged,"Actual active TLK format preserves exact sections, signed skill BYTE difference and raw die versus displayed HP gain")
	var wire_received: Dictionary=JSON.parse_string(JSON.stringify(received));var wire_before:=wire_received.duplicate(true)
	value=Summary.compose(wire_received,private,[128,3],[0,1,65535],null,8,false,tables,text)
	check(value.ready and value.summary==expected,"Received JSON FLOAT and private INT IDs do not list old feats as newly gained")
	check(wire_received==wire_before,"Mixed numeric Summary membership never mutates the received snapshot")
	value=Summary.compose(received,private,[127,1],[0],null,8,true,tables,text)
	check(value.ready and value.summary.contains("Hit Points : ?\n\nFeats :\nNone\n\nSkills :\nNone\n"),"Received hidden-HP rule prints question mark, with active None text for empty lists")
	var known: Array=[]
	for _level in 10:known.append([])
	known[0]=[0];known[1]=[2];tables.classes.orderedRows[0].SpellCaster="1"
	value=Summary.compose(received,private,[127,1],[0],known,8,false,tables,text)
	check(value.ready and value.summary.ends_with("\nSpells gained :\nNew spell\n\nSpells removed :\nRemoved spell\n"),"Current-class native known books compare in level/order and use active spell names")
	check(not Summary.compose(received,private,[127,1],[0],null,8,false,tables,text).ready,"Missing final copied known arrays stay pending")
	var missing:=received.duplicate(true);missing.erase("spellbooks")
	check(not Summary.compose(missing,private,[127,1],[0],known,8,false,tables,text).ready,"Missing owned before-book does not become a constructor-empty book")
	check(Summary.known(missing,1,0,tables).ready and Summary.known(missing,1,0,tables).value==[[],[],[],[],[],[],[],[],[],[]],"Only an appended new private class receives proven empty constructor books")
	check(not Summary.compose(received,private,[127,1],[0],known,8,null,tables,text).ready,"Missing received hidden-HP flag never becomes false")
	tables.classes.orderedRows[0].SpellCaster="0";check(received==before and tables==data,"Summary formatting never writes actor/private comparison/shared rules")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Pure Summary helper:384 original executed HP cases in both authored INT and actual JSON FLOAT feat representations, active-table/TLK text, raw-roll/display separation, signed skills/known-book differences and missing input gates. No runtime adapter/view, live server or pixel acceptance."})+"\n");file.close();quit(0 if failures.is_empty() else 1)
