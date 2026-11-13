extends RefCounted
# Process/lifecycle success is separate from an automated gameplay assertion.
# A normal user may quit at Main Menu or cancel an incomplete join. Neither is
# evidence of playable content, and neither is itself an application failure.
static func classify(report: Dictionary,args: Dictionary,application: bool) -> Dictionary:
	var strict:=not application
	for flag in ["settings-check","actions-check","offline-replay"]:
		if args.get(flag,"")=="true": strict=true
	var gameplay: bool=bool(report.get("playable",false)) and bool(report.get("object_visuals_complete",false)) and (bool(report.get("interactive",false)) or float(report.get("controlled_distance",0))>0.2) and bool(report.get("environment_accepted",false))
	var failed:=report.has("failure")
	return {"mode":"gameplay-validation" if strict else "application-lifecycle","gameplay_success":gameplay and not failed,"success":not failed and (gameplay or not strict),"scope":"Application exit never substitutes for gameplay, visual, performance or migration acceptance; final protocol acknowledgment and cleanup remain required."}
