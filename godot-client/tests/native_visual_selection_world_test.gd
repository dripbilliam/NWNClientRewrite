extends "res://tests/native_effect_membership_test.gd"
var native_calls:=0
var native_failures:=0
func fixture(indexed: bool,controlled: int=123) -> Dictionary:
	var value:=super.fixture(indexed,controlled)
	value.world.compiled_selection=indexed
	return value
func dispose(value: Dictionary) -> void:
	native_calls+=value.world.compiled_selection_calls;native_failures+=value.world.compiled_selection_failures
	super.dispose(value)
func extra_evidence() -> Dictionary:
	check(native_calls>0 and native_failures==0,"Actual world integration exercises native selection without fallback/failure")
	return {"compiled_selection_calls":native_calls,"compiled_selection_failures":native_failures}
