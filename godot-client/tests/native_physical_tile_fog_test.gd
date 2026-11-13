extends SceneTree
const Fog=preload("res://tools/native_parity/visibility/physical_tile_fog.gd")
var checks:=0
var failures: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);print("FAIL ",label)
func word(value: float) -> int:
	var bytes:=PackedByteArray();bytes.resize(4);bytes.encode_float(0,value);return bytes.decode_u32(0)
func _initialize() -> void:run.call_deferred()
func endpoint(fog,token: int,life: Array,key: String,source: Node,state: Dictionary) -> Dictionary:
	var reference:=weakref(source)
	var lease:={"source":source.get_instance_id(),"part":1,"material":state.material}
	var guard:=func(value):return is_instance_valid(reference.get_ref()) and value==lease and state.current
	var publish:=func(factor,value):
		if not guard.call(value):return false
		state.factor=factor;state.writes+=1
		value.material=-1 # The publisher receives detached lease data.
		return true
	return {"result":fog.adopt_endpoint(token,life,key,lease,guard,publish),"lease":lease,"state":state}
func run() -> void:
	var current:={"value":true}
	var scope: Array=[5,3,9]
	var guard:=func(value):return current.value and value==scope
	var fog:=Fog.new()
	check(fog.configure(scope,guard).available,"Physical fog borrows an explicit source scope")
	scope[0]=6
	check(not fog.register_tile(1,[100,1]).available,"Mutation of source scope invalidates, rather than silently retargets, the configured owner")
	scope[0]=5
	var life: Array=[100,1]
	check(fog.register_tile(1,life).allocated,"First physical TileData is constructed")
	life[1]=9
	check(not fog.tile_view(1,life).available,"Tile lifetime is detached from caller data")
	life[1]=1
	check(not fog.register_tile(1,life).allocated and fog.tile_view(1,life).factor==1.0,"Shared SpawnTile aliases reuse constructor state without reset")
	check(not fog.register_tile(1,[100,2]).available,"A different physical lifetime cannot reuse an active token")
	check(fog.register_tile(2,[100,2]).available,"Outside/border TileData has independent physical state")
	check(fog.register_tile(4294967295,[100,3]).available,"Opaque uint32 physical tokens retain the full resolver domain")
	check(fog.advance_collected(PackedInt64Array([4294967295]),0.1).available,"Native packed callback tokens require no boxed Array conversion")
	check(not fog.advance_collected({"token":1},0.1).available,"An unrelated container is not accepted as collection input")
	var terrain:=Node.new();root.add_child(terrain)
	var scenery:=Node.new();root.add_child(scenery)
	var a:=endpoint(fog,1,life,"terrain-part",terrain,{"current":true,"factor":-5.0,"writes":0,"material":42})
	var b:=endpoint(fog,1,life,"static-part",scenery,{"current":true,"factor":-5.0,"writes":0,"material":43})
	check(a.result.available and b.result.available and a.state.factor==1 and b.state.factor==1,"Terrain and received static Parts share physical TileData endpoints")
	check(fog.receive_fog(1,life,true).available and fog.tile_view(1,life).factor==0,"Native fog(true) resets physical factor independently of visual readiness")
	check(a.state.factor==1 and b.state.factor==1,"Incomplete participant binding preserves default1 on every registered endpoint")
	check(fog.set_publish_ready(1,life,true).available and a.state.factor==0 and b.state.factor==0,"A complete physical TileData publishes to terrain and static geometry together")
	check(fog.tile_view(2,[100,2]).factor==1 and not fog.tile_view(2,[100,2]).fogged,"Canonical initialization never zeros an unrelated outside TileData")
	check(fog.advance_collected([1],0.1).changed==0 and a.state.factor==0,"Collected fogged tile does not advance")
	check(fog.receive_fog(1,life,false).available,"Native fog(false) retains current factor")
	check(fog.advance_collected([],0.1).changed==0 and a.state.factor==0,"A revealed but uncollected TileData remains unchanged")
	var writes: int=a.state.writes
	check(fog.advance_collected([1,1],0.1).changed==1 and word(a.state.factor)==0x3f4ccccd and a.state.factor==b.state.factor,"Duplicate ordered callbacks produce native f32 0.8 on all physical participants")
	check(a.state.writes==writes+1,"Duplicate callbacks do not duplicate the final shader endpoint write")
	check(fog.advance_collected([1],1).available and a.state.factor==1,"Native ramp upper-clamps at1")
	writes=a.state.writes
	check(fog.advance_collected([1],0.1).changed==0 and a.state.writes==writes,"Settled native tiles do not revisit shader endpoints")
	check(fog.receive_fog(1,life,true).available and a.state.factor==0,"Repeated native true setter is not discarded as a flag no-op")
	fog.receive_fog(1,life,false)
	check(fog.advance_collected([1],-0.125).available and word(a.state.factor)==0xbf000000,"Signed native renderer DeltaT has no invented lower-factor clamp")
	var previous: float=a.state.factor
	check(not fog.advance_collected([1,99],0.1).available and a.state.factor==previous and fog.tile_view(1,life).factor==previous,"Unknown callback list is rejected before partial native-state mutation")
	check(not fog.advance_collected([1],NAN).available and fog.tile_view(1,life).factor==previous,"Unavailable timing is explicit and never substituted")
	var view:=fog.tile_view(1,life);view.lifetime[0]=-1;view.factor=99
	check(fog.tile_view(1,life).lifetime==life and fog.tile_view(1,life).factor==previous,"Detached diagnostic views cannot modify physical state")
	check(fog.set_publish_ready(1,life,false).available and a.state.factor==1 and b.state.factor==1,"Losing source completeness restores default1 for all physical participants")
	check(fog.retire_endpoint("static-part",b.lease),"Source/Part retirement drops only its endpoint lease")
	check(fog.tile_view(1,life).endpoints==1 and fog.tile_view(1,life).factor==previous,"Retiring a static placement does not retire shared physical TileData")
	scenery.free()
	var replacement:=Node.new();root.add_child(replacement)
	var c:=endpoint(fog,1,life,"static-part",replacement,{"current":true,"factor":-5.0,"writes":0,"material":44})
	check(c.result.available and c.state.factor==1,"A later replacement endpoint adopts the current effective factor")
	check(not fog.retire_endpoint("static-part",b.lease) and fog.tile_view(1,life).endpoints==2,"Old source lifetime cannot retire a replacement using the same endpoint key")
	check(fog.set_publish_ready(1,life,true).available and c.state.factor==previous and a.state.factor==previous,"Completeness reactivation publishes retained native state without recomputation")
	check(a.lease.material==42 and c.lease.material==44,"Mutable publisher arguments cannot change retained endpoint leases")
	c.state.current=false
	check(not fog.receive_fog(1,life,true).available and c.state.factor==previous,"A replaced material/endpoint blocks writes onto the stale endpoint")
	check(fog.tile_view(1,life).factor==0,"Publication failure does not invent a different native reducer state")
	check(fog.retire_endpoint("static-part",c.lease),"Stale endpoint can be retired by its exact source owner")
	check(fog.set_publish_ready(1,life,false).available and a.state.factor==1,"Remaining current endpoint restores explicit default after an unsupported endpoint")
	var retry:=Fog.new();retry.configure([5,9,9],func(value):return value==[5,9,9]);retry.register_tile(1,[900,1])
	var stale_first:=endpoint(retry,1,[900,1],"first",terrain,{"current":true,"factor":-5.0,"writes":0,"material":91})
	var current_last:=endpoint(retry,1,[900,1],"last",replacement,{"current":true,"factor":-5.0,"writes":0,"material":92})
	retry.receive_fog(1,[900,1],true);retry.receive_fog(1,[900,1],false);retry.advance_collected([1],0.125);retry.set_publish_ready(1,[900,1],true)
	check(current_last.state.factor==0.5,"Retry regression begins with two genuinely published half-fog endpoints")
	stale_first.state.current=false
	check(not retry.set_publish_ready(1,[900,1],false).available and current_last.state.factor==0.5 and retry.tile_view(1,[900,1]).publication_pending,"Stale first endpoint leaves later fallback publication explicitly pending")
	check(retry.retire_endpoint("first",stale_first.lease),"Retirement removes the stale endpoint without changing native C8")
	var resumed:=retry.set_publish_ready(1,[900,1],false)
	check(resumed.available and not resumed.changed and current_last.state.factor==1 and not retry.tile_view(1,[900,1]).publication_pending,"Same-value completeness retry really restores later endpoints after stale retirement")
	check(retry.tile_view(1,[900,1]).factor==0.5,"Retry publication does not advance or replay native fog state")
	var recovered_writes: int=current_last.state.writes;retry.set_publish_ready(1,[900,1],false)
	check(current_last.state.writes==recovered_writes,"A successful completeness retry returns to the zero-redundant-write path")
	retry.close()
	# Guard callbacks can reenter scope retirement. No succeeding endpoint from
	# this old callback is allowed to be marked published after that reentry.
	var reentrant:=Fog.new();reentrant.configure([5,4,9],func(value):return value==[5,4,9]);reentrant.register_tile(1,[200,1])
	var calls:={"value":0}
	var reentered:=reentrant.adopt_endpoint(1,[200,1],"reentrant",{"id":1},func(_value):return true,func(_factor,_value):calls.value+=1;reentrant.close();return true)
	check(not reentered.available and calls.value==1 and reentrant.snapshot().closed and reentrant.snapshot().stats.publications==0,"Reentrant scope replacement cannot certify the retired endpoint's publication")
	current.value=false;writes=a.state.writes
	check(not fog.receive_fog(1,life,false).available and not fog.advance_collected([1],0.1).available and a.state.writes==writes,"Connection/area retirement fences setters, collection and endpoint writes")
	fog.close()
	check(not fog.register_tile(1,[300,1]).available and not fog.tile_view(1,life).available,"Closed scope cannot resolve an old token or resurrect state")
	var reconnect:=Fog.new();reconnect.configure([6,1,9],func(value):return value==[6,1,9]);reconnect.register_tile(1,[300,1])
	check(not reconnect.tile_view(1,life).available and reconnect.tile_view(1,[300,1]).factor==1,"Reconnect may reuse a numeric token only with its new physical scope/lifetime")
	reconnect.close();terrain.free();replacement.free()
	print("NATIVE_PHYSICAL_TILE_FOG ",checks," checks ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
