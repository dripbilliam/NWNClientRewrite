extends RefCounted
# Original9ce190 for MemorizesSpells!=0/LearnScroll==0: every enabled level
# with a successful minimum-ability getter writes the native known-left BYTE
# into WORD+19dc before testing it. Only such a guaranteed overwrite removes
# dependence on the panel's unbound prior counter. No previous value is guessed.
const Scalars=preload("res://systems/native_data/level_up_class_state.gd")
static func derive(capacity: Array,minimum: Array,known: Array) -> Dictionary:
	if capacity.size()!=10 or minimum.size()!=10 or known.size()!=10:return {"ready":false,"reason":"Native ten-level spell counter storage is unavailable."}
	var reached: Array=[];var counter: Variant=null
	for level in 10:
		if not Scalars.integer(capacity[level],0,255) or not minimum[level] is bool or not known[level] is Array or known[level].size()>255:return {"ready":false,"reason":"Native spell counter getters are unavailable."}
		if int(capacity[level])!=0 and minimum[level]:
			reached.append(level);counter=maxi(0,int(capacity[level])-known[level].size())
	if reached.is_empty():return {"ready":false,"reason":"Original spell initialization requires a prior private selection counter.","reached":[],"counter":null}
	return {"ready":true,"counter":int(counter),"reached":reached,"source":"native9ce190_known_left_overwrite"}
