import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadObjectState} from '../src/object_state_load.js';
import {ModuleSession} from '../src/module_session.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
import {parseGff} from '../src/gff.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-object-state-load-observations.json',import.meta.url)));
test('whole original object-state load preserves constructor mode, exact skip flags, apply flags and owner order',async()=>{
 for(const {case:c,calls}of native.cases){
  const trace=[],o={},p={read:()=>{trace.push(['list',c.status]);return{status:c.status,value:c.effects};},constructEffect:flag=>{trace.push(['construct',flag]);return{};},
   loadEffect:(e,row)=>{trace.push(['load',row.id]);Object.assign(e,{id:row.id,skipOnLoad:row.skipOnLoad,subtype:row.packed&~7,durationType:row.packed&7});},
   releaseEffect:e=>trace.push(['destroy',e.id]),applyEffect:(object,e,loading,special)=>{assert.equal(object,o);trace.push(['apply',e.id,loading,special]);},
   variables:()=>trace.push(['variables']),actions:()=>trace.push(['actions']),transition:()=>trace.push(['transition'])};
  await loadObjectState(o,{},p);assert.deepEqual(trace,calls);
 }
});
test('live import skips saved flagged/equipped effects before property application or ID allocation',async()=>{
 const s=new ModuleSession(null,{runStartupScripts:false}),item=s.register('item','saved-item',{}),next=s.effects.nextId;
 const fields={EffectList:gffField(15,[gffRecord({Id:gffField(6,0xffffffffffffffffn),Type:gffField(2,91),SubType:gffField(2,17),SkipOnLoad:gffField(0,255)},2),gffRecord({Id:gffField(6,0x8000000000000001n),Type:gffField(2,91),SubType:gffField(2,19)},2)])};
 await s.objectState.load(item,parseGff(writeGff('UTI ',gffRecord(fields)),'UTI ').root);
 assert.deepEqual(item.effects,[]);assert.equal(s.effects.nextId,next);
});
