const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {CreationApplyDiagnostic,cpuDelta,runtimeTraceReady}=require('../tools/native-creation-apply-diagnostic.cjs');
const directory=path.resolve(__dirname,'../.cache/creation-apply-unit-'+Date.now());fs.mkdirSync(directory,{recursive:true});
test('durable scalar-only phase heartbeat and exact bounded first frames survive stalled apply',()=>{
 let now=10;const prefix=path.join(directory,'owned'),d=new CreationApplyDiagnostic(prefix,{clock:()=>now});
 d.record('native',{kind:'creation-source-phase',phase:'Main Play',connection:1,checks:108,credential:'never-record',object:{not:'recorded'}});
 assert.equal(JSON.stringify(d.summary()).includes('never-record'),false);assert.equal(JSON.stringify(d.summary()).includes('not'),false);
 d.setupFrame('{"kind":"setup","connection":1,"resourceSources":{"archives":[]}}\n');
 const frames=['{"kind":"raw-world-begin","serial":1,"generation":1,"count":1,"data":{"bridgeMode":"full"}}\n','{"kind":"raw-world-chunk","serial":1,"generation":1,"objects":[{"id":4294967295}]}\n','{"kind":"raw-world-end","serial":1,"generation":1}\n'];
 d.rawFrames(frames,{connection:1,generation:1,serial:1,areaId:0x80000001});
 assert.equal(fs.readFileSync(prefix+'.raw.jsonl','utf8'),frames.join(''));assert.equal(d.snapshot.objects,1);assert.equal(d.shouldStack(),false);
 now+=60000;assert.equal(d.shouldStack(),true);d.armStack();assert.equal(d.shouldStack(),false);
 const durable=JSON.parse(fs.readFileSync(prefix+'.phases.json'));assert.equal(durable.stackStarted,true);assert.equal(durable.rows.at(-1).kind,'owned-stack-trigger');
 assert.throws(()=>new CreationApplyDiagnostic(prefix),/retained/);
});
test('owned CPU deltas require unchanged process IDs, start times and monotonic counters',()=>{
 const before={success:true,exactLaunchIdentity:true,cpu:{atUtc:'2026-11-04T01:00:00Z',native:{processId:10,startedUtc:'2026-11-04T00:59:00Z',cpuSeconds:2},debugger:{processId:9,startedUtc:'2026-11-04T00:58:59Z',cpuSeconds:0.1}}};
 const after=structuredClone(before);after.cpu.atUtc='2026-11-04T01:01:00Z';after.cpu.native.cpuSeconds=14;after.cpu.debugger.cpuSeconds=0.125;
 const delta=cpuDelta(before,after);assert.equal(delta.ready,true);assert.equal(delta.elapsedMs,60000);assert.equal(delta.nativeCpuSeconds,12);assert(Math.abs(delta.debuggerCpuSeconds-0.025)<1e-10);
 for(const change of [value=>value.cpu.native.processId++,value=>value.cpu.native.startedUtc='changed',value=>value.cpu.debugger.cpuSeconds=-1,value=>value.cpu.atUtc=before.cpu.atUtc,value=>value.exactLaunchIdentity=false]){const bad=structuredClone(after);change(bad);assert.equal(cpuDelta(before,bad).ready,false);}
});
test('only matching full-frame ACK disarms the owned stack deadline; buffers and ledger are bounded',()=>{
 let now=0;const d=new CreationApplyDiagnostic(path.join(directory,'acked'),{clock:()=>now});
 const frames=['{"kind":"raw-world-begin","count":0,"data":{}}\n','{"kind":"raw-world-end"}\n'];
 d.rawFrames(frames,{connection:2,generation:3,serial:4});d.accepted({connection:1,generation:3,serial:4});now=60000;assert.equal(d.shouldStack(),true);
 d.accepted({connection:2,generation:3,serial:4});assert.equal(d.shouldStack(),false);
 for(let i=0;i<300;i++)d.record('native',{kind:'creation-native-phase',phase:'x'.repeat(1000),sequence:i});
 assert.equal(d.rows.length,256);assert(d.dropped>0);assert(d.rows.every(r=>r.phase.length<=160));
 const bad=new CreationApplyDiagnostic(path.join(directory,'bad'));assert.throws(()=>bad.rawFrames(['x'.repeat(8*1024*1024+1)],{}),/8MiB/);
 assert.throws(()=>bad.setupFrame('{"kind":"hello","token":"not-captured"}'),/setup/);
});
test('reserved lifecycle ledger survives a full ordinary ledger and records only bounded scalars',()=>{
 let now=10;const d=new CreationApplyDiagnostic(path.join(directory,'lifecycle'),{clock:()=>now++});
 for(let i=0;i<300;i++)d.record('native',{kind:'observed',phase:'frame'});
 for(const phase of ['finish:start','finished:received','finish-ack:send-request','finish-ack:write-callback','process:exit','report:write'])d.boundary('host',phase,{connection:1,queued:0,read:10,written:20,exitCode:0,success:true,ending:true,code:'ECONNRESET',payload:'never-captured',credential:'never-captured'});
 const durable=JSON.parse(fs.readFileSync(d.prefix+'.phases.json'));
 assert.equal(durable.rows.length,256);assert.equal(durable.lifecycle.length,6);assert.equal(durable.lifecycle.at(-1).phase,'report:write');assert.equal(durable.lifecycle[0].code,'ECONNRESET');assert.equal(JSON.stringify(durable).includes('never-captured'),false);
 for(let i=0;i<40;i++)d.boundary('socket','close',{code:'not a scalar error code',buffers:Buffer.alloc(2)});
 assert.equal(d.lifecycle.length,32);assert.equal(d.lifecycleDropped,14);assert.equal(d.lifecycle.at(-1).code,undefined);assert(d.lifecycle.every(r=>r.direction.length<=16&&r.phase.length<=80));
});
test('diagnostic acceptance requires the actual native trace to arm and retain bounded evidence',()=>{
 const valid={enabled:true,armed:true,failure:'',maximum_rows:256,sample_interval_ms:2000,rows:10,dropped:0,samples:1};
 assert.equal(runtimeTraceReady(valid),true);
 for(const change of [v=>v.enabled=false,v=>v.armed=false,v=>v.failure='Cannot open owned runtime trace',v=>v.rows=0,v=>v.rows=257,v=>v.rows=1.5,v=>v.maximum_rows=1024,v=>v.sample_interval_ms=0,v=>v.dropped=-1,v=>v.samples=-1]){const bad=structuredClone(valid);change(bad);assert.equal(runtimeTraceReady(bad),false);}
 assert.equal(runtimeTraceReady(null),false);
});
