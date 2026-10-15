import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {addLoopingVisual,removeLoopingVisual} from '../src/visual_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-looping-visual-observations.json',import.meta.url)));
const transform=token=>({scale:token,translate:[0,0,0],rotate:[0,0,0]});
test('loop list growth, field widths, duplicate removal and shifts match original list instructions',()=>{
  for(const row of oracle.rows){const c=row.case,actor={nativeLoopingVisuals160:{capacity:c.capacity,records:c.rows.map(([visualId,sourceId,bodyPart,token])=>({visualId,sourceId,bodyPart,transform:transform(token)}))}},[id,source,body,token]=c.value;
    (c.mode==='add'?addLoopingVisual:removeLoopingVisual)(actor,id,source,body,transform(token));
    assert.equal(actor.nativeLoopingVisuals160.capacity,row.capacity,JSON.stringify(c));
    assert.deepEqual(actor.nativeLoopingVisuals160.records.map(r=>[r.visualId,r.sourceId,r.bodyPart,r.transform.scale]),row.rows,JSON.stringify(c));
  }
});
test('live visual effect expiration removes one matching loop and retains other active copies',async()=>{
  const s=new ModuleSession(null),o=s.register('creature','target',{position:[0,0,0]}),caster=s.register('creature','caster',{});
  s.characterRules={visualeffects:{orderedRows:[{Type_FD:'B'}],columns:['Type_FD']}};
  const make=()=>s.commands.EffectVisualEffect([0],{self:caster.id});
  await s.effects.apply(2,make(),o.id);await s.effects.apply(1,make(),o.id,1);
  assert.equal(o.nativeLoopingVisuals160.records.length,2);assert.equal(o.effects.length,2);
  s.scheduler.time=1000;await s.effects.updateObject(o);assert.equal(o.effects.length,2);
  s.scheduler.time=1001;await s.effects.updateObject(o);assert.equal(o.effects.length,1);assert.equal(o.nativeLoopingVisuals160.records.length,1);
  await s.effects.remove(o.id,o.effects[0].id);assert.equal(o.nativeLoopingVisuals160.records.length,0);
});
