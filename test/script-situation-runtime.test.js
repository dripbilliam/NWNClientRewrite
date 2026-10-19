import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {NwScriptVm} from '../src/nwscript_vm.js';
import {parseNcs} from '../src/ncs.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {scriptUserDefinedEvent,createScriptEngineStructure} from '../src/script_engine_structures.js';
const decode=root=>parseGff(writeGff('UTI ',root),'UTI ').root;
function fixture(){
 const s=new ModuleSession(null,{runStartupScripts:false}),vm=new NwScriptVm({api:[],command:()=>{}}),bytes=Buffer.alloc(15);bytes.write('NCS V1.0');bytes[8]=0x42;bytes.writeUInt32BE(15,9);bytes.set([0x20,0],13);const program=parseNcs(bytes,'saved_snapshot');
 const snapshot=vm.capture({program,stored:{pc:13,baseSize:0,stackSize:4},bp:0,stack:[{type:3,value:17}]});return{s,vm,snapshot};
}
test('live VM snapshots round-trip code, native metadata, NDB and chunk without identity allocation',async()=>{
 const {s,vm,snapshot}=fixture(),next=s.effects.nextId,ids=[...s.registry.objects.keys()];snapshot.nativeStackSize=9;snapshot.nativeSecondaryPtr=22;snapshot.nativeScriptEventId=-1;snapshot.nativeScriptState.ndb=Uint8Array.of(0,1,255);snapshot.nativeScriptState.scriptChunk='chunk\0tail';
 const before=decode(await s.scriptSituations.save(snapshot)),restored=await s.scriptSituations.load(before),after=decode(await s.scriptSituations.save(restored));assert.deepEqual(after,before);
 assert.equal(restored.nativeStackSize,9);assert.equal(restored.stack.length,1);assert.equal(restored.nativeStackCapacity,17);assert.equal(restored.nativeSecondaryPtr,22);assert.equal(restored.nativeScriptEventId,-1);assert.deepEqual(restored.program.nativeCode,snapshot.program.nativeCode);
 const nested=vm.capture({program:restored.program,nativeScriptState:restored.nativeScriptState,stored:{pc:13,baseSize:0,stackSize:4},bp:0,stack:restored.stack});assert.equal(nested.nativeSecondaryPtr,0);assert.equal(nested.nativeScriptEventId,0);assert.equal(nested.nativeScriptState.ndb,restored.nativeScriptState.ndb);assert.equal(nested.nativeScriptState.scriptChunk,'chunk\0tail');
 assert.equal(s.effects.nextId,next);assert.deepEqual([...s.registry.objects.keys()],ids);
});
test('zero CodeSize preserves a prior native action pointer and diagnoses an unwritten first pointer',async()=>{
 const {s,snapshot}=fixture(),empty=decode(gffRecord({CodeSize:gffField(5,0)}));assert.equal(await s.scriptSituations.load(empty,snapshot),snapshot);await assert.rejects(s.scriptSituations.load(empty),/output pointer is unwritten/);
});
test('engine structures, jump ownership and disposed snapshots retain precise diagnostics',async()=>{
 const {s,snapshot}=fixture();snapshot.stack[0]={type:21,value:null};await assert.rejects(s.scriptSituations.save(snapshot),/opaque engine-structure save owner 5/);
 snapshot.stack[0]={type:3,value:17};snapshot.nativeScriptState.jumps=[{label:'jump',vmInstPtr:0,instPtr:0,stackPtr:0,instPtrLevel:0,fromJmp:0,retVal:0}];const data=decode(await s.scriptSituations.save(snapshot));await assert.rejects(s.scriptSituations.load(data),/jump-map load ownership/);snapshot.disposed=true;await assert.rejects(s.scriptSituations.save(snapshot),/disposed snapshot/);
});
test('live engine values retain saved effect IDs while native load constructors advance and wrap the allocator',async()=>{
 const {s,snapshot}=fixture(),effect=s.effects.create(1),property=s.effects.create(91,0x7f000000,[6,0,0,1,0,0,255,100,1]);
 snapshot.stack=[{type:16,value:effect},{type:20,value:property},{type:17,value:scriptUserDefinedEvent(321)},{type:18,value:createScriptEngineStructure(2)},{type:19,value:createScriptEngineStructure(3)}];snapshot.nativeStackSize=5;snapshot.nativeStackCapacity=21;
 const data=decode(await s.scriptSituations.save(snapshot));s.effects.nextId=0xffffffffffffffffn;const restored=await s.scriptSituations.load(data);assert.equal(s.effects.nextId,1n);
 assert.equal(restored.stack[0].value.id,effect.id);assert.equal(restored.stack[1].value.id,property.id);assert.equal(restored.stack[2].value.type,11);assert.deepEqual(restored.stack[2].value.integers,[321]);assert.deepEqual(restored.stack[3].value,snapshot.stack[3].value);assert.deepEqual(restored.stack[4].value,snapshot.stack[4].value);assert.deepEqual(decode(await s.scriptSituations.save(restored)),data);
});
