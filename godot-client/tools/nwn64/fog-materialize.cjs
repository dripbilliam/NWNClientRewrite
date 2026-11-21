'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),[label,kind='correctness']=process.argv.slice(2),sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');assert(/^fog-fixture-[a-z0-9-]+$/.test(label||''));assert(['correctness','component'].includes(kind));
const base=path.join(project,'.cache/native-live-review/reviewed-arelith-b/project'),baseManifest=fs.readFileSync(path.join(base,'../manifest.json')),expected=new Map(JSON.parse(baseManifest).files.map(row=>[path.relative(base,row.file).replaceAll('\\','/'),row.sha256]));
const emitter='systems/native_render/particle_emitter.gd',before=fs.readFileSync(path.join(project,'.cache/nwn64/fog-early-out-a/before/particle_emitter.gd')),after=fs.readFileSync(path.join(project,emitter));
assert.equal(sha(before),'78751fe54099bb683ca4dc5b26e0627bb28bf95ea2d958017604fd99ea56c747');assert.equal(sha(before),expected.get(emitter));
const needle='if is_instance_valid(owner): preload("res://systems/native_render/native_surface_state.gd").publish_camera';assert.equal(before.toString().split(needle).length,2);
assert.equal(before.toString().replace(needle,'if is_instance_valid(owner) and not preload("res://systems/native_render/native_surface_state.gd").authoritative(owner): preload("res://systems/native_render/native_surface_state.gd").publish_camera'),after.toString(),'Candidate must be exactly the approved one-line edit');
const root=path.join(project,'.cache/nwn64',label);assert(!fs.existsSync(root));const legs=[];
for(const [mode,sourceEmitter]of [['before',before],['after',after]]){
 const view=path.join(root,mode,'project'),pins=[],copied=new Set();fs.mkdirSync(view,{recursive:true});
 function put(relative,bytes,origin){const file=path.join(view,relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});pins.push({relative,bytes:bytes.length,sha256:sha(bytes),origin});}
 function copy(relative){
  if(copied.has(relative))return;assert(relative&&!relative.includes('..')&&!path.isAbsolute(relative));copied.add(relative);
  let bytes,origin;
  if(relative.startsWith('tests/nwn64_fog')){bytes=fs.readFileSync(path.join(project,relative));origin='owned fixture';}
  else if(relative===emitter){bytes=sourceEmitter;origin=mode+' exact complete emitter';}
  else{bytes=fs.readFileSync(path.join(base,relative));assert.equal(sha(bytes),expected.get(relative),'Frozen reviewedB dependency changed: '+relative);origin='frozen reviewedB';}
  if(relative==='systems/native_render/particle_stream_fog.gd'&&kind==='correctness'){
   let text=bytes.toString(),anchor='static func sample(camera: Camera3D,native_surface_output: bool=false,owner: Node=null) -> Array:\n';assert.equal(text.split(anchor).length,2);
   text=text.replace(anchor,anchor+'\tpreload("res://tests/nwn64_fog_probe.gd").samples+=1\n');bytes=Buffer.from(text);origin+=' plus declared test-only sample counter';
  }
  put(relative,bytes,origin);
  if(relative.endsWith('.gd')){
   for(const m of bytes.toString().matchAll(/(?:preload|load)\("res:\/\/([^"\n]+)"\)|extends\s+"res:\/\/([^"\n]+)"/g))copy(m[1]??m[2]);
   for(const m of bytes.toString().matchAll(/["']res:\/\/([^"'\n]+\.(?:json|gdshader|gdshaderinc))["']/g))if(expected.has(m[1]))copy(m[1]);
  }
 }
 copy(kind==='correctness'?'tests/nwn64_fog_test.gd':'tests/nwn64_fog_component.gd');
 const dll=fs.readFileSync(path.join(base,'.cache/native-kernel/nwn-particle-kernel.dll'));assert.equal(sha(dll),'485741af15f0581a3c60c0f9a8ae738888eba08716c7a5c2c2d1bd550828963d');put('.cache/native-kernel/nwn-particle-kernel.dll',dll,'unchanged accepted DLL private copy');copy('native/particle_kernel.gdextension');
 put('project.godot',Buffer.from('config_version=5\n[application]\nconfig/name="NWN64 actual fog tick prefix"\n[display]\nwindow/size/viewport_width=640\nwindow/size/viewport_height=360\nwindow/size/no_focus=true\n'),'private fixture');
 put('.godot/global_script_class_cache.cfg',Buffer.from('list=[]\n'),'isolated class cache');put('.godot/extension_list.cfg',Buffer.from('res://native/particle_kernel.gdextension\n'),'accepted extension only');
 legs.push({mode,project:view,pins,emitterSHA256:sha(sourceEmitter)});
}
const manifest={issue:'NWN-64',kind,baseManifestSHA256:sha(baseManifest),legs,scope:'Actual complete before/after emitter, original reviewedB dependencies and accepted DLL. Fixture _ready override; '+(kind==='correctness'?'explicitly instrumented Fog.sample counter.':'Fog.sample byte-exact original and uninstrumented.')+' No complete simulation, FPS or runtime/default acceptance.'};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file:path.join(root,'manifest.json'),sha256:sha(fs.readFileSync(path.join(root,'manifest.json'))),legs:legs.map(v=>({mode:v.mode,project:v.project,files:v.pins.length}))}));
