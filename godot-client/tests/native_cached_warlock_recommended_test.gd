extends "res://tests/native_cached_warlock_complete_test.gd"
# The hidden default149 is inspected as raw data, never forced into the visible
# list. Each invocation physically chooses one real visible package310..314.
var mode_retirement_done:=false
func fixture_scope()->String:return "Offline actual cached Arelith Warlock automatic visible-package path through shipping controls, real post panes and active-data Tail/native BIC. The six raw Associate missing cells are inspected, but hidden149 is not injected into a physical choice. No Session/key/GPU/server claim."
func verify_selected_bic(document:Dictionary,creator)->void:
	var written:Array=document.root.FeatList.map(func(row):return int(row.Feat))
	for row in creator.rules.draft.feats:
		check(written.has(int(row.id)),"Parsed automatic-package BIC retains actual selected feat"+str(int(row.id)))
	observations.automaticBicFeats=written
func package_flow(creator,ui)->bool:
	var front=creator.source_frontend;var chosen:=310
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--package="):chosen=int(arg.trim_prefix("--package="))
	if not check(chosen in [310,311,312,313,314],"Requested automatic package is an actual visible captured row",chosen):return false
	var raw_missing:Array=[]
	for id in [149,310,311,312,313,314]:
		var row:Dictionary=creator.rules.row("packages",id)
		var raw:Variant=creator.rules.cell(row,"Associate",null)
		raw_missing.append({"physicalId":id,"associate":raw})
		if not check(creator.rules.num(row,"ClassID",-1)==92 and (raw=="****" or raw==null or str(raw).is_empty()),"Exact active Warlock package has native missing Associate data: "+str(id),raw):return false
	if not await select_entry(front.packages,chosen,"Automatic active package"+str(chosen)):return false
	observations.automaticPackage={"selected":chosen,"rawAssociate":raw_missing,"headerDefault":front.packages.state.default_package}
	if not await input(front.packages.buttons.okbutton,"Apply actual selected automatic package"):return false
	if not check(await wait_source(creator,["","package-spells","package-associate"],15),"Actual automatic package resolves to a real post pane or Customize",trace):return false
	if front.child=="package-spells":
		if not check(await wait_for(func():return front.spells.layout_ready and front.spells.model.get("ready",false),8),"Automatic package's real zero-slot Spells prepares"):return false
		observations.spells=front.spells.model.duplicate(true)
		if not check(front.spells.model.get("remaining")==0 and front.spells.model.get("canAccept",false),"Automatic Warlock zero-slot Spells retains native acceptance",front.spells.model):return false
		if not await input(front.spells.buttons.okbutton,"Automatic zero-slot Spells OK"):return false
		if not check(await wait_source(creator,["","package-associate"]),"Automatic zero-slot post flow advances"):return false
	if front.child=="package-associate":
		if not check(await wait_for(func():return front.associate.layout_ready,8),"Automatic package's actual Familiar pane prepares"):return false
		if not await finish_associate(creator,ui):return false
	if not check(front.child.is_empty() and front.flow.enabled.customize,"Actual automatic package completion enables source Customize",creator.status):return false
	var receipt:Dictionary=creator.rules.draft.get("sourceAutomaticFeats",{})
	observations.automaticReceipt=receipt.duplicate(true)
	if not check(receipt.get("completed",false) and receipt.get("selected")==[408,945] and receipt.get("remaining")==1 and receipt.get("normal")==2 and receipt.get("bonus")==1 and not creator.rules.draft.get("sourceFeatChoices",false),"Actual automatic callback stamps exact native prescription and ignored remainder without filler",receipt):return false
	if chosen==310 and not mode_retirement_done:
		mode_retirement_done=true
		if not await input(front.main.buttons.packagesbutton,"Reopen completed automatic package"):return false
		var retired_on_entry:bool=not creator.rules.draft.has("sourceAutomaticFeats")
		if not await input(front.packages.buttons.configurepckg,"Switch actual package to manual Configure"):return false
		if not check(await wait_source(creator,["package-configuration"]),"Physical Configure reaches actual Skills after automatic mode"):return false
		var retired_on_configure:bool=not creator.rules.draft.has("sourceAutomaticFeats")
		if not await input(front.skills.buttons.cancelbutton,"Cancel manual Skills to source Main"):return false
		if not check(await wait_source(creator,[""]),"Physical manual Cancel returns to source Main"):return false
		observations.automaticModeRetirement={"onEntry":retired_on_entry,"onConfigure":retired_on_configure,"onCancel":not creator.rules.draft.has("sourceAutomaticFeats")}
		if not check(retired_on_entry and retired_on_configure and not creator.rules.draft.has("sourceAutomaticFeats"),"Actual Package entry/Configure/Cancel retire automatic receipt without a draft injection",observations.automaticModeRetirement):return false
		if not await input(front.main.buttons.packagesbutton,"Reopen Package for fresh automatic prescription"):return false
		return await package_flow(creator,ui)
	mark(creator,"automatic-package-complete")
	return failures.is_empty()
