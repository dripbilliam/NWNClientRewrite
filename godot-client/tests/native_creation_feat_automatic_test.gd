extends "res://tests/native_creation_feat_adapter_test.gd"
const Automatic=preload("res://systems/native_data/creation_feat_automatic.gd")
func model() -> RefCounted:
	var rules=fixture();rules.tables.racialtypes.orderedRows[0].NumberNormalFeatsEveryNthLevel="2";rules.tables.bonus.orderedRows[0].Bonus="1"
	rules.tables.classfeats.orderedRows.append({"FeatIndex":"8","List":"2","GrantedOnLevel":"1"})
	rules.tables.classes.orderedRows[0].PickDomains="0"
	rules.tables.packages={"orderedRows":[{"ClassID":"0","PlayerClass":"1","FeatPref2DA":"auto_preferences"}]}
	rules.tables.auto_preferences={"orderedRows":[{"FeatIndex":"0"},{"FeatIndex":"2"}]}
	rules.draft.merge({"goodEvil":50,"lawChaos":50,"packageSource":true,"skills":{0:1},"feats":[{"id":0,"kind":"normal"},{"id":2,"kind":"normal"}]},true)
	return rules
func stamp(rules) -> Dictionary:
	var value:=Automatic.capture(rules,{},[741,3]);check(value.ready,"Compact source receipt captures completed native Package")
	if value.ready:rules.draft.sourceAutomaticFeats=value.receipt
	return value.get("receipt",{})
func reject(rules,receipt: Variant,label: String) -> void:
	var result:=Automatic.verify(rules,receipt);check(not result.get("ready",false) or not result.get("valid",false),label,result)
func run() -> void:
	var report:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report=arg.trim_prefix("--report=")
	if report.is_empty() or FileAccess.file_exists(report):quit(2);return
	var rules=model();var original_draft: Dictionary=rules.draft.duplicate(true);var original_tables: Dictionary=rules.tables.duplicate(true);var receipt:=stamp(rules)
	var answer:=Automatic.verify(rules,receipt)
	check(answer.get("ready",false) and answer.get("valid",false) and answer.selected==[0,2] and answer.remaining==1,"Exact original preference exhaustion preserves two normal feats and ignored unused bonus",answer)
	var manual:=Snapshot.validate_choices(rules,[0,2]);check(manual.ready and not manual.valid,"The same choices still fail manual all-candidate completeness")
	check(rules.tables==original_tables and rules.draft.sourceAutomaticFeats==receipt,"Worker replay does not mutate active tables or its receipt")
	var expected: Dictionary=original_draft.duplicate(true);expected.sourceAutomaticFeats=receipt;check(rules.draft==expected,"Capture adds only its compact detached receipt to the private draft")
	check(var_to_bytes(receipt).size()<2048 and not str(receipt).contains("definitions") and not str(receipt).contains("orderedRows"),"Receipt stays compact without decoded/table graphs")
	for field in ["classId","raceId","packageId","school","goodEvil","lawChaos"]:
		var changed=model();changed.draft[field]=int(changed.draft[field])+1;reject(changed,receipt,"Changed source context rejects: "+field)
	var changed=model();changed.draft.abilities.Str+=1;reject(changed,receipt,"Changed raw ability context rejects")
	changed=model();changed.draft.domains=[1,2];reject(changed,receipt,"Changed domain context rejects")
	changed=model();changed.draft.skills[0]=2;reject(changed,receipt,"Changed post-recommendation ranks reject")
	changed=model();changed.draft.feats.reverse();reject(changed,receipt,"Changed preference output order rejects")
	changed=model();changed.tables.bonus.orderedRows[0].Bonus="2";reject(changed,receipt,"Changed active class bonus budget rejects")
	changed=model();changed.tables.auto_preferences={"orderedRows":[{"FeatIndex":"0"}]};reject(changed,receipt,"Changed active preference source replays and rejects a different result")
	changed=model();changed.tables.auto_preferences={"orderedRows":[{"FeatIndex":"0xZZ"}]};reject(changed,receipt,"Undefined native hex preference conversion remains unavailable")
	changed=model();changed.tables.erase("auto_preferences");reject(changed,receipt,"Unloaded declared preferences remain unavailable")
	changed=model();changed.tables.auto_preferences={"orderedRows":"malformed"};reject(changed,receipt,"Malformed active preference table remains unavailable")
	changed=model();changed.tables.auto_preferences={};reject(changed,receipt,"A loaded-to-failed preference publication cannot reuse an old verdict")
	for field in ["context","postSkills","selected","preferences"]:
		var bad:=receipt.duplicate(true);bad[field]=17;reject(model(),bad,"Malformed compact field rejects without engine error: "+field)
	for patch in [{"completed":false},{"version":2},{"scope":[741,-1]},{"normal":256},{"remaining":-1},{"selected":[0.0,2.0]},{"preSkills":{0:-1}}]:
		var bad:=receipt.duplicate(true);bad.merge(patch,true);reject(model(),bad,"Malformed completion/owner/budget/identity/rank rejects: "+str(patch))
	changed=model();changed.draft.sourceFeatChoices=true;reject(changed,receipt,"Automatic receipt cannot exempt a source manual selection")
	changed=model();changed.draft.packageSource=false;reject(changed,receipt,"Generic draft cannot select the source-automatic branch")
	rules.reset_choices();check(not rules.draft.has("sourceAutomaticFeats") and not rules.draft.has("sourceFeatChoices"),"Derived reset retires both selection modes")
	# An absent cell skips the helper. A parsed zero-row or a known failed
	# load attempts it but returns remaining unchanged; none invents fillers.
	for kind in ["absent","empty","failed"]:
		var empty=model();empty.draft.feats=[]
		if kind=="absent":empty.tables.packages.orderedRows[0].FeatPref2DA="****";empty.tables.erase("auto_preferences")
		else:empty.tables.auto_preferences={"orderedRows":[]} if kind=="empty" else {}
		var empty_receipt:=stamp(empty);var result:=Automatic.verify(empty,empty_receipt)
		check(result.get("valid",false) and result.selected.is_empty() and result.remaining==3,"Original absent/zero-row/known-failed preference source leaves budget without a fabricated feat: "+kind,result)
	for memorizes in [0,1]:
		var caster=model();caster.tables.classes.orderedRows[0].merge({"SpellCaster":"1","PlayerClass":"1","MemorizesSpells":str(memorizes),"LearnScroll":str(memorizes),"SpellbookRestricted":"1","SpellcastingAbil":"INT","SpellGainTable":"auto_gain","SpellKnownTable":"auto_known"},true)
		caster.tables.auto_gain={"orderedRows":[{"NumSpellLevels":"2","SpellLevel0":"1","SpellLevel1":"1"}]};caster.tables.auto_known={"orderedRows":[{"SpellLevel0":"1","SpellLevel1":"1"}]}
		var caster_receipt:=stamp(caster);var result:=Automatic.verify(caster,caster_receipt)
		check(result.get("ready",false) and result.get("valid",false),"Actual RuleView passes the native spell-capacity resolver for caster mode "+str(memorizes),result)
	var wrapped=model();wrapped.tables.racialtypes.orderedRows[0].NumberNormalFeatsEveryNthLevel="255";wrapped.tables.bonus.orderedRows[0].Bonus="1";wrapped.draft.feats=[]
	var wrapped_receipt:=stamp(wrapped);answer=Automatic.verify(wrapped,wrapped_receipt)
	check(answer.get("valid",false) and answer.selected.is_empty() and answer.remaining==0,"Original combined CHAR sum wraps256 to0 before scanning preferences",answer)
	wrapped=model();wrapped.tables.racialtypes.orderedRows[0].NumberNormalFeatsEveryNthLevel="255";wrapped.tables.bonus.orderedRows[0].Bonus="2";wrapped.draft.feats=[{"id":0,"kind":"normal"}]
	wrapped_receipt=stamp(wrapped);answer=Automatic.verify(wrapped,wrapped_receipt)
	check(answer.get("valid",false) and answer.selected==[0] and answer.remaining==0,"Original combined CHAR257 permits exactly one preference while retaining separate candidate budgets",answer)
	var file:=FileAccess.open(report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"gpu":false,"serverConnections":0,"scope":"Original-backed preference-only automatic feat replay with ignored CHAR remainder; compact receipt, pre/post skill context, active table invalidation, malformed/empty/missing data, caster RuleView spell resolution, generic/manual separation, reset and wrapped budgets. No actor/server/BIC or complete custom controls acceptance."},"\t"));file.close();quit(0 if failures.is_empty() else 1)
