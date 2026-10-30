extends RefCounted
# Original INV_STACKSPLIT9aa6d0/740/810/920, CRT atoi and timer1e4d30.
# Presentation arithmetic only; the server owns all balances and item counts.
const PERIOD_US:=50000
const DELAY_US:=500000
static func signed32(value: int) -> int:
	value=value&0xffffffff
	return value-0x100000000 if value>0x7fffffff else value
static func decimal(text: String) -> int:
	var index:=0
	while index<text.length() and text.unicode_at(index) in [9,10,11,12,13,32]: index+=1
	var negative:=false
	if index<text.length() and text.unicode_at(index) in [43,45]: negative=text.unicode_at(index)==45; index+=1
	var maximum:=2147483648 if negative else 2147483647; var value:=0
	while index<text.length():
		var digit:=text.unicode_at(index)-48
		if digit<0 or digit>9: break
		value=mini(maximum,value*10+digit); index+=1
	return -value if negative else value
static func changed(text: String,maximum: int,step: int) -> int:
	var value:=signed32(decimal(text)+(1 if step>0 else -1))
	return mini(value,signed32(maximum)) if step>0 else maxi(value,0)
static func confirmed(text: String,maximum: int) -> int: return mini(decimal(text),signed32(maximum))
static func accepts_character(code: int) -> bool: return code<=57
static func tick(elapsed: int,initial: bool,delta_us: int,held: bool) -> Dictionary:
	var current:=signed32(elapsed+delta_us); var fired: bool=current>(DELAY_US if initial else PERIOD_US) and held
	return {"elapsed":0 if fired else current,"initial":false if fired else initial,"fired":fired}
