'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {rawWorldFrames}=require('../../raw-world-frames.cjs'),{RawWorldDeltas}=require('../../raw-world-deltas.cjs');
const {IMMUTABLE_SERIALIZED_JSON:contract,sealImmutableEncodedPlan:seal,encodedRecordFrames,selectWorldFrames,constants,_testing}=require('./encoded-record-framer.cjs');
const stringify=v=>JSON.stringify(v,(_k,x)=>typeof x==='bigint'?{native64:String(x)}:x);
let checks=0,cases=0;const eq=(a,b)=>{assert.deepEqual(a,b);checks++;},ok=x=>{assert(x);checks++;};
function plan(envelope){const {objects,...header}=envelope.data;return seal({...envelope,records:objects.map(stringify),headerJson:stringify(header)},contract);}
function drain(g){const frames=[];let error=null;try{for(const x of g)frames.push(x);}catch(e){error=e;}return{frames,error};}
function differential(envelope,maximum=constants.FRAME_BYTES,legacy=rawWorldFrames,fast=p=>encodedRecordFrames(p,maximum)){const a=drain(legacy(envelope,maximum)),b=drain(fast(plan(envelope)));eq(b.frames,a.frames);eq(b.error?.constructor.name,a.error?.constructor.name);eq(b.error?.message,a.error?.message);for(const frame of b.frames)ok(Buffer.byteLength(frame.slice(0,-1))<=maximum);cases++;return b;}
eq(constants.SNAPSHOT_BYTES,64*1024*1024);eq(constants.OBJECTS_PER_FRAME,64);
for(const connection of [undefined,0,7,Number.MAX_SAFE_INTEGER])for(const count of [0,1,63,64,65,130]){
 const objects=Array.from({length:count},(_,id)=>({id,objectType:5,replicated:{position:[id,-0,1e-8],wide:42n,nested:{x:undefined,y:[undefined,null,NaN,Infinity]},text:'é中😀\n"\\\ud800'}}));
 const header={2:'numeric-key-order',area:{id:4},bridgeMode:'delta',bridgeBaseSerial:3,removedObjectIds:[9,1],controlledId:0};
 const result=differential({serial:9,generation:2,connection,data:{objects,...header}});
 const parsed=result.frames.map(JSON.parse),chunks=parsed.filter(f=>f.kind==='raw-world-chunk');ok(chunks.every(c=>c.objects.length<=64));eq(chunks.flatMap(c=>c.objects),JSON.parse(stringify(objects)));eq(parsed[0].data,JSON.parse(stringify(header)));
}
for(const maximum of [1400,1800,4096,16384])differential({serial:1,generation:1,connection:2,data:{objects:Array.from({length:80},(_,id)=>({id,text:'é中😀'.repeat(60)})),area:{id:2}}},maximum);
// Actual planner strings, including final bridge field order and native64.
const delta=new RawWorldDeltas(),source=[{id:1,wide:17n},{id:2,position:[1,2,3]}],scope={connection:3,generation:4};
let data=delta.plan({...scope,serial:1,data:{objects:source,bridgeMode:'old',removedObjectIds:['old'],area:{id:7}}});
const headerOf=d=>{const{objects,...header}=d;return header;};
const fromActual=seal({...scope,serial:1,records:data.objects.map(o=>delta.pending.records.get(o.id)),headerJson:stringify(headerOf(data))},contract);eq([...encodedRecordFrames(fromActual)],[...rawWorldFrames({...scope,serial:1,data})]);ok(delta.acknowledge({...scope,serial:1}));
source[1].position[0]=5;data=delta.plan({...scope,serial:2,data:{objects:source,bridgeMode:'old',removedObjectIds:['old'],area:{id:7}}});const second=seal({...scope,serial:2,records:data.objects.map(o=>delta.pending.records.get(o.id)),headerJson:stringify(headerOf(data))},contract);eq([...encodedRecordFrames(second)],[...rawWorldFrames({...scope,serial:2,data})]);
// Small injected budget: original source control flow differs ONLY in constant.
const originalPath=path.resolve(__dirname,'../../raw-world-frames.cjs'),original=fs.readFileSync(originalPath,'utf8');eq(original.split('64*1024*1024').length,2);const sandbox={module:{exports:{}},Buffer};vm.runInNewContext(original.replace('64*1024*1024','256'),sandbox,{filename:'actual-original-with256-byte-test-budget.cjs'});const smallLegacy=sandbox.module.exports.rawWorldFrames;
const limited={serial:1,generation:1,data:{objects:Array.from({length:65},(_,id)=>({id,text:'x'.repeat(8)}))}};differential(limited,1e6,smallLegacy,p=>_testing.withSnapshotBudget(p,1e6,256));
// Error timing and early generator return/throw remain lazy after BEGIN.
for(const data of [{objects:[{id:1,text:'x'.repeat(5000)}]},{objects:[],header:'x'.repeat(5000)}])differential({serial:1,generation:1,data},4096);
const oversized={serial:1,generation:1,data:{objects:[{text:'x'.repeat(5000)}]}};for(const make of [()=>rawWorldFrames(oversized,4096),()=>encodedRecordFrames(plan(oversized),4096)]){const g=make();eq(JSON.parse(g.next().value).kind,'raw-world-begin');eq(g.return('stop'),{done:true,value:'stop'});}
const thrown=new Error('consumer throw');for(const make of [()=>rawWorldFrames(oversized,4096),()=>encodedRecordFrames(plan(oversized),4096)]){const g=make();g.next();assert.throws(()=>g.throw(thrown),e=>e===thrown);checks++;}
// Sealing retains strings, not the producer's mutable array or scalar aliases.
const records=['{"id":1}'],input={serial:1,generation:1,records,headerJson:'{}'},sealed=seal(input,contract);records[0]='{"id":9}';input.headerJson='{"changed":true}';eq(JSON.parse([...encodedRecordFrames(sealed)][1]).objects,[{id:1}]);eq(JSON.parse([...encodedRecordFrames(sealed)][0]).data,{});
assert.throws(()=>seal(input,Symbol('forged')),/contract/);checks++;assert.throws(()=>seal({...input,records:[{}]},contract),/serialized record/);checks++;
// Unsupported getter: actual triple serialization produces different values.
let reads=0;const getterRow={id:1,nested:{get value(){return++reads;}}},getterPlanner=new RawWorldDeltas(),getterData=getterPlanner.plan({connection:1,generation:1,serial:1,data:{objects:[getterRow]}});eq(reads,1);
const getterCapsule=seal({connection:1,generation:1,serial:1,records:[getterPlanner.pending.records.get(1)],headerJson:stringify(headerOf(getterData))},contract);const legacyGetter=[...rawWorldFrames({connection:1,generation:1,serial:1,data:getterData})];eq(reads,3);ok(legacyGetter[1]!==[...encodedRecordFrames(getterCapsule)][1]);
reads=0;const getterEnvelope={serial:1,generation:1,data:{objects:[getterRow]}};const fallback=[...selectWorldFrames({encodedPlan:{records:['forged']},legacyEnvelope:getterEnvelope})];eq(reads,2);eq(JSON.parse(fallback[1]).objects[0].nested.value,2);
// toJSON root key differs between per-record stringify and chunk array output.
const keyed={id:1,toJSON(key){return{id:1,key};}},keyedEnvelope={serial:1,generation:1,data:{objects:[keyed]}};const keyCapsule=plan(keyedEnvelope);eq(JSON.parse([...rawWorldFrames(keyedEnvelope)][1]).objects[0].key,'0');eq(JSON.parse([...encodedRecordFrames(keyCapsule)][1]).objects[0].key,'');
// A synchronous write after BEGIN may mutate a live alias. Unknown API fallback
// observes it as legacy does; a sealed snapshot intentionally cannot be assumed equivalent.
const alias={id:1,nested:{x:0}},aliasEnvelope={serial:1,generation:1,data:{objects:[alias]}},captured=plan(aliasEnvelope),unknown=selectWorldFrames({legacyEnvelope:aliasEnvelope});unknown.next();alias.nested.x=7;eq(JSON.parse(unknown.next().value).objects[0].nested.x,7);eq(JSON.parse([...encodedRecordFrames(captured)][1]).objects[0].nested.x,0);
// Unknown invalid API keeps original errors instead of entering encoded path.
for(const connection of [-1,'7',NaN]){const e={serial:1,generation:1,connection,data:{objects:[]}};const a=drain(rawWorldFrames(e)),b=drain(selectWorldFrames({legacyEnvelope:e}));eq(b.error.message,a.error.message);}
// Count calls, never elapsed time. This observes only framing AFTER strings
// already exist; it does not claim the required planner serialization vanished.
const countedEnvelope={serial:1,generation:1,data:{objects:Array.from({length:65},(_,id)=>({id,text:'owned'}))}},countedPlan=plan(countedEnvelope),realStringify=JSON.stringify;let calls=0,legacyStringifyCalls=0,encodedStringifyCalls=0;
try{JSON.stringify=function(...args){calls++;return Reflect.apply(realStringify,JSON,args);};[...rawWorldFrames(countedEnvelope)];legacyStringifyCalls=calls;calls=0;[...encodedRecordFrames(countedPlan)];encodedStringifyCalls=calls;}finally{JSON.stringify=realStringify;}
eq(legacyStringifyCalls,69);eq(encodedStringifyCalls,0);
console.log(JSON.stringify({success:true,checks,differentialCases:cases,actualLegacyReference:true,smallInjectedSnapshotBudget:true,productionSnapshotBytes:constants.SNAPSHOT_BYTES,maximumTestPayloadBytes:5000,framingOnlyStringifyCalls:{legacy:legacyStringifyCalls,encoded:encodedStringifyCalls,objects:65},noBenchmark:true,noHostActivation:true,unsupportedGetterToJsonAndAliasReuseDemonstrated:true}));
