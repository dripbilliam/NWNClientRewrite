// Selected-file source overlay only; no engine, connection or full graph copy.
// Root must schedule even this small generator before execution while gaming.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';import {digest} from './processor-graph.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^raw-world-plan-overlay-[a-z0-9-]+$/.test(label??''))throw Error('Fresh loading-owned source overlay label required');
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing source evidence preserved');
const sources=[
 ['tools/native-session-host.cjs','601abc8d60b47ffbd91baf7c4b62d729e572259bc0f10a8bf1772c3d4346c618'],
 ['tools/raw-world-deltas.cjs','0e1b38d199b70bfcfdc9f1e6ec5fc1a94ad8530e85e1ee5c5a1f231649ee7491'],
 ['tools/raw-world-frames.cjs','aba359d051f419a61a4b3e187920c05df48463f368707cfba2205c5d3098e0dc']
];
const inputs=sources.map(([relative,sha256])=>{const bytes=fs.readFileSync(path.join(project,relative));if(digest(bytes)!==sha256)throw Error('Reviewed shared input differs '+relative);return{relative,sha256,bytes};});
const once=(text,before,after)=>{if(text.split(before).length!==2)throw Error('Host source seam differs '+before.slice(0,90));return text.replace(before,after);};
const raw=inputs[0].bytes.toString('utf8'),crlf=raw.includes('\r\n');let host=raw.replaceAll('\r\n','\n');
host=once(host,"const worldDeltas=new (require('./raw-world-deltas.cjs').RawWorldDeltas)();",`const rawWorldPlanSnapshots=process.argv.includes('--raw-world-framing=plan-snapshot');
const rawWorldPlanTransport=require('./perf140/loading/raw-world-plan-snapshot.cjs');
const worldDeltas=new rawWorldPlanTransport.SnapshotRawWorldDeltas();`);
host=once(host,'   const changed=worldDeltas.plan({serial,generation,data,connection:lobby.connection});',`   const rawPlanInput={serial,generation,data,connection:lobby.connection};
   const changed=rawWorldPlanSnapshots?worldDeltas.planSnapshot(rawPlanInput):worldDeltas.plan(rawPlanInput);`);
host=once(host,'   report.rawWorldUpdates??={full:0,delta:0,objects:0,removed:0};report.rawWorldUpdates[changed.bridgeMode]++;report.rawWorldUpdates.objects+=changed.objects.length;report.rawWorldUpdates.removed+=changed.removedObjectIds.length;',`   report.rawWorldUpdates??={full:0,delta:0,objects:0,removed:0};report.rawWorldUpdates[changed.bridgeMode]++;report.rawWorldUpdates.objects+=rawWorldPlanSnapshots?changed.objectCount:changed.objects.length;report.rawWorldUpdates.removed+=rawWorldPlanSnapshots?changed.removedCount:changed.removedObjectIds.length;
   report.rawWorldFraming={requested:rawWorldPlanSnapshots,mode:rawWorldPlanSnapshots?worldDeltas.snapshotStatus(changed).framing:'generic'};`);
host=once(host,"   let frames=worldRadialCapture&&!worldRadialCapture.work?[...rawWorldFrames({serial,generation,data:changed,connection:lobby.connection})]:rawWorldFrames({serial,generation,data:changed,connection:lobby.connection});",`   let frames=rawWorldPlanSnapshots?rawWorldPlanTransport.rawWorldSnapshotFrames(changed):rawWorldFrames({serial,generation,data:changed,connection:lobby.connection});
   if(worldRadialCapture&&!worldRadialCapture.work)frames=[...frames];`);
if(crlf)host=host.replaceAll('\n','\r\n');
const moduleRelative='tools/perf140/loading/raw-world-plan-snapshot.cjs',moduleBytes=fs.readFileSync(path.join(project,moduleRelative));
const outputs=[['tools/native-session-host.cjs',Buffer.from(host)], [moduleRelative,moduleBytes]];
for(const [relative,bytes]of outputs){const file=path.join(stage,'overlay',relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});}
const manifest={version:1,label,kind:'source-only-protocol-overlay',inputs:inputs.map(({relative,sha256,bytes})=>({relative,sha256,bytes:bytes.length})),outputs:outputs.map(([relative,bytes])=>({relative,sha256:digest(bytes),bytes:bytes.length})),flag:'--raw-world-framing=plan-snapshot',default:'generic',schema:'raw-world-plan-snapshot-v1',wholeGraphAdmission:false,sourceFilesCopied:2,fullProjectCopied:false,testsRun:false,engineStarts:0,serverConnections:0,sharedFilesEdited:false,scope:'Explicit opt-in canonical Host immutable serialization snapshot. Generic plan/framing APIs retained. This source overlay is not an independently runnable relocated repository and has not been live accepted.'};
const file=path.join(stage,'source-overlay.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:digest(fs.readFileSync(file)),sourceOnly:true,outputs:outputs.length}));
