import fs from 'node:fs';import path from 'node:path';import {createHash} from 'node:crypto';import {spawnSync} from 'node:child_process';import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^live-blockers-check-[a-z0-9-]+$/.test(label??''))throw Error('Fresh explicit local blocker check label required');
const folder=path.join(source,'.cache/native-presentation-parity/root',label),sha=b=>createHash('sha256').update(b).digest('hex');
const assetsFile=path.join(source,'.cache/native-presentation-parity/root/blockers-live-v2/manifest.json');
if(sha(fs.readFileSync(assetsFile))!=='0d1caffc31a88bd7340bc62b551074eab75baa9a8d39df56fe634b47d7b4b9da')throw Error('Exact retained server fixture differs');
const assets=JSON.parse(fs.readFileSync(assetsFile));for(const pin of assets.files)if(sha(fs.readFileSync(pin.file))!==pin.sha256)throw Error('Recovered original resource changed');
const stage=spawnSync(process.execPath,[path.join(source,'tools/native_parity/stage-source-project.mjs'),folder],{encoding:'utf8',windowsHide:true});
if(stage.status!==0)throw Error(stage.stderr||stage.stdout);
const manifest=JSON.parse(fs.readFileSync(path.join(folder,'source-manifest.json'))),project=manifest.project;
const parent=JSON.parse(fs.readFileSync(path.join(source,'.cache/native-presentation-parity/loading-agent/parity-launch-seven-fixes-v2/manifest.json')));
const dll='.cache/native-kernel/nwn-particle-kernel.dll',extension='native/particle_kernel.gdextension';
for(const relative of [dll,extension]){const pin=parent.pins.find(p=>p.relative===relative),raw=fs.readFileSync(path.join(parent.project,relative));if(!pin||sha(raw)!==pin.sha256)throw Error('Frozen native runtime differs');const to=path.join(project,relative);fs.mkdirSync(path.dirname(to),{recursive:true});fs.writeFileSync(to,raw,{flag:'wx'});}
if(sha(fs.readFileSync(path.join(project,dll)))!=='672bd24ae23f0be06bb209bc40ec5083fbe8ac14e92b2dd6b10f836255a840ea'||sha(fs.readFileSync(parent.engine.path))!=='ce2d36407d0a6107a3076a00faf7d9f9dae185c86994ccea8dfd7e450c50f12a')throw Error('Runtime identity mismatch');
const results=[];
for(const mode of ['gd','compiled']){
 const out=path.join(folder,mode);fs.mkdirSync(out,{recursive:true});const report=path.join(out,'result.json');
 const args=['--headless','--path',project,'--log-file',path.join(out,'engine.log'),'--script','res://tests/native_live_blockers_test.gd','--','--assets-manifest='+assetsFile,'--report='+report,'--cache='+path.join(out,'prepared'),...(mode==='compiled'?['--existing-kernel']:[])];
 const child=spawnSync(parent.engine.path,args,{cwd:project,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:2*1024*1024,env:{...process.env,NWN_PARTICLE_KERNEL:mode}});
 const stdout=child.stdout??'',stderr=child.stderr??'';fs.writeFileSync(path.join(out,'stdout.log'),stdout);fs.writeFileSync(path.join(out,'stderr.log'),stderr);
 const errors=(stdout+'\n'+stderr).split(/\r?\n/).filter(v=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use/.test(v));
 let result=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}
 const record={mode,exit:child.status,error:child.error?.message??null,errors,result,success:child.status===0&&!child.error&&!errors.length&&result?.success===true};results.push(record);
 console.log(JSON.stringify({mode,success:record.success,exit:record.exit,errors,checks:result?.checks,failures:result?.failures,observations:result?.observations}));
}
const changed=manifest.pins.filter(p=>sha(fs.readFileSync(path.join(project,p.relative)))!==p.sha256).map(p=>p.relative);
const success=results.every(r=>r.success)&&!changed.length;
fs.writeFileSync(path.join(folder,'run.json'),JSON.stringify({success,results,changed,engine:parent.engine.sha256,dll:parent.nativeBinary.sha256,assetsSha256:sha(fs.readFileSync(assetsFile)),server_connections:0,gpu_claim:false},null,2)+'\n');
process.exitCode=success?0:1;
