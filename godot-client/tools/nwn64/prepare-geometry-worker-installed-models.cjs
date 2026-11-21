const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const root = path.resolve(__dirname, '../..');
const base = path.join(root, '.cache/particle-geometry-worker/candidate-e/fixture');
const label = process.argv[2];
if (!/^[a-z]$/.test(label ?? '')) throw new Error('Fresh private stage letter required');
const out = path.join(root, `.cache/nwn64/geometry-worker-installed-${label}`);
if (fs.existsSync(out)) throw new Error('Private stage already exists');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const pins = [];
const visited = new Set();
function copy(relative) {
  if (visited.has(relative)) return;
  visited.add(relative);
  const source = path.join(root, relative);
  const bytes = fs.readFileSync(source);
  const target = path.join(out, relative);
  fs.mkdirSync(path.dirname(target), {recursive:true});
  fs.writeFileSync(target, bytes);
  pins.push({relative,sha256:sha(bytes)});
  if (/\.(gd|gdshader|gdshaderinc)$/.test(relative)) {
    for (const match of bytes.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']|extends\s*["']res:\/\/([^"']+)["']|#include\s*["']res:\/\/([^"']+)["']/g)) copy(match[1] ?? match[2] ?? match[3]);
  }
}
function replaceOnce(body, from, to) {
  if (body.split(from).length !== 2) throw new Error(`Expected one marker: ${from.slice(0,60)}`);
  return body.replace(from,to);
}
fs.cpSync(base, out, {recursive:true});
const relative = 'tests/native_perf140_particle_native_random_models_test.gd';
copy(relative);
let body = fs.readFileSync(path.join(out,relative),'utf8');
body = replaceOnce(body, '"presentation":ClassDB.instantiate("NwnParticlePresentation"),"owners":[]', '"presentation":ClassDB.instantiate("NwnParticlePresentation"),"worker":native_rng,"owners":[]');
body = replaceOnce(body, 'ClassDB.instantiate("NwnVisualRandom") if native_rng else Random.new()', 'Random.new()');
body = replaceOnce(body, '"profile":true}))', '"profile":true,"geometry_worker":bool(row.worker)}))');
body = replaceOnce(body, '["it_torch_000","plc_cndl01","plc_x0_drt"]', '["it_torch_000","plc_cndl01","plc_x0_drt","c_goldem","plc_v02","plc_i10","tnp_gmist","plc_u09"]');
body = replaceOnce(body, 'var observations: Array=[];var total_emitters:=0', 'var observations: Array=[];var unsupported: Array=[];var total_emitters:=0');
body = replaceOnce(body, 'if kind not in ["fountain","explosion","single"] or (int(parameters.get("flags",0))&1)!=0:continue', `if kind not in ["fountain","explosion","single"] or (int(parameters.get("flags",0))&1)!=0 or not Emitter.MODES.has(str(parameters.get("render","Normal"))):
					if row==rows[0]:unsupported.append({"model":name,"node":str(original.name),"update":kind,"render":str(parameters.get("render","")),"flags":int(parameters.get("flags",0))})
					continue`);
body = replaceOnce(body, 'observations.append({"name":name,"sha256":Cache.digest(bytes),"physical_nodes":model.nodes.size(),"supported_emitters":model_emitters})', `var authored_profiles: Array=[]
		for original: Dictionary in model.nodes:
			if original.has("emitter"):authored_profiles.append({"node":str(original.name),"update":str(original.emitter.get("update","")),"render":str(original.emitter.get("render","")),"flags":int(original.emitter.get("flags",0)),"chunk":not str(original.emitter.get("chunkname","")).is_empty()})
		observations.append({"name":name,"sha256":Cache.digest(bytes),"physical_nodes":model.nodes.size(),"supported_emitters":model_emitters,"authored_profiles":authored_profiles})`);
body = replaceOnce(body, 'check(a.buffer==b.buffer and outputs[0].active==outputs[1].active,"Exact actual-model geometry/admission "+str(frame))', `check(a.buffer==b.buffer and outputs[0].active==outputs[1].active,"Exact actual-model geometry/admission "+str(frame))
		check(a.ranges.size()==b.ranges.size(),"Exact actual-model ordered range count "+str(frame))
		for range_index in mini(a.ranges.size(),b.ranges.size()):
			var left: Dictionary=a.ranges[range_index];var right: Dictionary=b.ranges[range_index]
			check(left.first==right.first and left.count==right.count and left.bounds==right.bounds,"Exact actual-model ordered range "+str(frame)+"/"+str(range_index))`);
body = replaceOnce(body, 'var draws: int=rows[1].rng.draws;var direct_hits: int=rows[1].rng.snapshot().direct_hits', `var worker_stats: Dictionary=rows[1].presentation.call("dispatch",7,{})
	check(int(worker_stats.get("geometry_worker_frames",0))>0,"Original installed model fixture executed real geometry worker")
	var draws: int=rows[1].rng.draws;var direct_hits: int=0`);
body = replaceOnce(body, 'check(rows[1].rng.snapshot().direct_hits>0,"Actual installed models use guarded native draws")', 'check(rows[1].rng.draws>0,"Actual installed models draw the shared visual RNG")');
body = replaceOnce(body, '"native_direct_hits":direct_hits,"network_connections":0', '"native_direct_hits":direct_hits,"worker_frames":worker_stats.get("geometry_worker_frames",0),"worker_vertices":worker_stats.get("geometry_worker_vertices",0),"unsupported":unsupported,"network_connections":0');
body = replaceOnce(body, '"scope":"Installed MDL fields/TRS/controller pools with exact native-vs-GD shared visual RNG state and CPU geometry; deterministic chunk service boundary stand-ins, no texture/child-Gob/GPU visual claim."', '"scope":"Private OFF/ON geometry-worker pair over eight installed original MDLs and their authored emitter fields/TRS/controller pools; exact ordered native packet/state/RNG/service callbacks and worker execution. Controlled chunk callbacks and clip authority; no texture/child-Gob/GPU/FPS claim."');
fs.writeFileSync(path.join(out,'tests/geometry_worker_installed_models_test.gd'),body);
const binary = fs.readFileSync(path.join(out,'.cache/native-kernel/nwn-particle-kernel.dll'));
const receipt = {privateProject:out,derivedFrom:relative,derivedSha256:sha(Buffer.from(body)),binarySha256:sha(binary),pins,sourceWritesOutsideStage:0};
fs.writeFileSync(path.join(out,'installed-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({privateProject:out,derivedSha256:receipt.derivedSha256,binarySha256:receipt.binarySha256,files:pins.length}));
