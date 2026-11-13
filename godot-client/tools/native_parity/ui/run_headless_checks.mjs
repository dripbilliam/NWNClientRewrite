// Explicit isolated functional lane only. No source-project import/.godot,
// native outputs, renderer, server or public connection. Not an FPS benchmark.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [label,...requested]=process.argv.slice(2);
const existingKernel=requested[0]==='--existing-kernel';if(existingKernel)requested.shift();
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit fixture label required');
const allowed=['native_parity_camera_fov_test.gd','native_parity_blocker_setting_test.gd','native_parity_conversation_viewport_test.gd','native_parity_door_parser_metadata_test.gd','native_parity_actor_alpha_test.gd','native_parity_actor_alpha_cost_test.gd','native_parity_static_alpha_dispatch_test.gd','native_parity_highlight_material_test.gd','native_parity_highlight_bounds_test.gd','native_parity_highlight_original_test.gd','native_parity_highlight_textured_test.gd','native_parity_highlight_textured_original_test.gd','native_parity_highlight_inline_test.gd','native_parity_highlight_inline_original_test.gd','native_parity_highlight_aabb_test.gd','native_parity_highlight_aabb_original_test.gd'];
const selected=requested.length?requested:allowed;
if(selected.some(name=>!allowed.includes(name))||new Set(selected).size!==selected.length)throw Error('Only owned dedicated fixtures may run');
if(existingKernel&&(selected.length!==1||!['native_parity_actor_alpha_test.gd','native_parity_actor_alpha_cost_test.gd','native_parity_static_alpha_dispatch_test.gd'].includes(selected[0])))throw Error('Approved existing library is only for the dedicated alpha gates');
const folder=path.join(project,'.cache/native-140fps/particles-agent',label),copy=path.join(folder,'project');
await fs.mkdir(folder,{recursive:false});await fs.mkdir(copy);
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const descriptorFile=path.join(project,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json');
const descriptorBytes=await fs.readFile(descriptorFile),descriptor=JSON.parse(descriptorBytes),engine=descriptor.engines.candidate;
if(engine.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a'||hash(await fs.readFile(engine.path))!==engine.sha256)throw Error('Verified private native engine differs');
const pins=[];const seen=new Set();const nativeInputs=[];
async function stage(relative){
 if(seen.has(relative))return;seen.add(relative);
 if(relative==='native/particle_kernel.gdextension')return;
 if(!relative.endsWith('.gd')||relative.includes('..')||path.isAbsolute(relative))throw Error('Only exact GD source closure is allowed: '+relative);
 const from=path.join(project,relative),bytes=await fs.readFile(from),text=bytes.toString('utf8'),target=path.join(copy,relative);
 await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});pins.push({relative,sha256:hash(bytes),bytes:bytes.length});
 const references=[...text.matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g)];
 for(const match of references)await stage(match[1]??match[2]);
}
for(const name of selected)await stage('tests/'+name);
if((selected.includes('native_parity_highlight_original_test.gd')||selected.includes('native_parity_highlight_textured_original_test.gd')||selected.includes('native_parity_highlight_inline_original_test.gd')||selected.includes('native_parity_highlight_aabb_original_test.gd'))){
 const relative='tools/native_parity/highlighting/original_leaf_corpus.json',bytes=await fs.readFile(path.join(project,relative)),target=path.join(copy,relative);
 await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});pins.push({relative,sha256:hash(bytes),bytes:bytes.length});
}
if(existingKernel){
 const parent=path.join(project,'.cache/native-140fps/root/drive-envelope-fenced-v1'),manifestFile=path.join(parent,'manifest.json'),manifest=await fs.readFile(manifestFile);
 if(hash(manifest)!=='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1')throw Error('Approved native parent manifest differs');
 for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll']){
  const source=path.join(parent,'project',relative),bytes=await fs.readFile(source),target=path.join(copy,relative),sha256=hash(bytes);
  if(relative.endsWith('.dll')&&sha256!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Approved existing library differs');
  await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes,{flag:'wx'});nativeInputs.push({relative,source,sha256,bytes:bytes.length});
 }
}
await fs.writeFile(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="NWNParity-'+label+'"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="CodexParity/'+label+'"\n[display]\nwindow/size/viewport_width=1200\nwindow/size/viewport_height=900\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n',{flag:'wx'});
await fs.mkdir(path.join(copy,'.godot'));await fs.writeFile(path.join(copy,'.godot/global_script_class_cache.cfg'),'list=[]\n',{flag:'wx'});
await fs.mkdir(path.join(folder,'userdata'));
const receipt={version:1,kind:'isolated-headless-parity-functional',label,project:copy,sourceProject:project,engine:{...engine,descriptor:descriptorFile,descriptorSha256:hash(descriptorBytes)},pins,nativeInputs,stagedBytes:pins.reduce((sum,row)=>sum+row.bytes,0),sourceProjectImports:0,nativeOutputsCopied:nativeInputs.length,nativeBuilds:0,serverConnections:0,performanceClaim:false,cases:[]};
await fs.writeFile(path.join(folder,'staged.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({stage:folder,files:pins.length,bytes:receipt.stagedBytes,engine:engine.sha256,cases:selected}));
for(const name of selected){
 const base=path.join(folder,name.replace(/\.gd$/,''));
 const args=['--headless','--path',copy,'--log-file',base+'.engine.log','--script','res://tests/'+name];
 if(existingKernel)args.push('--','--existing-kernel');
 const before=Date.now(),child=spawn(engine.path,args,{cwd:copy,windowsHide:true,env:{...process.env,APPDATA:path.join(folder,'userdata'),LOCALAPPDATA:path.join(folder,'userdata'),NWN_PARITY_UI_TEST_DIR:path.join(folder,'userdata')}});
 console.log(JSON.stringify({started:name,pid:child.pid,args}));
 let stdout='',stderr='',timedOut=false;child.stdout.on('data',bytes=>stdout+=bytes.toString());child.stderr.on('data',bytes=>stderr+=bytes.toString());
 const timeout=setTimeout(()=>{timedOut=true;child.kill();},45000);
 const ended=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',(code,signal)=>resolve({code,signal}));});clearTimeout(timeout);
 await fs.writeFile(base+'.stdout.log',stdout);await fs.writeFile(base+'.stderr.log',stderr);
 const lines=stdout.trim().split(/\r?\n/),summary=lines.findLast(line=>/^NATIVE_PARITY_/.test(line))??null;
 const failures=/\b(?:ERROR|SCRIPT ERROR|Parse Error|Compile Error|WARNING):|ObjectDB instances leaked|resources still in use|was never freed/.test(stdout+'\n'+stderr);
 const result={name,pid:child.pid,...ended,timedOut,wallMs:Date.now()-before,summary,engineErrors:failures,stdout:base+'.stdout.log',stderr:base+'.stderr.log',engineLog:base+'.engine.log',success:ended.code===0&&!timedOut&&!failures&&/\b0 failures\s*$/.test(summary??'')};
 receipt.cases.push(result);console.log(JSON.stringify(result));
}
receipt.sourceChanged=[];receipt.privateChanged=[];
for(const pin of pins){if(hash(await fs.readFile(path.join(project,pin.relative)))!==pin.sha256)receipt.sourceChanged.push(pin.relative);if(hash(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)receipt.privateChanged.push(pin.relative);}
for(const pin of nativeInputs){if(hash(await fs.readFile(pin.source))!==pin.sha256)receipt.sourceChanged.push(pin.source);if(hash(await fs.readFile(path.join(copy,pin.relative)))!==pin.sha256)receipt.privateChanged.push(pin.relative);}
receipt.success=receipt.cases.every(row=>row.success)&&receipt.sourceChanged.length===0&&receipt.privateChanged.length===0;
await fs.writeFile(path.join(folder,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({receipt:path.join(folder,'receipt.json'),success:receipt.success,cases:receipt.cases.map(row=>({name:row.name,success:row.success,summary:row.summary})),sourceChanged:receipt.sourceChanged,privateChanged:receipt.privateChanged}));
process.exitCode=receipt.success?0:1;
