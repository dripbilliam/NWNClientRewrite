import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveScriptEngineStructure,loadScriptEngineStructure,createScriptEngineStructure,saveScriptEvent,loadScriptEvent,saveScriptTalent,loadScriptTalent,copyScriptEventValue} from '../src/script_engine_structures.js';
import {savedEffectStorage,loadGameEffect} from '../src/game_effect_load.js';
import {saveGameEffect,saveLocalLocation} from '../src/object_state_save.js';
import {loadLocalLocation} from '../src/script_variable_load.js';
import {gffRecord,writeGff} from '../src/gff_writer.js';
import {parseGff} from '../src/gff.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-engine-structures-observations.json',import.meta.url)));
const norm=value=>JSON.parse(JSON.stringify(value,(_k,v)=>typeof v==='bigint'?v.toString():v));
const decode=data=>parseGff(writeGff('UTI ',data),'UTI ').root;
test('native engine wrappers and complete payload bodies agree, including uint64 constructor allocation/wrap',async()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,status,nextId}of native.cases){
  let counter=BigInt(`0x${c.seed}`);const root=gffRecord({}),out={value:'previous'};
  const p={saveEffect:saveGameEffect,saveEvent:saveScriptEvent,saveLocation:(v,r)=>{saveLocalLocation(v,r);return 1;},saveTalent:saveScriptTalent,saveOpaque:(_kind,value,r)=>{r.fields.Opaque={type:5,value};return 77;},
   createEffect:mode=>{assert.equal(mode,1);const e=savedEffectStorage();e.id=counter.toString(16).padStart(16,'0');counter=BigInt.asUintN(64,counter+1n);e.exposed=1;e.showIcon=1;return e;},loadEffect:(e,r)=>loadGameEffect(e,r,{setCreator:(e,id)=>{e.creatorId=id;}}),
   create:kind=>kind>=5?{marker:0}:createScriptEngineStructure(kind),loadEvent:loadScriptEvent,loadLocation:(v,r)=>{Object.assign(v,loadLocalLocation(r));return 1;},loadTalent:loadScriptTalent,loadOpaque:(_kind,value,r)=>{value.marker=r.Opaque??0;return 0;}};
  let actual,result;
  if(c.mode==='save'){result=await saveScriptEngineStructure(c.kind,c.value,p,root);actual=root;}
  else if(c.mode==='load'){result=await loadScriptEngineStructure(c.kind,decode(c.data),p,out);actual=c.kind>=5&&c.kind<=7?out.value.marker:out.value;}
  else if(c.mode==='create'){actual=createScriptEngineStructure(c.kind);result=null;}
  else if(c.mode==='event-copy'){actual=copyScriptEventValue(c.value);result=null;}
  else{actual=structuredClone(c.value);result=loadScriptEvent(actual,decode(c.data));}
  const expected=structuredClone(output);if(c.mode==='create'&&c.kind===1){assert.equal(expected.type,0xa5a5,'native event constructor leaves the seeded type word unwritten');delete expected.type;}
  assert.deepEqual(norm(actual),expected,c.name);assert.equal(result,status,c.name);assert.equal(counter.toString(16).padStart(16,'0'),nextId,c.name);
 }
});
test('constructor defaults preserve unwritten event type and actual native NULL kinds',()=>{
 const event=createScriptEngineStructure(1);assert.equal(event.type,undefined);assert.throws(()=>saveScriptEvent(event,gffRecord({})),/event type/);
 for(const kind of [0,4])assert.equal(createScriptEngineStructure(kind).id,'0000000000000000');
 for(const kind of [5,6,7,8,9])assert.equal(createScriptEngineStructure(kind),null);
});
