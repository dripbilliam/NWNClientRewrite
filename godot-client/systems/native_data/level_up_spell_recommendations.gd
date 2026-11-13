extends RefCounted
# Original9c9df0 over an already valid private mode1 chooser. The action owner
# performs entry/successful-String resets at their asynchronous boundaries;
# finish() then runs preference traversal and the native descending GUI pass.
const Preferences=preload("res://systems/native_data/level_up_spell_preferences.gd")
static func apply(state,plan: Dictionary) -> Dictionary:
	if not state.ready or not plan.get("ready",false) or not plan.get("helperInvoked") is bool:return {"ready":false,"reason":"Native mode1 spell recommendations are unavailable."}
	if not state.reset_choices():return {"ready":false,"reason":"The native known-spell baseline is unavailable."}
	if plan.helperInvoked:state.reset_choices()
	return finish(state,plan)
static func finish(state,plan: Dictionary) -> Dictionary:
	if not state.ready or not plan.get("ready",false) or not plan.get("helperInvoked") is bool:return {"ready":false,"reason":"Native mode1 spell recommendations are unavailable."}
	var highest:=0;var preference_calls: Array=[];var greedy_calls: Array=[];var reads: Array=[]
	if plan.helperInvoked:
		var source: Dictionary=state.source.duplicate();source.known=state.known;source.restricted=plan.get("restricted");source.loaded=plan.get("loaded");source.preferences=[];source.opposition=plan.get("opposition")
		var result:=Preferences.apply(source,plan.get("preferenceTable",{}))
		if not result.ready:return result
		state.known=result.known;state.remaining=int(result.remaining)&255;highest=int(result.highest)&255;preference_calls=result.calls;reads=result.reads
	state.initialize(true)
	for level in range(9,-1,-1):
		if not state.tabs[level]:continue
		state.show_level(level)
		while state.remaining!=0 and state.source.minimum[state.selected_level] and not state.available_ids.is_empty():
			var id: int=state.available_ids[0]
			if not state.add(id):break
			greedy_calls.append(["learn",id]);highest=maxi(highest,level)
	state.show_level(highest)
	return {"ready":true,"view":state.view(),"preferenceCalls":preference_calls,"greedyCalls":greedy_calls,"reads":reads,"highest":highest}
