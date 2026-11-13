import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';import {spawn} from 'node:child_process';
const project=path.resolve('godot-client'),label=process.argv[2];if(!/^pipeline-family-v[34]-[a-z0-9-]+$/.test(label??''))throw Error('Fresh frozen V3/V4 family required');
const folder=path.join(project,'.cache/native-presentation-parity/root',label),composition=JSON.parse(fs.readFileSync(path.join(folder,'composition.json')));
if(composition.version!==Number(/^pipeline-family-v([34])-/.exec(label)[1]))throw Error('Family version differs');
const batchFile=path.join(folder,'cache-comparison-a.json');if(fs.existsSync(batchFile))throw Error('Previous batch retained');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const driver=path.join(project,'tools/replay-native-loading.mjs'),helper=path.join(project,'tools/native_parity/performance/replay_client_capsule.mjs'),pins={driver:hash(driver),helper:hash(helper)};
const capture=path.join(process.env.APPDATA,'nwn-model-viewer-research/native-loading-recordings/capture-YaH3xf');
const runs=composition.version===4?[['packed','packed-cold'],['recipe','recipe-cold'],['cache','cache-cold'],['recipe','legacy-warm-control'],['cache','cache-warm']]:[['terrain','terrain-cold'],['scenery','scenery-cold'],['cache','cache-cold'],['scenery','legacy-warm-control'],['cache','cache-warm']];
const cacheDirectory=path.join(os.tmpdir(),'nwn-'+label+'-native-cache-a','prepared');if(fs.existsSync(path.dirname(cacheDirectory)))throw Error('Fresh native cache comparison directory required');
const batch={version:1,kind:'sequential-vulkan-static-and-native-draw-cache-comparison',started:new Date().toISOString(),pins,runs:[],scope:'Cold variants use fresh application caches. Both warm cases share the exact cache-cold prepared root, so legacy prepared data is warm in both. User/shader homes are fresh; OS/driver caches uncontrolled. Single ordered pairs do not prove general FPS improvement.'};
const save=()=>fs.writeFileSync(batchFile,JSON.stringify(batch,null,2)+'\n');save();
function inventory(root){let files=0,bytes=0,resources=0,resourceBytes=0;if(!fs.existsSync(root))return{files,bytes,resources,resourceBytes};const pending=[root];while(pending.length){for(const entry of fs.readdirSync(pending.pop(),{withFileTypes:true})){const f=path.join(entry.parentPath,entry.name);if(entry.isDirectory())pending.push(f);else if(entry.isFile()){const size=fs.statSync(f).size;files++;bytes+=size;if(entry.name.endsWith('.res')){resources++;resourceBytes+=size;}}}}return{files,bytes,resources,resourceBytes};}
for(const [variantName,caseName]of runs){
 const variant=composition.variants.find(row=>row.name===variantName);if(!variant||hash(variant.file)!==variant.sha256)throw Error('Variant differs');
 const run=label+'-'+caseName+'-a',temporary=path.join(os.tmpdir(),'nwn-'+run);fs.mkdirSync(temporary);const home=path.join(temporary,'userdata');fs.mkdirSync(home);
 const prepared=caseName==='cache-cold'||caseName.includes('warm')?cacheDirectory:path.join(temporary,'prepared');
 const nativeDirectory=path.join(prepared,'godot-prepared-resources-v1');
 const row={variant:variantName,case:caseName,run,prepared,temporary,started:new Date().toISOString(),beforeNativeCache:inventory(nativeDirectory),publicConnections:0};batch.runs.push(row);save();
 console.log(JSON.stringify({starting:caseName,run}));
 const args=[driver,'--capture='+capture,'--generation=2','--client-capsule='+variant.file,'--client-capsule-sha256='+variant.sha256,'--run='+run,'--cache-directory='+prepared,'--paced','--movement-timing','--profiling=true','--observe-profile=true','--steady-ms=10000'];
 const child=spawn(process.execPath,args,{windowsHide:true,stdio:['ignore','pipe','pipe'],env:{...process.env,APPDATA:home,LOCALAPPDATA:home}});
 child.stdout.on('data',v=>process.stdout.write(v));child.stderr.on('data',v=>process.stderr.write(v));
 const end=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('close',(code,signal)=>resolve({code,signal}));});
 const reportFile=path.join(project,'reports',run+'.json'),report=fs.existsSync(reportFile)?JSON.parse(fs.readFileSync(reportFile)):null,n=report?.native;
 Object.assign(row,{...end,finished:new Date().toISOString(),success:report?.success===true,report:reportFile,presentation:n?.presentation_state,intervals:n?.frame_intervals,baseMs:n?.world?.base_scenery_first_known_complete_ms,terrain:n?.world?.terrain,baseDraw:n?.world?.base_draw_merge,pool:n?.world?.pool,workers:n?.workers_remaining,afterNativeCache:inventory(nativeDirectory),sourceDriverUnchanged:hash(driver)===pins.driver&&hash(helper)===pins.helper});save();
 console.log(JSON.stringify({finished:caseName,success:row.success,code:end.code,intervals:row.intervals,baseMs:row.baseMs,bufferHits:row.pool?.native_draw_buffer_hits,nativeCache:row.afterNativeCache}));
 if(!row.success||!row.sourceDriverUnchanged)throw Error('Comparison correctness gate failed; further runs held');
 if(caseName==='cache-cold'&&row.afterNativeCache.resources===0)throw Error('Native cache candidate published no artifacts');
}
batch.success=true;batch.finished=new Date().toISOString();save();
