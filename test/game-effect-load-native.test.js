import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {loadGameEffect,savedEffectStorage} from '../src/game_effect_load.js';
import {readNativeGff} from '../src/native_gff_fields.js';
import {gffRecord,gffField,writeGff} from '../src/gff_writer.js';
import {parseGff} from '../src/gff.js';
import {ModuleSession} from '../src/module_session.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-game-effect-load-observations.json',import.meta.url)));
const decode=tree=>parseGff(writeGff('UTI ',tree),'UTI ').root;
test('whole saved-effect loader matches original typed defaults, payload loops and creator ordering',()=>{
 assert.equal(native.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
 for(const {case:c,output,calls}of native.cases){
  const actual=structuredClone(c.initial),trace=[];
  loadGameEffect(actual,decode(c.data),{read:(o,n,t,d)=>{const r=readNativeGff(o,n,t,d);trace.push([t===15?'list':'read',n,...(t===15?[]:[t]),r.status]);return r;},setCreator:(e,id)=>{
   trace.push(['creator',id,e.spellId,e.casterLevel]);e.creatorId=c.resolvedCreator;if(e.spellId===-1)e.spellId=777;if(e.casterLevel===-1)e.casterLevel=888;
  }});
  assert.deepEqual(actual,output,c.name);assert.deepEqual(trace,calls.filter(c=>c[0]!=='element'),c.name);
 }
});
test('unsafe saved-effect integer allocation/overflow and uninitialized list state stay explicit',()=>{
 const load=fields=>loadGameEffect(savedEffectStorage(),decode(gffRecord(fields)),{setCreator:(e,id)=>{e.creatorId=id;}});
 assert.throws(()=>load({NumIntegers:gffField(5,-1)}),/negative integer allocation/);
 assert.throws(()=>load({NumIntegers:gffField(5,1),IntList:gffField(15,[gffRecord({}),gffRecord({})])}),/exceeds allocated/);
 assert.throws(()=>load({FloatList:gffField(15,[])}),/uninitialized struct/);
});
test('live saved-effect loading preserves uint64 ID without consuming the effect allocator',()=>{
 const s=new ModuleSession(null,{runStartupScripts:false}),next=s.effects.nextId;
 const effect=s.effects.loadSaved(decode(gffRecord({Id:gffField(6,0xffffffffffffffffn),Type:gffField(2,91),SkipOnLoad:gffField(0,255)})));
 assert.equal(effect.id,'ffffffffffffffff');assert.equal(effect.skipOnLoad,1);assert.equal(effect.type,91);assert.equal(effect.creatorId,0);assert.equal(effect.exposed,0);assert.equal(effect.showIcon,0);assert.equal(effect.spellId,0);assert.deepEqual(effect.integers,[]);assert.equal(s.effects.nextId,next);
 const copied=s.effects.copyConstruct(effect,1);assert.equal(copied.skipOnLoad,0);assert.equal(copied.id,effect.id);assert.equal(s.effects.nextId,next);
});
