extends RefCounted
# Cold selection only. Every original binary32 rounding boundary stays in its
# owning algorithm. The experiment stores the scalar in an inline Color channel
# instead of constructing Array + PackedFloat32Array solely to cast one value.
static func configured() -> bool:
	var args:=OS.get_cmdline_user_args()
	if args.has("--scalar-representation=packed"):return false
	if args.has("--scalar-representation=value"):return true
	var choice:=OS.get_environment("NWN_SCALAR_REPRESENTATION")
	return choice=="value" or choice!="packed" and OS.get_name()=="Windows"
