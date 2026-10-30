extends RefCounted
# Original non-creature virtual selectors9b0790 (door) and9b20a0 (placeable).
static func name(type: int,code: int,destroyed_model: int=0) -> String:
	code&=65535
	if code in [14,77,99,100,213,214,215,216]: return "damage"
	if type==10:
		if code==72: return "default" if destroyed_model==0 else "dead"
		return {22:"closed",50:"opened1",51:"opened2",300:"opening1",301:"opening2",302:"closing1",303:"closing2",304:"die"}.get(code,"pause")
	if type==9: return {72:"dead",73:"on",74:"off",75:"open",76:"close",400:"on2off",401:"off2on",402:"close2open",403:"open2close",404:"die"}.get(code,"default")
	return ""
static func door_state(state: Dictionary) -> int:
	return int(state.get("doorOpenState",{22:0,50:1,51:2,72:3}.get(int(state.get("animation",-1)),-1)))
