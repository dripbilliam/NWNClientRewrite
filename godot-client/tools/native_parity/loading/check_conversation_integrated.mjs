import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),root=path.dirname(source);
const [label,mode,phase]=process.argv.slice(2);
const originalAssets=process.argv.includes('--original-assets');
const pixelFixture=process.argv.includes('--pixels');
const profileOverrides=process.argv.includes('--profile-overrides');
const renderThread=process.argv.includes('--safe-render-thread')?'safe':'separate';
if(!/^conversation-integrated-[a-z0-9-]+$/.test(label??'')||!['baseline','current'].includes(mode)||!['stage','run','parse','graphics'].includes(phase))throw Error('Fresh label baseline/current stage/run/parse/graphics required');
const folder=path.join(source,'.cache/native-presentation-parity/loading-agent',label),project=path.join(folder,'project');
const parentFile=path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v2/manifest.json');
const parent=JSON.parse(fs.readFileSync(parentFile));
const hash=raw=>crypto.createHash('sha256').update(raw).digest('hex');
if(hash(fs.readFileSync(parentFile))!=='c82135844d8e779d8dc930f89a9eb626317844b0e65d921633f1461169f8b59b')throw Error('Active capsule parent changed');
const test=pixelFixture?'tests/native_parity_conversation_pixels_test.gd':'tests/native_parity_conversation_integrated_test.gd',frame='systems/native_conversation_frame.gd';
const currentFiles=new Set([frame,'systems/native_data/conversation_layout.gd','tools/native_parity/ui/conversation_viewport.gd']);
if(phase==='stage'){
 if(fs.existsSync(folder))throw Error('Existing evidence preserved');fs.mkdirSync(project,{recursive:true});
 const pins=[],seen=new Set(),queue=[test,...(pixelFixture?['systems/native_data/feedback_descriptors.json']:[])];let bytes=0;
 while(queue.length){
  const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
  if(relative.includes('..')||seen.size>800)throw Error('Unexpected source closure');
  const file=path.join(relative===test||mode==='current'&&currentFiles.has(relative)?source:parent.project,relative),raw=fs.readFileSync(file);bytes+=raw.length;
  if(bytes>8*1024*1024)throw Error('Bounded closure exceeds8MiB');
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);pins.push({relative,source:file,sha256:hash(raw)});
  if(relative.endsWith('.gd'))for(const match of raw.toString('utf8').matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(match[1]??match[2]);
 }
 if(pixelFixture){
  const relative='.cache/native-kernel/nwn-particle-kernel.dll',raw=fs.readFileSync(path.join(parent.project,relative));
  if(hash(raw)!==parent.nativeBinary.sha256)throw Error('Matched native DLL differs');
  const target=path.join(project,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw);pins.push({relative,source:path.join(parent.project,relative),sha256:hash(raw)});
 }
 const config='config_version=5\n[application]\nconfig/name="Integrated conversation correctness check"\n[display]\nwindow/size/viewport_width=1280\nwindow/size/viewport_height=800\nwindow/size/no_focus=true\nwindow/size/initial_position_type=3\nwindow/size/initial_screen=2\n[rendering]\nrenderer/rendering_method="'+(pixelFixture?'forward_plus':'gl_compatibility')+'"\n';
 fs.writeFileSync(path.join(project,'project.godot'),config);pins.push({relative:'project.godot',sha256:hash(config)});
 fs.mkdirSync(path.join(project,'.godot'),{recursive:true});fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
 const override=profileOverrides?path.join(process.env.USERPROFILE,'Documents/Neverwinter Nights.0/override'):null;
 const resourcePins=override?['pnl_dialog.mdl','ctl_dialog_entry.mdl','ctl_dialog_reply.mdl'].map(name=>{const file=path.join(override,name),raw=fs.readFileSync(file);return {file,bytes:raw.length,sha256:hash(raw)};}):[];
 fs.writeFileSync(path.join(folder,'stage.json'),JSON.stringify({label,mode,project,test,pins,bytes,originalAssets,pixelFixture,renderThread,override,resourcePins,install:path.resolve(root,'../FullDecomp/NwnRootInstall'),parent:{file:parentFile,sha256:hash(fs.readFileSync(parentFile))},engine:parent.engine,serverConnections:0,gpuDraws:0,nativeBuilds:0},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage:true,pins:pins.length,bytes,folder}));process.exit(0);
}
const output=path.join(folder,phase==='parse'?'parse.json':'run.json');if(fs.existsSync(output))throw Error('Existing run preserved');
const stage=JSON.parse(fs.readFileSync(path.join(folder,'stage.json')));
if(phase==='graphics'&&(!stage.pixelFixture||!process.argv.includes('--graphics-authorized')))throw Error('Explicit scheduled graphical fixture authorization required');
if(phase==='run'&&stage.pixelFixture)throw Error('Pixel fixture requires explicit graphics phase; parse is separately headless');
const changed=()=>stage.pins.filter(pin=>hash(fs.readFileSync(path.join(project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
if(changed().length||hash(fs.readFileSync(stage.engine.path))!==stage.engine.sha256)throw Error('Stage or ce2d engine differs');
const resultFile=path.join(folder,'result.json'),home=path.join(folder,'userdata');fs.mkdirSync(home,{recursive:true});
const args=[...(phase==='graphics'?['--render-thread',stage.renderThread??'separate','--rendering-method','forward_plus']:['--headless']),...(phase==='parse'?['--check-only']:[]),'--log-file',path.join(folder,phase==='parse'?'parse.engine.log':'engine.log'),'--path',project,'--script','res://'+stage.test,'--','--report='+resultFile];
if(stage.originalAssets)args.push('--install='+stage.install,'--cache='+path.join(folder,'prepared'),'--prepared-cache-write=sync','--particle-kernel=gd');
if(stage.override)args.push('--override='+stage.override);
const started=new Date().toISOString(),child=spawnSync(stage.engine.path,args,{cwd:root,encoding:'utf8',windowsHide:true,timeout:phase==='graphics'?120000:15000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(folder,phase==='parse'?'parse.stdout.log':'stdout.log'),stdout,{flag:'wx'});fs.writeFileSync(path.join(folder,phase==='parse'?'parse.stderr.log':'stderr.log'),stderr,{flag:'wx'});
const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
let result=null;try{result=JSON.parse(fs.readFileSync(resultFile));}catch{}
const sourceChanged=changed(),resourceChanged=(stage.resourcePins??[]).filter(pin=>hash(fs.readFileSync(pin.file))!==pin.sha256).map(pin=>pin.file),success=child.status===0&&!child.error&&!errors.length&&(phase==='parse'||result?.success===true)&&!sourceChanged.length&&!resourceChanged.length;
fs.writeFileSync(output,JSON.stringify({success,label,mode,started,finished:new Date().toISOString(),stage:{file:path.join(folder,'stage.json'),sha256:hash(fs.readFileSync(path.join(folder,'stage.json')))},engine:stage.engine,exit:child.status,error:child.error?.message??null,errors,sourceChanged,resourceChanged,result,serverConnections:0,nativeBuilds:0,gpuDraws:phase==='graphics'?'functional-only':0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,checks:result?.checks,failures:result?.failures,errors,error:child.error?.message??null,exit:child.status,receipt:output}));process.exit(success?0:1);
