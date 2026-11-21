import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {clientCastSoundSuppression,readClientCastFields,localClientCastFields,clientCastFieldReader} from '../src/client_cast_fields.js';
const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-cast-field-observations.json',import.meta.url)));
const keys=['EPIC_AUTOMATIC_LESSER_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_SILENT_LEVEL_CAP','EPIC_AUTOMATIC_GREATER_SILENT_LEVEL_CAP'];
test('native cast-update sound flag preserves metamagic bit, class/master/innate fallback and strict automatic-silent caps',()=>{
 const rows=capture.rows.filter(r=>r.case.mode==='send');
 for(const row of rows){const c=row.case,calls=[],primary={id:37,master:123,innate:c.innate??0},master={id:123},actor={nativeSpellId218:37,nativeSpellMetamagic22d:c.meta,nativeSpellClass22c:c.classIndex??0},rules={ruleset:{orderedRows:keys.map((Label,i)=>({Label,Value:String(c.caps[i])}))}},p={
   spell:id=>{calls.push(['spell',id>>>0]);return id===37?(c.spell??1)?primary:null:c.masterExists?master:null;},
   classType:(_o,index)=>{calls.push(['class',index]);return index<2?10+index:255;},
   level:(spell,type)=>{const kind=spell===primary?'primary':'master';calls.push(['level',kind,type]);return type===255?255:c[kind];},
   hasFeat:(_o,id)=>{calls.push(['feat',id]);return c.feats&(1<<(id-860))?1:0;}
  };
  const value=clientCastSoundSuppression(actor,rules,p);assert.equal(value,row.calls.find(c=>c[0]==='bool')[1],JSON.stringify(c));
  assert.deepEqual(calls,row.calls.filter(c=>['spell','class','level','feat'].includes(c[0])),JSON.stringify(c));
  for(const cap of row.calls.filter(c=>c[0]==='cap'))assert.ok(keys.includes(cap[1]),'Native seeded PIC literal must resolve to the full EPIC ruleset key');
 }assert.equal(rows.length,6915);
});
test('native cast field receiver narrows animation SHORT and keeps old cells on overflow while consuming missing-source fields',()=>{
 const rows=capture.rows.filter(r=>r.case.mode==='read');for(const row of rows){const c=row.case,calls=[],state={spellId:100,spellItemId:200,suppressSound:-1};
  const result=readClientCastFields(c.object?state:null,c.animation,{dword:bits=>{calls.push(['readDword',bits]);return c.spellId;},objectId:()=>{calls.push(['readObject']);return c.itemId;},bool:()=>{calls.push(['readBool']);return c.suppressed;},overflow:()=>{calls.push(['overflow']);return c.overflow;}});
  assert.deepEqual({state,calls},{state:row.state,calls:row.calls},JSON.stringify(c));assert.equal(result,row.exit!=='0x140785726');
 }assert.equal(rows.length,384);
});
test('local cast fields convert only the received item ID and keep authoritative cells unchanged',()=>{
 const actor={id:5,animationState:15,nativeSpellId218:37,nativeSpellTarget818:100,nativeSpellMetamagic22d:16,nativeSpellClass22c:255},before=structuredClone(actor),state={};
 const fields=localClientCastFields(actor,{}, {spell:()=>null});assert.deepEqual(fields,[{type:'dword',value:37},{type:'object',value:0x80000064},{type:'bool',value:1}]);assert.deepEqual(actor,before);assert.equal(readClientCastFields(state,15,clientCastFieldReader(fields)),true);assert.deepEqual(state,{spellId:37,spellItemId:0x80000064,suppressSound:1});
 assert.equal(readClientCastFields(state,15,clientCastFieldReader(fields.slice(0,2))),false);assert.deepEqual(state,{spellId:37,spellItemId:0x80000064,suppressSound:1});
 actor.animationState=250;assert.deepEqual(localClientCastFields(actor,{},{}),[]);
});
