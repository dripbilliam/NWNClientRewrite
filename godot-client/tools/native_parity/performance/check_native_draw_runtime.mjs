import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawnSync} from 'node:child_process';
const root=path.resolve('godot-client'),label=process.argv[2];
if(!/^native-draw-runtime-[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit runtime test label required');
const folder=path.join(root,'.cache/native-presentation-parity/root',label),project=path.join(folder,'project');
if(fs.existsSync(folder))throw Error('Prior test receipt preserved');
fs.mkdirSync(project,{recursive:true});
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const fixture='tests/native_draw_cache_runtime_test.gd',queue=[fixture],seen=new Set(),pins=[];
while(queue.length){
 const relative=queue.shift();if(seen.has(relative))continue;seen.add(relative);
 if(relative.includes('..')||path.isAbsolute(relative)||seen.size>500)throw Error('Unexpected source closure');
 const source=path.join(root,relative),raw=fs.readFileSync(source),target=path.join(project,relative);
 fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,raw,{flag:'wx'});pins.push({relative,source,sha256:sha(raw)});
 for(const found of raw.toString().matchAll(/(?:preload|load)\(\s*["']res:\/\/([^"']+)["']\s*\)|extends\s+["']res:\/\/([^"']+)["']/g))queue.push(found[1]??found[2]);
}
fs.writeFileSync(path.join(project,'project.godot'),'config_version=5\n[application]\nconfig/name="Native draw cache runtime check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
fs.mkdirSync(path.join(project,'.godot'));fs.writeFileSync(path.join(project,'.godot/global_script_class_cache.cfg'),'list=[]\n');
const home=path.join(folder,'userdata');fs.mkdirSync(home);const cacheRoot=fs.mkdtempSync(path.join(os.tmpdir(),label+'-'));
const resultFile=path.join(folder,'result.json');
const engine=path.join(root,'.cache/native-140fps/render-agent/engine-font-atlas-ownership-v1/build-1793998835313/binaries/godot.windows.template_release.x86_64.exe');
const engineSha256='62f54a7f7ff4638987730a246833cea4054779e7cb2a333bb5921fd5b0aea6dc';
if(sha(fs.readFileSync(engine))!==engineSha256)throw Error('Pinned engine differs');
const args=['--headless','--render-thread','safe','--path',project,'--log-file',path.join(folder,'engine.log'),'--script','res://'+fixture,'--','--report='+resultFile,'--cache-root='+cacheRoot,'--native-draw-cache=prepared','--entity-api-rest=false','--particle-kernel=gd'];
const started=new Date().toISOString(),child=spawnSync(engine,args,{windowsHide:true,encoding:'utf8',timeout:90000,maxBuffer:2*1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
fs.writeFileSync(path.join(folder,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(folder,'stderr.log'),child.stderr??'');
let result=null;try{result=JSON.parse(fs.readFileSync(resultFile));}catch{}
const diagnostics=((child.stdout??'')+'\n'+(child.stderr??'')).split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use|Invalid call/.test(line));
const changed=pins.filter(row=>sha(fs.readFileSync(row.source))!==row.sha256||sha(fs.readFileSync(path.join(project,row.relative)))!==row.sha256).map(row=>row.relative);
const success=child.status===0&&!child.error&&result?.success===true&&!diagnostics.length&&!changed.length;
fs.writeFileSync(path.join(folder,'run.json'),JSON.stringify({success,started,finished:new Date().toISOString(),engine,engineSha256,cacheRoot,pins,result,diagnostics,changed,exitCode:child.status,error:child.error?.message??null,args,publicConnections:0,graphics:false,nativeBuilds:0},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success,checks:result?.checks,failures:result?.failures,diagnostics,changed,exitCode:child.status,error:child.error?.message,folder}));process.exitCode=success?0:1;
