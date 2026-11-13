const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(__dirname, '../..');
const base = path.join(root, '.cache/particle-geometry-worker/candidate-e/fixture');
const label = process.argv[2];
if (!/^[a-z]$/.test(label ?? '')) throw new Error('Fresh private stage letter required');
const out = path.join(root, `.cache/nwn64/geometry-worker-original-${label}`);
const source = path.join(base, 'tests/geometry_worker_chunks_test.gd');
const inventory = path.join(root, 'reports/native-effect-membership-local-index-v3.native-emitter-inventory.json');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
function replaceOnce(body, from, to) {
  if (body.split(from).length !== 2) throw new Error(`Expected one marker: ${from.slice(0, 70)}`);
  return body.replace(from, to);
}
if (fs.existsSync(out)) throw new Error('Private witness stage already exists');
const original = JSON.parse(fs.readFileSync(inventory));
const keys = ['Explosion|82', 'Fountain|70', 'Explosion|74', 'Fountain|98'];
for (const key of keys) if (!original.some(row => `${row.properties.update}|${row.properties.flags}` === key && row.source === 'plc_i05')) throw new Error(`Missing original emitter ${key}`);
const sourceBytes = fs.readFileSync(source);
let body = sourceBytes.toString('utf8');
body = replaceOnce(body, 'func main_frames() -> Dictionary:\n\tvar scene:=Node3D.new(); root.add_child(scene)', `func main_frames() -> Dictionary:
	var inventory: Array=JSON.parse_string(FileAccess.get_file_as_string("res://original-emitter-inventory.json"))
	print("ORIGINAL_INVENTORY ",inventory.size()," ",str(inventory[0].source) if not inventory.is_empty() else "empty"," ",str(inventory[0].properties.update)+"|"+str(int(inventory[0].properties.flags)) if not inventory.is_empty() else "empty")
	var profiles: Array=[]
	for key in ["Explosion|82","Fountain|70","Explosion|74","Fountain|98"]:
		var found: Dictionary={}
		for row: Dictionary in inventory:
			if str(row.source)=="plc_i05" and str(row.properties.update)+"|"+str(int(row.properties.flags))==key: found=row.properties; break
		check(not found.is_empty(),"Original plc_i05 authored profile "+key)
		profiles.append(found)
	var scene:=Node3D.new(); root.add_child(scene)`);
body = replaceOnce(body, 'var kind: String=["fountain","explosion","single"][index%3]\n\t\tvar seed_owner:=make_owner(false,kind,32|128|16,false,false)\n\t\tseed_owner.state.renderMode1a8=maxi(index-1,0)\n\t\tif index==0: seed_owner.state.chunkName="private_test_chunk"', `var original: Dictionary=profiles[index%4]
		var kind: String=str(original.update).to_lower()
		var seed_owner:=make_owner(false,kind,int(original.flags),false,false)
		seed_owner.state.renderMode1a8=0
		seed_owner.state.chunkName=str(original.chunkname)
		seed_owner.state.blendMode68=0 if str(original.blend)=="Normal" else 2
		seed_owner.state.twoSided=bool(original.twosidedtex)
		for pair in [["birthrate","birthRate"],["lifeexp","lifeExp"],["particlerot","particleRot"],["blurlength","blurLength"],["velocity","velocity"],["randvel","randomVelocity"],["framestart","frameStart"],["frameend","frameEnd"],["xsize","xSize"],["ysize","ySize"],["spread","spread"],["mass","mass"],["bounce_co","bounceCoefficient"],["sizestart","sizeStart"],["sizeend","sizeEnd"],["sizestart_y","sizeStartY"],["sizeend_y","sizeEndY"],["alphastart","alphaStart"],["alphaend","alphaEnd"],["fps","fps"],["deadspace","deadspace"],["blastradius","blastRadius"],["blastlength","blastLength"]]:
			seed_owner.state[pair[1]]=original[pair[0]]
		seed_owner.state.colorStart=original.colorstart
		seed_owner.state.colorEnd=original.colorend
		seed_owner.state.xGrid=int(original.xgrid)
		seed_owner.state.yGrid=int(original.ygrid)
		seed_owner.state.loop=int(original.loop)
		seed_owner.state.spawnType=int(original.spawntype)`);
body = replaceOnce(body, 'input.patch={"flags":32|128|16,"birthRate":17.0}; input.detonate=index%3==1', 'input.patch={"flags":int(profiles[index%4].flags),"birthRate":float(profiles[index%4].birthrate)}; input.detonate=index%4==0 or index%4==2');
body = replaceOnce(body, '"addPointSourceWind":func(_p,_r,_l,_f):events.append(["wind",index])', '"wind":func(_p,delta):return [delta*0.1,delta*-0.2,0.0],"addPointSourceWind":func(_p,_r,_l,_f):events.append(["wind",index])');
body = replaceOnce(body, 'var rngs: Array=[]; var traces: Array=[[],[]]; var callbacks_by_slot: Array=[[],[]]; var owners: Array=[[],[]]', 'var rngs: Array=[]; var winds: Array=[]; var traces: Array=[[],[]]; var callbacks_by_slot: Array=[[],[]]; var owners: Array=[[],[]]');
body = replaceOnce(body, 'var rng:=Random.new(); rng.seed_value(884); rngs.append(rng)', `var rng:=Random.new(); rng.seed_value(884); rngs.append(rng)
		var wind: RefCounted=ClassDB.instantiate("NwnWindManager")
		var configured_wind: Dictionary=wind.call("dispatch",0,{"seed":18,"wind":[0.8,-0.3,0.0],"deviation":0.15,"pitch":0.08,"timeout":0.5})
		check(not configured_wind.has("error"),"Original-profile scene wind configures "+str(slot)); winds.append(wind)`);
body = replaceOnce(body, 'if index==0: providers.merge(chunks(traces[slot]),true)', 'if index%4==0: providers.merge(chunks(traces[slot]),true)');
body = replaceOnce(body, '"source_flags":0,"clip":"constant","clip_length":3.0,"culling":true}', '"source_flags":0,"clip":"constant","clip_length":3.0,"culling":true,"wind_token":winds[1].call("dispatch",6,{})}');
body = replaceOnce(body, 'var expected: Dictionary={}; traces[0].clear(); traces[1].clear()', `var expected: Dictionary={}; traces[0].clear(); traces[1].clear()
		for slot in 2:
			var before_wind: Dictionary=winds[slot].call("dispatch",7,{})
			var advanced_wind: Dictionary=winds[slot].call("dispatch",1,{"delta":delta,"seed":rngs[slot].state})
			check(not advanced_wind.has("error"),"Original-profile wind advances "+str(frame)+"/"+str(slot))
			rngs[slot].state=int(advanced_wind.seed)
			rngs[slot].draws+=int(advanced_wind.draws)-int(before_wind.draws)`);
body = replaceOnce(body, '"capacity":capacities[index],"source_flags":0,"culling":true}', '"capacity":capacities[index],"source_flags":0,"culling":true,"wind_token":winds[0].call("dispatch",6,{})}');
body = replaceOnce(body, 'owners.clear(); presentation=null; scene.free()', 'owners.clear(); presentation=null; winds.clear(); scene.free()');
body = replaceOnce(body, '"scope":"Headless prototype: eight typed moving emitters share one active-only immutable packet, compared with complete existing native state/geometry/RNG across 180 varied-delta frames, all seven quad modes, collisions, chunks, culling, clocks and pause controls. Original-instruction geometry and native sort/admission corpora have separate tests. No actual GPU or whole-scene FPS acceptance."', '"scope":"Original plc_i05 authored emitter fields (four source profiles, fountain/explosion, Normal quad) projected into paired native owners; 180 moving/culling/clock/collision/chunk frames compare exact ordered packet, owner state and RNG with worker enabled. Synthetic pose and callbacks remain; no original model animation, other draw modes, GPU, or FPS acceptance."');
fs.cpSync(base, out, {recursive: true});
fs.writeFileSync(path.join(out, 'tests/geometry_worker_original_witness_test.gd'), body);
fs.copyFileSync(inventory, path.join(out, 'original-emitter-inventory.json'));
const receipt = {source: path.relative(root,source).replaceAll('\\','/'), sourceSha256:sha(sourceBytes), inventory:path.relative(root,inventory).replaceAll('\\','/'), inventorySha256:sha(fs.readFileSync(inventory)), derivedSha256:sha(Buffer.from(body)), binarySha256:sha(fs.readFileSync(path.join(out,'.cache/native-kernel/nwn-particle-kernel.dll'))), originalProfiles:keys, originalSource:'plc_i05', privateProject:out};
fs.writeFileSync(path.join(out,'witness-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify(receipt));
