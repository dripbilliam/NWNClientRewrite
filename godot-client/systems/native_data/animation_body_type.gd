extends RefCounted
# Read-only native oracle: nwmain SHA256 3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a,
# FUN_1409795c0, Find calls 0x140979b82..0x140979bd8, setter call
# 0x140979c57 -> FUN_14080a2d0 writes the animation owner's +0xde byte.
# MODELTYPE is a set of case-sensitive flags, not a single-character enum.
static func classify(value: String) -> int:
	var category:=4 if value.contains("P") else 2 if not value.contains("S") and (value.contains("F") or value.contains("L")) else 11
	if category in [4,2] and not value.contains("L"): return 1
	return 3 if category==2 else 2
