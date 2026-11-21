'use strict';
// Isolated pure-kernel runner. No world/actor/rig/UI preload and no shared DLL.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),[label,binaryArg,receiptArg]=process.argv.slice(2),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert(/^[a-z0-9-]+$/.test(label??''));assert(binaryArg&&receiptArg);
const binary=path.resolve(project,binaryArg),bytes=fs.readFileSync(binary);let sourceProof;
if(receiptArg==='accepted'){assert.equal(sha(bytes),'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');sourceProof={accepted:true,file:binary,sha256:sha(bytes)};}
else{const receipt=path.resolve(project,receiptArg),proofBytes=fs.readFileSync(receipt),proof=JSON.parse(proofBytes.toString().replace(/^\uFEFF/,''));assert(proof.success);assert.equal(sha(bytes),proof.binarySha256);assert.equal(path.resolve(proof.binary),binary);sourceProof={file:receipt,sha256:sha(proofBytes),compiler:proof.compilerSha256,flags:proof.flags,sourcePins:proof.sourcePins};}
const out=path.join(project,'.cache/nwn64',label),view=path.join(out,'project');assert(!fs.existsSync(out));fs.mkdirSync(view,{recursive:true});const copied=new Map(),oracles=new Set();
function put(relative,data){const target=path.join(view,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,data,{flag:'wx'});copied.set(relative,{relative,bytes:data.length,sha256:sha(data)});}
function copy(relative){
 assert(!relative.startsWith('/')&&!relative.includes('..')&&!relative.includes('\\'));
 assert(!/(?:actor_instance|model_rigs|skeletal_rigs|live_world|resource_pool|creature_stream|native_session_world|native_live_world|native-godot-particles)/.test(relative),'Unvalidated world/renderer dependency forbidden: '+relative);
 if(copied.has(relative))return;const b=fs.readFileSync(path.join(project,relative));put(relative,b);
 if(!relative.endsWith('.gd'))return;const source=b.toString();
 for(const match of source.matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)|extends\s+"res:\/\/([^"\n]+)"/g))copy(match[1]??match[2]);
 for(const match of source.matchAll(/(?:original|update_tests)\("([^"\n]+)"/g))oracles.add(match[1]);
}
for(const r of ['tests/nwn64_resident_test.gd','tests/nwn64_compact_vertices_test.gd','tests/nwn64_resident_chunks_test.gd','tests/nwn64_typed_pose_test.gd','tests/nwn64_busy_test.gd','tests/nwn64_busy_diagnostic_test.gd','tests/nwn64_phase_test.gd','tests/nwn64_shared_phase_test.gd'])copy(r);
put('project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="NWN64 private kernel tests"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'));
if(!copied.has('native/particle_kernel.gdextension'))copy('native/particle_kernel.gdextension');
put('.cache/native-kernel/nwn-particle-kernel.dll',bytes);
// Native-pose fixtures instantiate their class directly; preserve normal
// extension auto-loading, bound only to this private project's copied DLL.
put('.godot/extension_list.cfg',Buffer.from('res://native/particle_kernel.gdextension\n'));
put('.godot/global_script_class_cache.cfg',Buffer.from('list=[]\n'));
const oraclePins=[];for(const name of oracles){assert(/^[a-z0-9-]+$/.test(name));const source=path.join(project,'../backups/animations',name+'.json'),b=fs.readFileSync(source),target=path.join(out,'backups/animations',name+'.json');fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,b,{flag:'wx'});oraclePins.push({name,sha256:sha(b),bytes:b.length});}
const receipt={version:1,issue:'NWN-64',project:view,nativeBinarySha256:sha(bytes),sourceProof,files:[...copied.values()],oracles:oraclePins,scope:'Frozen pure-kernel source closure and private DLL. No shared extension list, original assets, world/UI/actor modules or live connection.'};
const file=path.join(out,'manifest.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(fs.readFileSync(file)),project:view,nativeBinarySha256:receipt.nativeBinarySha256,files:copied.size,oracles:oraclePins.length}));
