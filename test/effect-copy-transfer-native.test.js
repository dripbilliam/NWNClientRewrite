import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {ModuleSession} from '../src/module_session.js';
import {applyBeamEffect} from '../src/visual_effect.js';
import {applyVisionSource,removeVisionSource} from '../src/vision_effect.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-effect-copy-transfer-observations.json',import.meta.url)));
test('beam selected payload and vision suppression full-copy/fresh-ID sequence match original complete owners',async()=>{
 for(const row of oracle.rows){
  const c=row.case,s=new ModuleSession(null),o={objectType:c.objectType,visionFlags:c.flags??0},source=structuredClone(row.source),before=structuredClone(source),calls=[];let effects=structuredClone(row.initial);s.effects.nextId=100n;
  // Native removal excludes the same pointer, so retain that identity when
  // the incoming source is itself one of the initial live records.
  effects=effects.map(e=>e.id===source.id?source:e);
  const p={copyConstruct:(...a)=>s.effects.copyConstruct(...a),assignFresh:e=>s.effects.assignFresh(e),assignPreservingId:e=>s.effects.assignPreservingId(e),inDarkness:()=>c.darkness,effects:()=>effects,
   apply:(_o,e,loading)=>{calls.push(['apply',structuredClone(e),loading]);effects.push(e);effects.sort((a,b)=>a.type-b.type);},
   remove:(_o,e)=>{calls.push(['remove',e.id]);effects=effects.filter(other=>other.id!==e.id);}};
  const result=await(c.mode==='beam'?applyBeamEffect:c.mode.startsWith('remove')?removeVisionSource:applyVisionSource)(o,source,p,c.loading??0);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(effects,row.effects,JSON.stringify(c));assert.equal(o.visionFlags,row.flags);assert.equal(s.effects.nextId.toString(16).padStart(16,'0'),row.nextId);assert.deepEqual(source,before,'parent arguments survive child construction and assignment');
 }
});
