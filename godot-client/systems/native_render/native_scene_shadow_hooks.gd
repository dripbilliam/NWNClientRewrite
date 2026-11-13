extends RefCounted
# Exact primary-shadow/secondary-shadowblob branch plan. Never hides the main
# renderer. Native shadow detail is graphics.shadows.creatures.mode (0/1/2),
# not an account role, light budget, session mode or guessed room policy.
static func plan(command: Dictionary,detail: Variant,controlled: bool) -> Dictionary:
	if not detail is int or detail<0 or detail>2 or command.get("kind")!="native_reveal_hooks" or not command.get("revealed") is bool or not command.get("render_owner_present") is bool:return {"available":false,"reason":"native-shadow-hook-fields-unavailable"}
	if command.get("setter") not in ["immediate765c80","target765920"] or not command.get("native_field108") is int:return {"available":false,"reason":"native-reveal-setter-unavailable"}
	var reveal: bool=command.revealed;var present: bool=command.render_owner_present;var blocked: int=command.native_field108
	if reveal and blocked!=0:return {"available":true,"commands":[],"store_revealF4":null,"reason":"native-positive-reveal-blocked108"}
	if not present:return {"available":true,"commands":[],"store_revealF4":null if reveal else false,"reason":"native-render-wrapper-absent"}
	var dynamic: bool=reveal and (detail==2 or detail==1 and controlled)
	var blob: bool=not dynamic if reveal else detail==0
	return {"available":true,"commands":[{"kind":"native_shadow","enabled":dynamic},{"kind":"native_shadowblob","attached":blob,"virtual":"CNWC+1f8" if blob else "CNWC+200"}],"store_revealF4":reveal,"reason":"native-detail-hook-branch","detail":detail}
