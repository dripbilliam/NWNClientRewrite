extends RefCounted
# CGuiTimerButton1401e4d30: strict microsecond threshold, one callback per
# GUI tick, reset elapsed to zero rather than replaying missed intervals.
var active:=false
var first:=true
var elapsed:=0
var delay:=500000
var period:=50000
var rail_initial:=false
func begin(first_delay: int=500000,repeat_period: int=50000) -> void:
	active=true; first=true; elapsed=0; delay=first_delay; period=repeat_period; rail_initial=false
func begin_rail() -> void:
	# Slider HandleLMouseDown primes elapsed to delay with phase0. Its first
	# GUI timer tick pages, phase1 then waits delay, later phases use period.
	begin(333333,100000); rail_initial=true; elapsed=delay
func tick(microseconds: int,eligible: bool=true) -> bool:
	if not active: return false
	elapsed+=maxi(0,microseconds)
	if eligible and elapsed>(period if rail_initial else (delay if first else period)):
		elapsed=0
		if rail_initial: rail_initial=false
		else: first=false
		return true
	return false
func stop() -> void: active=false; first=true; elapsed=0; rail_initial=false
