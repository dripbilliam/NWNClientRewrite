import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spellLikeCastRequest} from '../src/network_spell_input.js';
import {networkSpellLikeUses} from '../src/network_spellbook.js';
import {NetworkSpellTargeting} from '../src/network_spell_targeting.js';
import {NetworkWorld} from '../src/network_world.js';
import {parse2da} from '../src/area.js';

test('160 original innate sender/server cases retain native bytes and distinct object/location talent routing',()=>{
 const f=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-network-spell-like-request-observations.json',import.meta.url)));
 assert.equal(f.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(f.cases.length,160);
 for(const row of f.cases){const c=row.case;if(c.format!==1)continue;
  const actual=spellLikeCastRequest({...c,position:c.point}),native=Buffer.from(row.packet,'hex'),used=native.at(-1)>>>5,mask=255<<(8-used)&255;
  assert.equal(actual.length,native.length);assert.deepEqual(Buffer.from(actual.subarray(0,-1)),native.subarray(0,-1),JSON.stringify(c));assert.equal(actual.at(-1)&mask,native.at(-1)&mask);
  const cast=row.calls.find(v=>v.kind==='cast');if(!cast)continue;
  assert.equal(cast.spell,c.spellId);assert.equal(cast.classIndex,254);assert.equal(cast.domainLevel,0);assert.equal(cast.metamagic,0);assert.equal(cast.conversion,0);assert.equal(cast.casterLevel,c.casterLevel);
  if(c.targetId!==0x7f000000){assert.equal(cast.targetId,(c.targetId&0x7fffffff)>>>0);assert.equal(cast.location,0);assert.deepEqual(cast.position,[4.25,5.5,6.75]);}
  else{assert.equal(cast.targetId,0x7f000000);assert.equal(cast.location,1);if(c.point[0]===1.25)assert.deepEqual(cast.position,[1.25,-2.5,Math.fround(3.75+Math.fround(.3))]);}
 }
 for(const flag of ['noActor','noStats','blocked','commandable','missingSpell'])assert.ok(f.cases.filter(r=>flag==='commandable'?r.case.commandable===0:r.case[flag]).every(r=>!r.calls.some(v=>v.kind==='cast')));
 // The ordinary innate location wrapper queues directly. GetArea belongs to
 // its item-use branch and is not a prerequisite of this request path.
 assert.ok(f.cases.some(r=>r.case.missingArea&&r.case.targetId===0x7f000000&&r.calls.some(v=>v.kind==='cast')));
 assert.ok(f.cases.some(r=>r.case.missingCreature&&r.case.targetId!==0x7f000000&&!r.calls.some(v=>v.kind==='cast')));
 for(const fields of [{spellId:-1},{casterLevel:256},{casterLevel:NaN},{targetId:-1},{position:[0,0,Infinity]}])assert.throws(()=>spellLikeCastRequest({spellId:1,casterLevel:1,...fields}));
});

test('innate UI preserves native caster-level nibble and counts ready records without spending replicated state',async()=>{
 const world=new NetworkWorld(),id=0xffffffff,areaId=0x80000001,actor={id,objectType:5,areaId,replicated:{position:[1,2,3]},playerState:{specialAbilities:[{spell:0,level:7,state:2},{spell:0,level:7,state:0},{spell:0,level:7,state:1},{spell:0,level:23,state:1}]}};
 world.localObjectId=id;world.areaId=areaId;world.registry.addObjectAtPos(id,actor);const before=structuredClone(actor),sent=[],spells=parse2da('2DA V2.0\n\nName TargetType Master\n0 1 1 0\n');
 const t=new NetworkSpellTargeting({world:()=>world,tables:()=>({spells}),context:()=>({generation:1}),submit:async r=>sent.push(r)});
 assert.equal(networkSpellLikeUses(actor,0,7),2);assert.equal(networkSpellLikeUses(actor,0,23),1);assert.equal(networkSpellLikeUses(actor,0,8),0);
 await t.begin({type:44,intParam:0,domainLevel:23});assert.equal(t.active,false);assert.deepEqual(sent[0],{kind:'innate',spellId:0,casterLevel:7,targetId:id,position:[1,2,3]});
 await t.radialInnate({spellId:0,domainLevel:255},actor,[1.1,2,3]);assert.equal(sent[1].casterLevel,15);assert.deepEqual(sent[1].position,[Math.fround(1.1),2,3]);
 await assert.rejects(t.radialInnate({spellId:0,domainLevel:1},null,[1,2,3]),/not valid/);assert.deepEqual(actor,before);
});
