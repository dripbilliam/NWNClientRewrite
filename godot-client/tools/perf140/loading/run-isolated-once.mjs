import fs from 'node:fs';import path from 'node:path';import {spawn} from 'node:child_process';import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';
export const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
export function createCapsule(label,parentLabel,script,variant='candidate'){
 if(!/^(?:raster-payload-census|raster-child|static-actor-route|raster-write-queue|bulk-float-stream|combined-loading)-[a-z0-9-]+$/.test(label)||!/^(?:processor-identity|raster-child|static-actor-route|raster-write-queue|bulk-float-stream|combined-loading)-[a-z0-9-]+$/.test(parentLabel)||!['baseline','candidate'].includes(variant))throw Error('Fresh owned functional capsule and pinned processor parent required');
 const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');
 const manifestFile=path.join(project,'.cache/native-140fps/loading-agent',parentLabel,'manifest.json'),manifestBytes=fs.readFileSync(manifestFile),manifest=JSON.parse(manifestBytes),copy=path.join(stage,'project'),pins=new Map(manifest.pins.map(v=>[v.relative,v.sha256]));
 for(const row of manifest.changed)if(variant==='candidate'||row.before!==null)pins.set(row.relative,variant==='candidate'?row.after:row.before);
 for(const row of manifest.fixtures??(manifest.fixture?[manifest.fixture]:[]))pins.set(row.relative,row.sha256);
 const sourceRoot=manifest[variant];fs.mkdirSync(copy,{recursive:true});for(const [relative,sha256] of pins){const file=path.join(sourceRoot,relative),bytes=fs.readFileSync(file);if(digest(bytes)!==sha256)throw Error('Frozen candidate source differs: '+relative);const target=path.join(copy,relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);}
 fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Asset Functional Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 const scriptBytes=fs.readFileSync(path.join(project,'tests',script));fs.writeFileSync(path.join(copy,'tests',script),scriptBytes);
 return {stage,copy,sourceRoot,variant,manifest,manifestFile,manifestSha256:digest(manifestBytes),script,scriptSha256:digest(scriptBytes),pins};
}
export async function runHeadless(capsule,args,timeoutMs=40000,directory=''){
 if(directory&&!/^[a-z][a-z0-9-]*$/.test(directory))throw Error('Fresh process output directory required');
 const output=directory?path.join(capsule.stage,directory):capsule.stage;if(directory){if(fs.existsSync(output))throw Error('Existing process evidence preserved');fs.mkdirSync(output);}
 const engine=path.join(project,'.tools/Godot_v4.7.2-stable_win64.exe'),engineSha256=digest(fs.readFileSync(engine));if(engineSha256!=='ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424')throw Error('Pinned engine differs');
 const app=path.join(output,'appdata'),local=path.join(output,'localappdata');fs.mkdirSync(app);fs.mkdirSync(local);const log=path.join(output,'engine.log'),proofFile=path.join(output,'proof.json'),processStartedAt=new Date().toISOString(),processBegan=performance.now();
 const outcome=await new Promise(resolve=>{const child=spawn(engine,['--headless','--path',capsule.copy,'--log-file',log,'--script','res://tests/'+capsule.script,'--',...args,'--report='+proofFile],{cwd:capsule.copy,windowsHide:true,env:{...process.env,APPDATA:app,LOCALAPPDATA:local},stdio:['ignore','pipe','pipe']});let stdout='',stderr='',error=null,killed=false,total=0;
  const collect=(which,b)=>{total+=b.length;if(total>2*1024*1024){error='Owned output exceeds 2 MiB';killed=true;child.kill();return;}if(which==='out')stdout+=b;else stderr+=b;};child.stdout.on('data',b=>collect('out',b));child.stderr.on('data',b=>collect('err',b));child.once('error',e=>error=e.message);const timer=setTimeout(()=>{error='Owned headless gate timeout';killed=true;child.kill();},timeoutMs);child.once('close',(exitCode,signal)=>{clearTimeout(timer);resolve({pid:child.pid,exitCode,signal,error,killed,stdout,stderr});});});
 const processElapsedMs=performance.now()-processBegan,processEndedAt=new Date().toISOString();fs.writeFileSync(path.join(output,'stdout.log'),outcome.stdout);fs.writeFileSync(path.join(output,'stderr.log'),outcome.stderr);let proof=null;try{proof=JSON.parse(fs.readFileSync(proofFile));}catch{}
 const text=(fs.existsSync(log)?fs.readFileSync(log,'utf8'):'')+'\n'+outcome.stderr,engineClean=!/SCRIPT ERROR|Parse Error|^ERROR:|WARNING:|ObjectDB.*leak|resources still in use/m.test(text);
 return {success:outcome.exitCode===0&&!outcome.signal&&!outcome.error&&!outcome.killed&&engineClean&&proof?.success===true,engineClean,proof,engineSha256,processElapsedMs,processStartedAt,processEndedAt,outcome:{...outcome,stdout:undefined,stderr:undefined}};
}
export function parentDrift(capsule){return [...capsule.pins].filter(([relative,sha256])=>digest(fs.readFileSync(path.join(capsule.sourceRoot,relative)))!==sha256).map(([relative])=>relative);}
