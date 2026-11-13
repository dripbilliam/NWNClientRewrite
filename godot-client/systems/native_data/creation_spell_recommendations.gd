extends RefCounted
# Original9c9df0 chooser coordinator. Existing State owns the native chooser's
# books, initialization, list ordering, counters and automatic level advance.
const Preferences=preload("res://systems/native_data/creation_spell_preferences.gd")
static func apply(state,plan: Dictionary) -> Dictionary:
	if not state.ready:return {"ready":false,"reason":"The native spell chooser is unavailable."}
	if not plan.get("ready",false) or not plan.get("helperInvoked") is bool:return {"ready":false,"reason":str(plan.get("reason","Native package preference lookup is unavailable."))}
	if not state.reset_choices():return {"ready":false,"reason":"The native known-spell baseline is unavailable."}
	var highest:=0;var preference_calls: Array=[];var greedy_calls: Array=[]
	if plan.helperInvoked:
		# Original resets once on entry and again after a successful package
		# SpellPref2DA lookup, before running the separate preference helper.
		state.reset_choices()
		var source: Dictionary=state.source.duplicate();source.known=state.known;source.restricted=plan.get("restricted");source.loaded=plan.get("loaded");source.preferences=plan.get("preferences");source.opposition=plan.get("opposition")
		var result:=Preferences.apply(source)
		if not result.ready:return result
		state.known=result.known;state.remaining=int(result.remaining)&255;highest=int(result.highest)&255;preference_calls=result.calls
	state.initialize(true)
	for level in range(9,-1,-1):
		if not state.tabs[level]:continue
		state.show_level(level)
		# Add's original non-memorizing auto-advance is deliberately retained:
		# the displayed level can change within this outer descending loop.
		while state.remaining!=0 and state.source.minimum[state.selected_level] and not state.available_ids.is_empty():
			var id: int=state.available_ids[0]
			if not state.add(id):break
			greedy_calls.append(["learn",id]);highest=maxi(highest,level)
	state.show_level(highest)
	return {"ready":true,"view":state.view(),"preferenceCalls":preference_calls,"greedyCalls":greedy_calls,"highest":highest}
