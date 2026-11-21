// Paired user-facing frame intervals, without detailed span instrumentation.
import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';import {spawn} from 'node:child_process';
const project=path.resolve('godot-client'),label=process.argv[2];if(!/^pipeline-family-v4-[a-z0-9-]+$/.test(label??''))throw Error('Frozen V4 family required');
const folder=path.join(project,'.cache/native-presentation-parity/root',label),composition=JSON.parse(fs.readFileSync(path.join(folder,'composition.json')));
const output=path.join(folder,'profiling-off-comparison-a.json');if(fs.existsSync(output))throw Error('Prior evidence preserved');
const hash=f=>crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex'),driver=path.join(project,'tools/replay-native-loading.mjs'),helper=path.join(project,'tools/native_parity/performance/replay_client_capsule.mjs');
const pins={driver:hash(driver),helper:hash(helper)},prepared=path.join(os.tmpdir(),'nwn-'+label+'-native-cache-a/prepared');if(!fs.existsSync(prepared))throw Error('Existing shared warm prepared root required');
const capture=path.join(process.env.APPDATA,'nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf'),batch={started:new Date().toISOString(),pins,runs:[],scope:'Same frozen source/lighting/particles; both use the same warm prepared root and fresh userdata/shader homes. Detailed profiling explicitly off, ten-second post-completion interval window. OS/driver caches uncontrolled, single pair.'};
const save=()=>fs.writeFileSync(output,JSON.stringify(batch,null,2)+'\n');save();
for(const name of ['packed','recipe']){
 const variant=composition.variants.find(row=>row.name===name);if(!variant||hash(variant.file)!==variant.sha256)throw Error('Variant changed');
 const run=label+'-'+name+'-profiling-off-a',temporary=path.join(os.tmpdir(),'nwn-'+run);fs.mkdirSync(temporary);const home=path.join(temporary,'userdata');fs.mkdirSync(home);
 const row={name,run,started:new Date().toISOString()};batch.runs.push(row);save();console.log(JSON.stringify({starting:name,profiling:false}));
 const args=[driver,'--capture='+capture,'--generation=2','--client-capsule='+variant.file,'--client-capsule-sha256='+variant.sha256,'--run='+run,'--cache-directory='+prepared,'--paced','--movement-timing','--profiling=false','--observe-profile=false','--steady-ms=10000'];
 const child=spawn(process.execPath,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});child.stdout.on('data',x=>process.stdout.write(x));child.stderr.on('data',x=>process.stderr.write(x));
 const end=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});
 const report=JSON.parse(fs.readFileSync(path.join(project,'reports',run+'.json'))),n=report.native;
 Object.assign(row,{...end,success:report.success===true,presentation:n?.presentation_state,intervals:n?.frame_intervals,entities:n?.world?.entities,tiles:n?.world?.terrain?.tiles,workers:n?.workers_remaining,finished:new Date().toISOString(),sourceDriverUnchanged:hash(driver)===pins.driver&&hash(helper)===pins.helper});save();
 console.log(JSON.stringify({finished:name,success:row.success,profiling:row.presentation?.detailed_profiling,intervals:row.intervals}));
 if(!row.success||row.presentation?.detailed_profiling!==false||!row.sourceDriverUnchanged)throw Error('Profiling-off correctness gate rejected');
}
batch.success=true;batch.finished=new Date().toISOString();save();
