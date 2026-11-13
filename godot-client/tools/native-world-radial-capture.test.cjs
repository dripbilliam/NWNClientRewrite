const test=require('node:test');const assert=require('node:assert/strict');const {createHash}=require('node:crypto');
const {NativeWorldRadialCapture,validateCapture,MAX_BYTES}=require('./native-world-radial-capture.cjs');
const sha=value=>createHash('sha256').update(value).digest('hex');
const frame=value=>JSON.stringify(value)+'\n';
const setup=frame({kind:'setup',connection:1,resourceSources:{install:'PRIVATE_INSTALLED_PATH'}});
const frames=[frame({kind:'raw-world-begin',connection:1,serial:7,generation:2,count:1,data:{bridgeMode:'full'}}),frame({kind:'raw-world-chunk',connection:1,serial:7,generation:2,objects:[{id:99,objectType:5}]}),frame({kind:'raw-world-end',connection:1,serial:7,generation:2})];
function value(){return{version:1,setupFrame:setup,rawFrames:frames.slice(),setupSha256:sha(setup),framesSha256:sha(frames.join(''))};}
test('first capture persists exact immutable serialized source frames once without overwriting',async()=>{
 const writes=[];const capture=new NativeWorldRadialCapture('owned-local.json',{writeFile:async(...args)=>writes.push(args)});capture.observeSetup(setup);const initial=frames.slice();const result=await capture.captureFrames(initial);initial.length=0;await capture.captureFrames([]);capture.observeSetup(frame({kind:'setup',connection:2}));
 assert.equal(writes.length,1);assert.deepEqual(writes[0][2],{flag:'wx'});assert.deepEqual(JSON.parse(writes[0][1]).rawFrames,frames);assert.equal(validateCapture(JSON.parse(writes[0][1])).objects,1);assert.equal(result.success,true);assert.equal((await capture.settle()).serial,7);
});
test('capture rejects missing setup, malformed ordering/checksums/scopes and bounded overflow',()=>{
 assert.throws(()=>new NativeWorldRadialCapture('owned').captureFrames(frames));
 for(const mutate of [v=>v.framesSha256='wrong',v=>v.rawFrames.reverse(),v=>v.rawFrames[1]=frame({kind:'raw-world-chunk',connection:2,serial:7,generation:2,objects:[{}]}),v=>v.setupFrame='x'.repeat(MAX_BYTES+1)]){const v=value();mutate(v);assert.throws(()=>validateCapture(v));}
});
test('write failure is an explicit captured failure and never retries on later frames',async()=>{
 let calls=0;const capture=new NativeWorldRadialCapture('owned',{writeFile:async()=>{calls++;throw Error('owned fixture failure');}});capture.observeSetup(setup);await assert.rejects(capture.captureFrames(frames));assert.equal((await capture.settle()).success,false);await assert.rejects(capture.captureFrames(frames));assert.equal(calls,1);
});
