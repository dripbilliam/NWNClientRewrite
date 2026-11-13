// Isolated actual source/worker/physical-Part test. No native build/GPU/server.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
const root=process.cwd(),source=path.join(root,'godot-client');
const run=path.resolve(process.argv[2]??''),boundary=path.join(source,'.cache/native-presentation-parity/render-agent')+path.sep;
if(!run.startsWith(boundary)||fs.existsSync(run))throw Error('Fresh owned fixture output required');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const descriptorFile=path.join(source,'.cache/native-140fps/render-agent/engine-builtin-light-v2/engine-descriptor.json');
const descriptorBytes=fs.readFileSync(descriptorFile),engine=JSON.parse(descriptorBytes).engines.candidate;
if(engine.sha256!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a'||hash(fs.readFileSync(engine.path))!==engine.sha256)throw Error('Engine pin mismatch');
const project=path.join(run,'project'),pins=[],seen=new Set();let total=0;
function stage(relative){
 if(seen.has(relative))return;seen.add(relative);
 if(relative==='native/particle_kernel.gdextension')return;
 if(!relative.endsWith('.gd')||relative.includes('..')||path.isAbsolute(relative))throw Error('Unexpected source closure '+relative);
 const bytes=fs.readFileSync(path.join(source,relative)),text=bytes.toString('utf8');
 total+=bytes.length;if(pins.length>=2048||total>24*1024*1024)throw Error('Source closure exceeds explicit bound');
 const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
 pins.push({relative,sha256:hash(bytes),bytes:bytes.length});
 for(const match of text.matchAll(/["']res:\/\/([^"'\n]+\.gd)["']/g))stage(match[1]);
}
stage('tests/native_transition_door_hover_test.gd');
const nativeParent=path.join(source,'.cache/native-140fps/root/drive-envelope-fenced-v1');
if(hash(fs.readFileSync(path.join(nativeParent,'manifest.json')))!=='cce71cea6e3ae8116d4747c97f1e161eed9350cd85386dc372578d9f6d4cdfc1')throw Error('Frozen DLL parent manifest mismatch');
const native=[];
for(const relative of ['native/particle_kernel.gdextension','.cache/native-kernel/nwn-particle-kernel.dll']){
 const from=path.join(nativeParent,'project',relative),bytes=fs.readFileSync(from),sha256=hash(bytes);
 if(relative.endsWith('.dll')&&sha256!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea')throw Error('Frozen DLL mismatch');
 const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});native.push({relative,source:from,sha256,bytes:bytes.length});
}
fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="Isolated original transition door rig"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="NWNParityDoorHover-'+path.basename(run)+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
const install=path.resolve(root,'../FullDecomp/NwnRootInstall'),cache=path.join(run,'private-cache');fs.mkdirSync(cache);
const changed=()=>pins.filter(p=>hash(fs.readFileSync(path.join(source,p.relative)))!==p.sha256).map(p=>p.relative);
if(changed().length)throw Error('Source changed while staging');
fs.writeFileSync(path.join(run,'sources.json'),JSON.stringify({source,project,pins,native,engine,descriptorSha256:hash(descriptorBytes),bytes:total,scope:'Two installed original binary doors via native worker, Runs, compiled NativePose and physical target bounds; controller-unavailable fallback. ASCII Trans remains unmet. No native build or server/GPU.'},null,2));
const args=['--headless','--path',project,'--log-file',path.join(run,'engine.log'),'--script','res://tests/native_transition_door_hover_test.gd','--',`--install=${install}`,`--cache=${cache}`,`--report=${path.join(run,'checks.json')}`];
const child=spawn(engine.path,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});let stdout='',stderr='',error=null,timedOut=false;
child.stdout.on('data',v=>stdout+=v);child.stderr.on('data',v=>stderr+=v);child.on('error',e=>error=String(e));
console.log(JSON.stringify({started:child.pid,project,files:pins.length,bytes:total}));
const timeout=setTimeout(()=>{timedOut=true;child.kill();},45000);
const exit=await new Promise(resolve=>child.once('close',(code,signal)=>resolve({code,signal})));clearTimeout(timeout);
const sourceChanged=changed();for(const n of native)if(hash(fs.readFileSync(n.source))!==n.sha256)sourceChanged.push(n.source);
const engineErrors=/\b(?:ERROR|SCRIPT ERROR|Parse Error|Compile Error|WARNING):|ObjectDB instances leaked|resources still in use|was never freed/.test(stdout+'\n'+stderr);
const receipt={...exit,pid:child.pid,args,error,timedOut,engineErrors,sourceChanged,engineSha256:engine.sha256,nativeSha256:native.find(n=>n.relative.endsWith('.dll')).sha256};
fs.writeFileSync(path.join(run,'process.json'),JSON.stringify(receipt,null,2));fs.writeFileSync(path.join(run,'stdout.log'),stdout);fs.writeFileSync(path.join(run,'stderr.log'),stderr);
console.log(JSON.stringify(receipt));console.log(stdout);console.log(stderr);process.exitCode=exit.code===0&&!timedOut&&!engineErrors&&!sourceChanged.length?0:1;
