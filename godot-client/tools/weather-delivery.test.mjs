import test from 'node:test';import assert from 'node:assert/strict';
import {WeatherDelivery} from './weather-delivery.mjs';import {EnvironmentDelivery} from './environment-delivery.mjs';
const deferred=()=>{let resolve,reject;return {promise:new Promise((a,b)=>{resolve=a;reject=b;}),resolve,reject};};
function fixture(){
 const area={weather:{type:1,enabled:1},fields:{}},session={closed:false,world:{areaId:7,time:{},registry:{get:()=>({state:area})}},areaGeneration:2};
 const table={columns:['Model','Animation','ModelLightning','FadeTime'],defaultValue:'****',orderedRows:[{Model:'****',Animation:'****',ModelLightning:'****',FadeTime:'****'},{Model:'fx_rain',Animation:'rain',ModelLightning:'fx_lightning01',FadeTime:'6000'},{Model:'fx_snow',Animation:'snow',ModelLightning:'fx_lightning01',FadeTime:'0x2328'}]};
 const scope={connection:3,areaId:7,generation:2,transferId:4},sent=[],diagnostics=[],reads=[];let active=true,ready=scope;
 const owner=new WeatherDelivery({session,connection:3,active:()=>active,ready:()=>ready,rules:async name=>{reads.push(name);return table;},send:v=>sent.push(v),diagnose:(code,reason)=>diagnostics.push({code,reason})});
 return {owner,session,scope,sent,diagnostics,reads,area,table,retire:()=>active=false,unready:()=>ready=null,admit:()=>ready=scope};
}
const settled=async f=>Promise.all([...f.owner.jobs]);
test('physical rules rows and native string/INT missing semantics arrive once per weather request',async()=>{
 const f=fixture();f.owner.receive({kind:'client-area'});await settled(f);assert.equal(f.sent.length,1);assert.deepEqual(f.reads,['weathertypes']);
 const m=f.sent[0];assert.deepEqual(m.weather,{type:1,enabled:true});assert.deepEqual(m.rows[0],{model:null,animation:null,lightning:null,fadeTime:6000});assert.deepEqual(m.rows[2],{model:'fx_snow',animation:'snow',lightning:'fx_lightning01',fadeTime:9000});assert.equal(m.presentationPending,true);
 assert.deepEqual(Object.fromEntries(Object.keys(f.scope).map(k=>[k,m[k]])),f.scope);
 for(let i=0;i<1000;i++)f.owner.flush();await settled(f);assert.equal(f.reads.length,1);
 f.owner.receive({kind:'area-weather'});await settled(f);assert.equal(f.sent[1].revision,2);assert.equal(f.sent.length,2,'repeated native setter still restarts the fade');
});
test('cold admission keeps latest received weather without launching work before ready',async()=>{
 const f=fixture();f.unready();f.owner.receive({kind:'client-area'});f.area.weather={type:2,enabled:0};f.owner.receive({kind:'area-weather'});await settled(f);assert.equal(f.reads.length,0);
 f.admit();f.owner.flush();await settled(f);assert.deepEqual(f.sent[0].weather,{type:2,enabled:false});assert.equal(f.sent[0].revision,2);
});
test('module clocks and environment refreshes do not repeat weather requests',async()=>{
 const f=fixture(),env=new EnvironmentDelivery({session:f.session,connection:3,active:()=>true,ready:()=>f.scope,weather:f.owner,send:()=>{}});
 env.receive({kind:'client-area'});await settled(f);
 for(const m of [{kind:'module-info'},{kind:'module-time',changes:{hour:1}},{kind:'module-time',changes:{timeOfDay:2,transition:0}}])env.receive(m);
 await settled(f);assert.equal(f.sent.length,1);assert.equal(f.owner.revision,1);
});
test('superseded weather, world identity, generation and ticket prevent stale asynchronous metadata publication',async()=>{
 for(const change of [f=>{f.area.weather={type:2,enabled:1};f.owner.receive({kind:'area-weather'});},f=>f.session.world={...f.session.world},f=>f.session.areaGeneration++,f=>f.scope.transferId++,f=>f.scope.connection++,f=>f.scope.areaId++]){
  const f=fixture(),gate=deferred();f.owner.rules=()=>gate.promise;f.owner.receive({kind:'client-area'});change(f);gate.resolve(f.table);await settled(f);
  assert.equal(f.sent.length, f.owner.revision===2?1:0);if(f.sent.length)assert.equal(f.sent[0].weather.type,2);
 }
});
test('closing environment waits for pending weather work and suppresses retired delivery and errors',async()=>{
 for(const fail of [false,true]){const f=fixture(),gate=deferred();f.owner.rules=()=>gate.promise;f.owner.receive({kind:'client-area'});let closed=false;
 const env=new EnvironmentDelivery({weather:f.owner});const end=env.close().then(()=>closed=true);await Promise.resolve();assert.equal(closed,false);
 if(fail)gate.reject(Error('retired read'));else gate.resolve(f.table);await end;assert.equal(f.owner.jobs.size,0);assert.equal(f.sent.length,0);assert.equal(f.diagnostics.length,0);}
});
test('inactive, closed, nonweather and mismatched native scopes do not resolve rules',async()=>{
 for(const change of [f=>f.retire(),f=>f.session.closed=true,f=>f.scope.connection++,f=>f.scope.generation++,f=>f.scope.areaId++]){const f=fixture();change(f);f.owner.receive({kind:'client-area'});await settled(f);assert.equal(f.reads.length,0);}
 const f=fixture();for(const kind of ['movement','module-time','area-environment'])f.owner.receive({kind});await settled(f);assert.equal(f.reads.length,0);
});
