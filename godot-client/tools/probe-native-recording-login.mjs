// Owned loopback handshake only: no character selection, world, graphics or chat.
import fs from 'node:fs/promises';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {createInstalledNetworkSession} from '../../electron/installed_network_session.mjs';
import {MovementTimingRecording} from './native-movement-recording.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const run=process.argv[2];if(!/^native-recording-login-[a-z0-9-]+$/.test(run??''))throw Error('Fresh owned login probe name required');
let input='';for await(const chunk of process.stdin){input+=chunk;if(input.length>512)throw Error('Private login input exceeds bound');}
let key=JSON.parse(input).cdKey;input='';if(typeof key!=='string'||key.length!==41)throw Error('Protected test key unavailable');
const stage=path.join(root,'runtime-logs',run);await fs.mkdir(stage);
const output=path.join(project,'reports',run+'.json'),results=[];
for(const variant of ['baseline','recording']){
 const phases=[],diagnostics=[],home=path.join(stage,variant);await fs.mkdir(home);let current,recorder,phase='create';
 const result={variant,connected:false};
 try{
  const created=await createInstalledNetworkSession({install:path.resolve(root,'../FullDecomp/NwnRootInstall'),userDirectory:home,cacheDirectory:path.join(home,'content'),modsDirectory:path.join(home,'workshop'),disabledMods:[],host:'127.0.0.1',port:5121,name:'NwnRecordingLoginProbe',credentials:{cdKey:key},onDiagnostic:d=>diagnostics.push({code:d.code,reason:d.reason,connectionError:d.connectionError})});
  current=created.session;
  for(const method of ['applicationId','platformIdentity','start','finish','seal','open']){
   const original=current.peer.crypto[method];current.peer.crypto[method]=async function(...args){phases.push({method,boundary:'before'});try{const value=await original.apply(this,args);phases.push({method,boundary:'after'});return value;}catch(error){phases.push({method,boundary:'failed',errorName:error.name,reason:error.message});throw error;}};
  }
  if(variant==='recording'){recorder=new MovementTimingRecording(path.join(home,'capture'));recorder.attach(current,1);}
  const log=await fs.readFile(path.join(root,'runtime-logs/local-multiplayer-server/logs/nwengineLog.txt'),'utf8'),pin=log.match(/cryptographic public identity is: ([A-Za-z0-9+/=]+)/)?.[1];if(!pin)throw Error('Owned server identity unavailable');
  phase='connect';await current.connect({host:'127.0.0.1',port:5121,metadata:created.metadata,timeout:10000,expectedServerPublicKey:Buffer.from(pin,'base64')});
  result.connected=true;result.phase=current.phase;
 }catch(error){result.failure={phase,name:error.name,reason:error.message};}
 finally{await current?.disconnect().catch(()=>{});if(recorder){const seal=await recorder.close({scope:'Handshake-only original localhost probe; no world/resource capture expected'});result.recorder={complete:seal.complete,failure:seal.failure,counts:seal.metadata?.movementCounts};}}
 result.phases=phases;result.diagnostics=diagnostics;results.push(result);
}
key='';const report={success:results.every(v=>v.connected),endpoint:'127.0.0.1:5121',publicConnections:0,worldEntries:0,results};
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(report));if(!report.success)process.exitCode=1;
