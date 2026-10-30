extends RefCounted
# Local visual stream, not gameplay/server randomness. Startup seed and global
# original draw ordering are not established by implementing the CRT recurrence.
var state:=1
var draws:=0
func seed_value(value: int) -> void:
	state=value&0xffffffff; draws=0
func next() -> int:
	state=(state*0x343fd+0x269ec3)&0xffffffff; draws+=1
	return (state>>16)&0x7fff
