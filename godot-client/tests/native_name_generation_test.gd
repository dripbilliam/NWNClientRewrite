extends SceneTree
const Letters=preload("res://systems/native_data/letter_table.gd")
const Generator=preload("res://systems/native_data/name_generation.gd")
var failures: Array=[]
var checks:=0
class Samples extends RefCounted:
	var seed:=1
	func next() -> int:
		seed=(seed*214013+2531011)&0xffffffff
		return (seed>>16)&32767
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> bool:
	checks+=1
	if not value:failures.append(message)
	return value
func digest(data: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not data.is_empty():hash.update(data)
	return hash.finish().hex_encode()
func content(n: int,sparse: bool=false) -> PackedByteArray:
	var values:=PackedFloat32Array();values.resize(3*(n+n*n+n*n*n));var at:=0
	for order in [1,2,3]:
		for left in (1 if order==1 else n):
			for right in (n if order==3 else 1):
				for mode in 3:
					for index in n:
						var scale:=.75 if sparse and mode==1 else .5 if sparse and mode==2 else 1.0
						values[at]=0.0 if sparse and order==3 and mode!=0 and (left*3+right)%11==0 else scale*(index+1)/n;at+=1
	var bytes: PackedByteArray="LTR V1.0".to_ascii_buffer();bytes.append(n);bytes.append_array(values.to_byte_array());return bytes
func run() -> void:
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var pair:=arg.trim_prefix("--").split("=",true,1)
		if pair.size()==2:args[pair[0]]=pair[1]
	if not args.has_all(["oracle","report"]) or FileAccess.file_exists(args.report):quit(2);return
	var source: Variant=JSON.parse_string(FileAccess.get_file_as_string(args.oracle))
	if not source is Dictionary or not source.has_all(["parsers","names"]):quit(2);return
	for at in source.parsers.size():
		var row: Dictionary=source.parsers[at];var bytes:=content(int(row.input.count))
		if row.input.kind=="trailing":bytes.append_array("extra bytes".to_ascii_buffer())
		elif row.input.kind=="truncated":bytes.resize(bytes.size()-1)
		elif row.input.kind=="wrong-header":bytes[0]=66;bytes[1]=65;bytes[2]=68
		var decoded:=Letters.decode(bytes)
		check(decoded.ready==row.ready,"Original LTR header/length admission "+str(at))
		if row.ready:check(Letters.valid(decoded) and digest(decoded.values.to_byte_array())==row.probabilitySha256,"Original start/middle/end prefix probability byte order "+str(at))
	var timings: Array=[]
	for at in source.names.size():
		var row: Dictionary=source.names[at];var table:=Letters.decode(content(int(row.input.count),bool(row.input.sparse)));var rng:=Samples.new();rng.seed=int(row.input.seed)
		var began:=Time.get_ticks_usec();var result:=Generator.new().generate(table,rng.next,row.input.filters if row.input.filterLoaded else []);timings.append((Time.get_ticks_usec()-began)/1000.0)
		check(result.ready and result.name==row.name,"Complete original generated name "+str(at)+": "+str(result))
		check(result.draws==int(row.draws),"Original RNG consumption/restart/backtrack/filter order "+str(at))
	var generator:=Generator.new();var table:=Letters.decode(content(3));var empty:=Letters.decode(content(0))
	check(not generator.generate(empty,func():return 0,[]).ready,"A loaded zero-letter resource cannot invent a name")
	check(not generator.generate(table,Callable(),[]).ready and not generator.generate(table,func():return 0,null).ready,"Missing RNG/filter inputs remain unavailable")
	var unavailable:=generator.generate(table,func():return null,[]);check(not unavailable.ready and unavailable.draws==1,"Missing RNG result does not become sample0")
	unavailable=generator.generate(table,func():return 32767,[],10);check(not unavailable.ready and unavailable.draws==10,"Strict CDF comparison retries a sample equal to the final1.0 boundary within the finite budget")
	unavailable=generator.generate(table,func():return 0,["aaaa"],20);check(not unavailable.ready and unavailable.draws==20,"Filtered repeats do not silently accept a banned name or invent another")
	check(not generator.draw.is_valid(),"Every completion releases the borrowed RNG callback")
	var nonmonotonic:=Letters.decode(content(3));nonmonotonic.values[0]=.9;nonmonotonic.values[1]=.1
	check(generator.choose(nonmonotonic,1,0,16384)==0,"Original probability selection scans first-match order rather than assuming a monotonic CDF")
	var large: PackedByteArray="LTR V1.0".to_ascii_buffer();large.append(255)
	check(not Letters.decode(large).ready,"Large declared alphabets require all bytes before allocation")
	check(not Letters.decode(PackedByteArray()).ready and not Letters.decode("LTR V2.0".to_ascii_buffer()).ready,"Absent/version-mismatched LTR stays explicit")
	var file:=FileAccess.open(args.report,FileAccess.WRITE);file.store_string(JSON.stringify({"success":failures.is_empty(),"checks":checks,"failures":failures,"originalParserCases":source.parsers.size(),"originalNameCases":source.names.size(),"generationMs":timings,"scope":"Native flat LTR parser and pure generator vs23 original full parser/72 original full generator executions with captured authored resources, RNG15/filter services; strict thresholds/backtracking/filters/bounded invalid inputs. No installed resource, table resolver, creator/draft/server/GPU/pixel acceptance.","gpu":false,"serverConnections":0},"\t"));file.close();quit(0 if failures.is_empty() else 1)
