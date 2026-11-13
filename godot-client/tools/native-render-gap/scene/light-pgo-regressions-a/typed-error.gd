extends "res://fixture.gd"
func run()->void:
	var typed: Dictionary[int,Variant]={1:12.0}
	var c:=context({"radius":8.0},typed)
	var result:=poll(c,"malformed-typed-state")
	check(not result.has("error") and result.rows.size()==1,"Old has validation diagnostic still uses the existing zero fallback")
	check(c.trace==["props","state","revision"],"Typed-key diagnostic preserves subsequent caller/getter order")
	var diagnostics: Dictionary=c.registry.call("dispatch",9,{})
	var selected: bool=OS.get_cmdline_user_args().has("--light-dictionary-read=single")
	check(int(diagnostics.get("dictionary_single_typed_key_fallbacks",0))==1 if selected else int(diagnostics.get("dictionary_single_typed_key_fallbacks",0))==0,"Actual typed-key fallback witnessed")
	close(c);await process_frame
	var file:=FileAccess.open(output,FileAccess.WRITE);var success:=checks.all(func(row):return row.ok)
	file.store_string(JSON.stringify({"success":success,"checks":checks,"observations":observations,"diagnostics":diagnostics,"scope":"Intentional malformed typed-key has diagnostic parity; no renderer or game inputs"}));file.close();quit(0 if success else 1)
