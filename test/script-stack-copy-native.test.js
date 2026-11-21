import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {copyScriptStack} from '../src/script_stack_copy.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {parseNcs} from '../src/ncs.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-stack-copy-observations.json',import.meta.url)));
test('whole native captured-stack copier matches region tails, clamps, capacity and engine dispatch',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls}of native.cases){
  const trace=[],actual=copyScriptStack({basePointer:c.basePointer,stackPointer:c.cells.length,cells:c.cells},c.topBytes,c.baseBytes,{copyEngine:(kind,value)=>{trace.push([kind,value]);return{copied:value,kind};}});
  assert.deepEqual(actual,output,c.name);assert.deepEqual(trace,calls,c.name);
 }
});
test('live capture records original stack size separately from copied cells and native spare capacity',()=>{
 const vm=new NwScriptVm({api:[],command:()=>{}}),stack=Array.from({length:8},(_,i)=>({type:3,value:i}));
 const snapshot=vm.capture({program:{name:'capture'},stored:{pc:31,baseSize:4,stackSize:8},bp:4,stack});
 assert.deepEqual(snapshot.stack.map(c=>c.value),[3,6,7]);assert.equal(snapshot.bp,1);assert.equal(snapshot.nativeStackSize,8);assert.equal(snapshot.nativeStackCapacity,19);assert.equal(snapshot.nativeInstructionPtr,18);
});
test('STORE_STATE and STORE_IP metadata match original opcode execution with host/header offset conversion',async()=>{
 const data=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-store-state-observations.json',import.meta.url))),vm=new NwScriptVm({api:[],command:()=>{}});
 for(const {case:c,output}of data.cases){
  const frame={};await vm.step(frame,{op:c.op,target:13+c.start+c.delta,baseSize:c.op===0x2c?c.base:undefined,stackSize:c.op===0x2c?c.top:undefined});
  assert.deepEqual({instructionPtr:frame.stored.pc-13,baseBytes:frame.stored.baseSize,topBytes:frame.stored.stackSize},output);
 }
 const bytes=Buffer.alloc(25);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(25,9);bytes.set([0x2c,10,0,0,0,4,0,0,0,8,0x20,0],13);
 const program=parseNcs(bytes,'header-offset'),ins=program.instructions.get(13);assert.deepEqual([...program.nativeCode],[...bytes.subarray(13)]);assert.equal(ins.target,23);assert.equal(ins.baseSize,4);assert.equal(ins.stackSize,8);
 bytes[13]=0;assert.equal(program.nativeCode[0],0x2c,'runtime owns retained code independently of the input buffer');
});
