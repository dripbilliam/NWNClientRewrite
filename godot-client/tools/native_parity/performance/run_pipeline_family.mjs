// Sequential local captured replay. Uses only reviewed immutable capsules.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawn,spawnSync} from 'node:child_process';
const project=path.resolve('godot-client'),label=process.argv[2];
if(!/^pipeline-family-[a-z0-9-]+$/.test(label??''))throw Error('Explicit staged family required');
const folder=path.join(project,'.cache/native-presentation-parity/root',label);
const composition=JSON.parse(fs.readFileSync(path.join(folder,'composition.json')));
const mode=process.argv[3]??'all';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const engine=JSON.parse(fs.readFileSync(composition.variants[0].file)).engine;
if(sha(fs.readFileSync(engine.path))!==engine.sha256)throw Error('Engine changed');
if(mode==='parse'){
 const home=path.join(folder,'parse-b-userdata');fs.mkdirSync(home);
 const args=['--headless','--render-thread','safe','--log-file',path.join(folder,'parse-b.engine.log'),'--path',composition.project,'--check-only','--script','res://native_session_world.gd','--','--entity-api-rest=false','--particle-kernel=gd'];
 const r=spawnSync(engine.path,args,{windowsHide:true,encoding:'utf8',timeout:30000,maxBuffer:1024*1024,env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
 const diagnostics=((r.stdout??'')+'\n'+(r.stderr??'')).split(/\r?\n/).filter(x=>/SCRIPT ERROR|^ERROR:|Parse Error|instances leaked|resources still in use/.test(x));
 const success=r.status===0&&!r.error&&!diagnostics.length;
 fs.writeFileSync(path.join(folder,'parse-b.json'),JSON.stringify({success,exit:r.status,error:r.error?.message,diagnostics,stdout:r.stdout,stderr:r.stderr,args},null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({success,exit:r.status,diagnostics}));process.exit(success?0:1);
}
const variants=mode==='all'?composition.variants:composition.variants.filter(row=>row.name===mode);
if(!variants.length)throw Error('Unknown family mode');
const driver=path.join(project,'tools/replay-native-loading.mjs'),helper=path.join(project,'tools/native_parity/performance/replay_client_capsule.mjs');
const pins={driver:sha(fs.readFileSync(driver)),helper:sha(fs.readFileSync(helper))};
const batch={kind:'sequential-vulkan-native-pipeline-comparison',started:new Date().toISOString(),pins,runs:[],scope:'Each variant uses a fresh prepared and shader/user cache. OS and driver caches uncontrolled. One pair does not establish general FPS improvement.'};
const batchFile=path.join(folder,'graphics-'+mode+'-a.json');if(fs.existsSync(batchFile))throw Error('Existing results preserved');
for(const variant of variants){
 const run=label+'-'+variant.name+'-a',temporary=path.join(os.tmpdir(),'nwn-'+run);fs.mkdirSync(temporary);
 const home=path.join(temporary,'userdata');fs.mkdirSync(home);
 const args=[driver,'--capture='+path.join(process.env.APPDATA,'nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf'),'--generation=2','--client-capsule='+variant.file,'--client-capsule-sha256='+variant.sha256,'--run='+run,'--cache-directory='+path.join(temporary,'prepared'),'--paced','--movement-timing','--profiling=true','--observe-profile=true','--steady-ms=10000'];
 const row={variant:variant.name,run,temporary,started:new Date().toISOString(),publicConnections:0};batch.runs.push(row);fs.writeFileSync(batchFile,JSON.stringify(batch,null,2)+'\n');
 console.log(JSON.stringify({starting:variant.name,run}));
 const child=spawn(process.execPath,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
 child.stdout.on('data',raw=>process.stdout.write(raw));child.stderr.on('data',raw=>process.stderr.write(raw));
 const end=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});
 const reportFile=path.join(project,'reports',run+'.json');const report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null;const n=report?.native;
 Object.assign(row,{finished:new Date().toISOString(),...end,success:report?.success===true,report:reportFile,presentation:n?.presentation_state,intervals:n?.frame_intervals,knownBaseMs:n?.world?.base_scenery_first_known_complete_ms,controlledReceivedMs:n?.world?.controlled_received_ms,playableMs:n?.world?.playable_ms,cameraMs:n?.world?.controlled_camera_bound_ms,baseStream:n?.world?.continuous_base_stream,terrain:n?.world?.terrain,workers:n?.workers_remaining});
 row.driverUnchanged=sha(fs.readFileSync(driver))===pins.driver&&sha(fs.readFileSync(helper))===pins.helper;
 fs.writeFileSync(batchFile,JSON.stringify(batch,null,2)+'\n');
 console.log(JSON.stringify({finished:variant.name,success:row.success,code:end.code,renderer:row.presentation?.method,intervals:row.intervals,baseMs:row.knownBaseMs}));
 if(!row.success||!row.driverUnchanged)throw Error('Strict comparison gate failed; remaining runs held');
}
batch.finished=new Date().toISOString();batch.success=true;fs.writeFileSync(batchFile,JSON.stringify(batch,null,2)+'\n');
