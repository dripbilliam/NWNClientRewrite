import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadScriptSituation} from '../src/script_situation_load.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord,gffField} from '../src/gff_writer.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-situation-load-observations.json',import.meta.url)));
const decode=data=>parseGff(writeGff('UTI ',data),'UTI ').root;
const normalize=v=>JSON.parse(JSON.stringify(v,(_k,v)=>v instanceof Uint8Array?[...v]:v));
test('whole snapshot and stack loaders match original output, ignored lower failures and engine ABI',async()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,status,calls}of native.cases){
  const out={value:'previous'},trace=[];
  const result=await loadScriptSituation(decode(c.data),{loadEngine:(kind,row,slot)=>{const marker=row.EngineMarker??0;trace.push(['engine',kind,marker]);slot.value={kind,marker};return 1;},stackFailure:line=>trace.push(['failure',line]),assignJump:(s,entry)=>{
   trace.push(['jump',entry.label]);const i=s.jumps.findIndex(e=>e.label===entry.label);if(i<0)s.jumps.push(entry);else s.jumps[i]=entry;
  }},out);
  assert.equal(result,status,c.name);assert.deepEqual(normalize(out.value),output,c.name);assert.deepEqual(trace,calls,c.name);
 }
});
test('unwritten blob bytes, negative allocations and uninitialized structures remain diagnosed',async()=>{
 const load=fields=>loadScriptSituation(decode(gffRecord(fields)),{},{});
 await assert.rejects(load({CodeSize:gffField(5,-1)}),/negative code allocation/);
 await assert.rejects(load({CodeSize:gffField(5,3),Code:gffField(13,[1])}),/unwritten allocated bytes/);
 await assert.rejects(load({CodeSize:gffField(5,1),Code:gffField(13,[1])}),/Stack struct is uninitialized/);
 await assert.rejects(load({CodeSize:gffField(5,1),Code:gffField(13,[1]),Stack:gffField(14,gffRecord({StackPointer:gffField(5,2),TotalSize:gffField(5,1)}))}),/beyond allocated/);
});
