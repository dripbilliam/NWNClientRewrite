import fs from 'node:fs/promises';import assert from 'node:assert/strict';import {NativePortalAdoption} from './portal-adoption.mjs';import {ServerEndpointPolicy} from './server-endpoint.mjs';
const out=process.argv.find(v=>v.startsWith('--report='))?.slice(9);if(!out||!global.gc)throw Error('Run with node --expose-gc and a new --report');
try{await fs.access(out);throw Error('Report exists');}catch(e){if(e.code!=='ENOENT')throw e;}
let finalized=0;const retirement=new FinalizationRegistry(()=>finalized++);
async function setup(){
 const old={closed:false,world:new Uint8Array(4*1024*1024),portalTransfer:{},identity:{forPortal:()=>({dispose(){}})}};retirement.register(old,'origin');
 const next={closed:false,disconnect:async()=>{}},lobby={session:old,connection:1,advancePortal(){this.session=null;return ++this.connection;}},result={session:next,metadata:{}};let current=old;
 const adopter=new NativePortalAdoption({lobby,policy:new ServerEndpointPolicy({allowed:[{host:'127.0.0.1',port:5122}]}),config:()=>({}),owns:(s,c)=>s===current&&c===lobby.connection,prepare:async()=>result,install:async(r)=>{current=r.session;lobby.session=r.session;}});
 adopter.bind(old,1);await old.portalTransfer.prepare({host:'127.0.0.1',port:5122,password:'',waypoint:'Arrival'});old.closed=true;old.portalHandoffReady=true;await adopter.adopt({previous:old,next:result});
 return{adopter,next,lobby};
}
const live=await setup(),until=performance.now()+3000;
do{await new Promise(r=>setImmediate(r));global.gc();await new Promise(r=>setTimeout(r,10));}while(!finalized&&performance.now()<until);
assert.equal(live.lobby.session,live.next);assert.equal(live.adopter.jobs.has(live.next),true);const passed=finalized===1;
await fs.writeFile(out,JSON.stringify({passed,retiredOriginsFinalized:finalized,destinationStillLive:live.lobby.session===live.next,scope:'Authored adoption coordinator GC lifetime only; not full backend, live server or native scene lifetime'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({passed,retiredOriginsFinalized:finalized}));if(!passed)process.exitCode=1;
