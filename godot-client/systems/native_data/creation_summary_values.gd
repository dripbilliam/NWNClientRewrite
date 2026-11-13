extends RefCounted
# Original live-draft Character prefix1409b6380..1409b72a5 and title88b180.
# Display projection only. Unported live-draft detail getters remain
# explicitly absent rather than being inferred from an imported BIC preview.
const Values=preload("res://systems/native_data/character_record_values.gd")
const KEYS=["Str","Dex","Con","Int","Wis","Cha"]
static func full_name(first: String,last: String) -> String:
	# Original7f3f00 joins nonempty fields; it does not trim their contents.
	return first if last.is_empty() else last if first.is_empty() else first+" "+last
static func label(value: Variant="",adjustment: int=0) -> Dictionary:
	return {"text":Values.integer_text(value) if value is int or value is float else str(value),"adjustment":adjustment}
static func compose(source: Dictionary,mask: int,tables: Dictionary) -> Dictionary:
	mask&=255
	var labels:={"title":label(str(source.get("prefix",""))+", "+(str(source.get("name","")) if mask&1 else "")),"classes":label(),"hitpoints":label(),"armorclass":label(),"experience":label(),"nextlevel":label(),"lac":label(),"lhp":label()}
	var header: String=str(source.get("race","")) if mask&2 else ""
	if mask&16: header+=", "+str(source.get("alignment",""))
	if mask&4: header+="\n"+str(source.get("class",""))+"\n"
	labels.classes=label(header)
	var scores: Array=source.get("scores",[]); var adjustments: Array=source.get("adjustments",[]); var pending: Array=[]
	for index in 6:
		var key: String=KEYS[index].to_lower(); labels[key+"stat"]=label(); labels[key+"mod"]=label()
		if not mask&8: continue
		if index>=scores.size() or scores[index]==null: pending.append(key+"stat"); pending.append(key+"mod"); continue
		var score:=int(scores[index])&255; var adjustment:=Values.signed8(int(adjustments[index])) if index<adjustments.size() else 0
		labels[key+"stat"]=label(score,adjustment)
		var effective: Variant=Values.modifier(score,tables); var baseline: Variant=Values.modifier((score-adjustment)&255,tables)
		if index==1 and effective!=null: effective=Values.signed8(int(effective)+Values.signed8(int(source.get("dexterity",0))))
		if effective!=null and baseline!=null: labels[key+"mod"]=label(effective,int(effective)-int(baseline))
		else: pending.append(key+"mod")
	if mask&8:
		if source.has_all(["currentHP","temporaryHP","maximumHP"]): labels.hitpoints=label(str(int(source.currentHP)+int(source.temporaryHP))+"/"+str(int(source.maximumHP)))
		else: pending.append("hitpoints")
		if source.has_all(["armorBase","armorModeBonus"]): labels.armorclass=label(int(source.armorBase)+int(source.armorModeBonus))
		# Earlier bounded-format oracle fixtures named the opaque second getter
		# armorItems. Retain that fixture input, but live data uses its real meaning.
		elif source.has_all(["armorBase","armorItems"]): labels.armorclass=label(int(source.armorBase)+int(source.armorItems))
		else: pending.append("armorclass")
	return {"labels":labels,"mask":mask,"pending":pending,"full_creation_summary_parity":false,"native_only":true}
