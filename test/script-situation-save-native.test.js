import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {saveScriptSituation} from '../src/script_situation_save.js';
import {gffField,writeGff} from '../src/gff_writer.js';
import {parseGff,getGffFieldTypes,getGffStructType} from '../src/gff.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-script-situation-save-observations.json',import.meta.url)));
const normalize=v=>JSON.parse(JSON.stringify(v,(_k,v)=>v instanceof Uint8Array?[...v]:v));
test('whole VM snapshot saver matches original fields, struct IDs, code buffers and fifth engine argument',async()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls,status}of native.cases){
  assert.equal(status,1,c.name);
  const s={...structuredClone(c),code:Uint8Array.from(c.code),ndb:c.ndb===null?null:Uint8Array.from(c.ndb)},trace=[];
  const actual=await saveScriptSituation(s,{saveEngine:(kind,value,row)=>{trace.push([kind,value]);row.fields.EngineMarker=gffField(5,value);return 0;}});
  assert.deepEqual(normalize(actual),output,c.name);assert.deepEqual(trace,calls,c.name);
 }
});
test('typed VM GFF preserves body bytes, CHAR stack types and physical jump labels',async()=>{
 const c=native.cases.find(x=>x.case.name==='all-cell-types').case,s={...structuredClone(c),code:Uint8Array.from(c.code),ndb:Uint8Array.from(c.ndb)};
 const root=parseGff(writeGff('UTI ',await saveScriptSituation(s,{saveEngine:(_kind,value,row)=>{row.fields.EngineMarker=gffField(5,value);}})),'UTI ').root;
 assert.deepEqual([...root.Code],c.code);assert.equal(root.StackSize,93);assert.equal(root.Stack.StackPointer,14);assert.equal(root.Stack.TotalSize,30);
 assert.equal(root.Stack.Stack[13].Type,-1);assert.equal(getGffFieldTypes(root.Stack.Stack[13]).Type,1);assert.equal(getGffStructType(root.Stack.Stack[13]),13);assert.equal(root.JmpList[0].Label,'a');assert.equal(root.JmpList[0].FromJmp,255);assert.equal(root.ScriptChunk,'chunk\0tail');
});
