// Real protected bootstrap/current native entry; headless menu only, no server.
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {spawnSync} from 'node:child_process';
const project=path.resolve('godot-client'),label=process.argv[2];
if(!/^production-features-[a-z0-9-]+$/.test(label??''))throw Error('Fresh production-features label required');
const folder=path.join(project,'.cache/native-presentation-parity/root',label);
if(fs.existsSync(folder))throw Error('Previous evidence is preserved');
fs.mkdirSync(folder,{recursive:true});
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const negative=process.argv.includes('--unsupported');
const cases=negative?[{name:'unsupported',options:['--performance-runtime=standard','--render-thread=safe','--drive-collision=legacy','--light-input-registry=builtin','--detailed-profiling=off'],expectedReject:true}]:[
 {name:'ordinary',options:['--performance-runtime=standard','--render-thread=safe','--drive-collision=legacy','--light-input-registry=script','--detailed-profiling=off'],expected:{runtime:'editor',collision:'legacy',lighting:'script'}},
 {name:'candidate',options:['--performance-runtime=verified-native','--render-thread=separate','--drive-collision=indexed','--light-input-registry=builtin','--detailed-profiling=off'],expected:{runtime:'verified-native',collision:'indexed',lighting:'builtin'}}
];
const summary={version:1,started:new Date().toISOString(),runs:[],graphics:false,serverConnections:0,publicConnections:0,builds:0,scope:'Actual ordinary protected bootstrap, current source, native startup/main-menu and manifest handshake. Headless cannot prove a GPU render thread or FPS.'};
for(const row of cases){
 const run=label+'-'+row.name,report=path.join(project,'reports',run+'.json'),startup=path.join(project,'reports',run+'.startup.json');
 if(fs.existsSync(report)||fs.existsSync(startup))throw Error('Prior host run preserved');
 const args=[path.join(project,'tools/native-session-bootstrap.cjs'),'--run='+run,'--native-runtime=editor','--startup-feature-check','--native-headless','--render-profile=gameplay',...row.options];
 const env={...process.env,NWN_PARTICLE_KERNEL:'compiled',NWN_ENTITY_API_REST:'false'};delete env.ELECTRON_RUN_AS_NODE;
 const child=spawnSync(path.resolve('node_modules/electron/dist/electron.exe'),args,{cwd:path.dirname(project),windowsHide:true,env,encoding:'utf8',timeout:90000,maxBuffer:3*1024*1024});
 fs.writeFileSync(path.join(folder,row.name+'.stdout.log'),child.stdout??'');fs.writeFileSync(path.join(folder,row.name+'.stderr.log'),child.stderr??'');
 let result=null,manifest=null;try{result=JSON.parse(fs.readFileSync(report));}catch{}try{manifest=JSON.parse(fs.readFileSync(startup));}catch{}
 const engineLog=path.join(project,'reports',run+'.engine.log'),native=manifest?.nativeStartup;
 const diagnostics=(fs.existsSync(engineLog)?fs.readFileSync(engineLog,'utf8'):'').split(/\r?\n/).filter(line=>/SCRIPT ERROR|^ERROR:|Parse Error|ObjectDB instances leaked|resources still in use/.test(line));
 if(row.expectedReject){
  let failedNative=null;try{failedNative=JSON.parse(fs.readFileSync(path.join(project,'reports',run+'.native.json')));}catch{}
  const checks={rejected:child.status!==0&&!child.error,clear_failure:/Native feature configuration rejected:.*Native light input class is unavailable/.test(result?.failure??''),native_rejection:failedNative?.runtime_features?.valid===false,manifest_rejected:manifest?.verification?.status==='rejected',no_menu:!result?.startupMainMenu,no_server:result?.publicConnections===0,diagnostics:diagnostics.length===0};
  summary.runs.push({name:row.name,run,accepted:Object.values(checks).every(Boolean),checks,diagnostics,exit:child.status,report,manifest:startup});
  break;
 }
 const checks={exit:child.status===0&&!child.error,host_success:result?.success===true,manifest:manifest?.verification?.status==='observed',runtime:manifest?.runtime?.kind===row.expected.runtime,registry:native?.registry?.sha256===manifest?.registry?.sha256,explicit_collision:native?.parsed_native_options?.['drive-collision']?.value===row.expected.collision,explicit_lighting:native?.parsed_native_options?.['light-input-registry']?.value===row.expected.lighting,profiling_off:native?.presentation?.detailed_profiling===false,headless_limitation:native?.rendering?.render_thread_requirement==='headless-not-a-gpu-thread-proof',no_server:result?.publicConnections===0&&(result?.states??[]).every(state=>state.phase!=='playing'),main_menu:result?.startupMainMenu?.ready===true,diagnostics:diagnostics.length===0,source_files:(manifest?.source?.files?.length??0)>100};
 const accepted=Object.values(checks).every(Boolean);summary.runs.push({name:row.name,run,accepted,checks,diagnostics,exit:child.status,error:child.error?.message??null,report,reportSha256:result?hash(report):null,manifest:startup,manifestSha256:manifest?hash(startup):null,engine:manifest?.runtime?.executableSha256,source:manifest?.source?.sha256});
 if(!accepted)break;
}
summary.success=summary.runs.length===cases.length&&summary.runs.every(row=>row.accepted);summary.finished=new Date().toISOString();
fs.writeFileSync(path.join(folder,'summary.json'),JSON.stringify(summary,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(summary,null,2));process.exitCode=summary.success?0:1;
