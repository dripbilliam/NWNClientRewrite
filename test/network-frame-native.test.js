import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {updateNetworkFrame} from '../src/network_frame.js';
import {NetworkKeyboardInput} from '../src/network_keyboard_input.js';
import {NetworkMotion} from '../src/network_motion.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-frame-input-origin-v1.json',import.meta.url))),metadata=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-input-frame-order-metadata-v1.json',import.meta.url)));
async function frame(c,run=updateNetworkFrame){
 const object={id:9,replicated:{position:c.render.slice(),orientation:[1,0,0],animation:4,walkRate:2000,runRate:4000}},before=structuredClone(object),motion=new NetworkMotion({height:(_p,z)=>z,report:()=>{}}),state=motion.ensure(object),sent=[];
 Object.assign(state,{position:c.predicted.slice(),render:c.render.slice(),path:[c.predicted.slice(),[c.predicted[0]+5,c.predicted[1],0]],cursor:0,active:true,script:1,factor:1,animation:4,correction:100});
 const context=()=>({sessionId:'frame',areaGeneration:1,areaId:7,actorId:9,position:state.render.slice(),orientation:state.orientation.slice()}),input=new NetworkKeyboardInput({events:new EventTarget(),document:new EventTarget(),context,enabled:()=>true,send:async(_context,request)=>{sent.push(request);return{sequence:1};},now:()=>1000});
 input.owner=context();input.inputPending=true;for(const[bit,key]of[[3,'KeyW'],[4,'KeyQ'],[8,'KeyE'],[16,'KeyA']])if((c.flags&bit)===bit)input.keys.add(key);
 run(input,{update:delta=>motion.update(delta)},.016);await input.queue;assert.deepEqual(object,before,'Presentation input/motion mutated the authoritative object');
 assert.notDeepEqual(state.render,c.render,'The test did not advance presentation');return sent.find(r=>r.operation==='drive');
}
test('frame input uses the original pre-AI rendered pose in16 native held-input cases',async()=>{
 assert.equal(oracle.cases.length,16);
 for(const c of oracle.cases){const actual=await frame(c),native=c.calls.find(call=>call.kind==='drive');assert.deepEqual(actual.position,native.position,JSON.stringify(c));assert.equal(actual.flags,c.flags);}
});
test('the previous reverse order violates the same native pose-sampling gate',async()=>{
 for(const c of oracle.cases){const actual=await frame(c,(keyboard,presentation,delta)=>{presentation.update(delta);keyboard.update();});assert.notDeepEqual(actual.position,c.calls.find(call=>call.kind==='drive').position);}
});
test('mapped original coordinator chain places held input before creature AI/path stepping',()=>{
 const outer=metadata.calls.filter(c=>c.function==='0x1406db800');assert.equal(outer.length,2);assert.equal(outer[0].target,'0x1406f14e0');assert.equal(outer[1].target,'0x140767d50');assert.ok(BigInt(outer[0].address)<BigInt(outer[1].address));assert.equal(metadata.vtable.slot,'0xe8');assert.equal(metadata.vtable.target,'0x1407fbd10');
 assert.ok(metadata.calls.some(c=>c.function==='0x1407fbd10'&&c.target==='0x1407fcd70'));assert.ok(metadata.calls.some(c=>c.function==='0x1407fcd70'&&c.target==='0x1408114d0'));
});
test('input still updates when no scene is attached and motion receives an unmodified delta',()=>{
 const calls=[];updateNetworkFrame({update:()=>calls.push('input')},null,.1);assert.deepEqual(calls,['input']);updateNetworkFrame({update:()=>calls.push('input')},{update:delta=>calls.push(delta)},.123);assert.deepEqual(calls,['input','input',.123]);
});
