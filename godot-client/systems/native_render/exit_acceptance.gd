extends RefCounted
# Process/lifecycle success is separate from an automated gameplay assertion.
# A normal user may quit at Main Menu or cancel an incomplete join. Neither is
# evidence of playable content, and neither is itself an application failure.
static func vault_check(report: Dictionary,create: bool) -> Dictionary:
	var name: String="direct_server_vault_create_check" if create else "direct_server_vault_reconnect_check"
	var receipt: Dictionary=report.get(name,{}) if report.get(name,{}) is Dictionary else {}
	var proof: Dictionary=report.get("creationProof",{}) if report.get("creationProof",{}) is Dictionary else {}
	var expected: Dictionary=proof.get("expected",{}) if proof.get("expected",{}) is Dictionary else {}
	var admitted: Dictionary=report.get("direct_headless_check",{}) if report.get("direct_headless_check",{}) is Dictionary else {}
	var last: Dictionary=report.get("last_world",{}) if report.get("last_world",{}) is Dictionary else {}
	var world: Dictionary=last.get("world",{}) if last.get("world",{}) is Dictionary else {}
	var checks: Dictionary={
		"source_controls":bool(proof.get("success",false)),
		"character_identity":not str(receipt.get("characterFingerprint","")).is_empty(),
		"world_admitted":bool(receipt.get("worldAdmitted",false)) and bool(world.get("ready",false)),
		"same_admitted_world":admitted.has("area") and admitted.has("ui_generation") and int(admitted.area)==int(last.get("area_id",-1)) and int(admitted.ui_generation)==int(last.get("generation",-1)),
		"shared_catalog":bool(admitted.get("catalog_shared",false)),
		"world_snapshots":int(admitted.get("snapshots",0))>0,
		"intentional_leave":str(last.get("reason","")) in ["session-reset","return-main-menu"],
		"disconnect_clean":bool(receipt.get("disconnectClean",false))
	}
	if create:
		checks["creator_opened"]=bool(receipt.get("creatorOpened",false))
		checks["creator_submitted"]=bool(receipt.get("creatorSubmitted",false))
		checks["source_19_sent"]=bool(receipt.get("source19Sent",false))
		checks["created_name"]=not str(expected.get("firstName","")).is_empty()
	else:
		for field in ["rosterAccepted","serverRowMatched","previewRequested","previewReady","playSent"]:
			checks[field]=bool(receipt.get(field,false))
	var passed:=true
	for value in checks.values():
		if not value:passed=false;break
	return {"checks":checks,"passed":passed}
static func classify(report: Dictionary,args: Dictionary,application: bool) -> Dictionary:
	var strict:=not application
	for flag in ["settings-check","actions-check","offline-replay"]:
		if args.get(flag,"")=="true": strict=true
	var gameplay: bool=bool(report.get("playable",false)) and bool(report.get("object_visuals_complete",false)) and (bool(report.get("interactive",false)) or float(report.get("controlled_distance",0))>0.2) and bool(report.get("environment_accepted",false))
	var failed:=report.has("failure")
	var create: bool=args.get("direct-server-vault-create-check","")=="true"
	var reconnect: bool=args.get("direct-server-vault-reconnect-check","")=="true"
	if create or reconnect:
		var lifecycle:=vault_check(report,create)
		return {"mode":"server-vault-create" if create else "server-vault-reconnect","gameplay_success":gameplay and not failed,"success":not failed and lifecycle.passed and not (create and reconnect),"lifecycle_checks":lifecycle.checks,"scope":"Private server-vault creation/reconnect and intentional leave only; visual and full gameplay acceptance remain separate. Final protocol acknowledgment and cleanup remain required."}
	return {"mode":"gameplay-validation" if strict else "application-lifecycle","gameplay_success":gameplay and not failed,"success":not failed and (gameplay or not strict),"scope":"Application exit never substitutes for gameplay, visual, performance or migration acceptance; final protocol acknowledgment and cleanup remain required."}
