import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {constructVisualEffect} from '../src/visual_effect.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-visual-constructor-observations.json',import.meta.url)));
test('visual constructor scalar/vector stores and legacy defaults match original command execution',()=>{
  const s=new ModuleSession(null),actor=s.register('creature','caster',{});
  actor.nativeEffectSpellId774=17;actor.nativeCasterOverride820=1;actor.nativeCasterOverride824=3;
  for(const row of oracle.rows){
    const c=row.case,args=[c.id??1];if(c.argc>=2)args.push(c.miss??0);if(c.argc>=5)args.push(c.scale??1,c.translate??[1,2,3],c.rotate??[4,5,6]);
    const e=constructVisualEffect(args,actor.id,{create:(...args)=>s.effects.create(...args)}),actual={};
    for(const key of ['type','subtype','creatorId','spellId','casterLevel','integers','floats','vectors'])actual[key]=e[key];
    assert.deepEqual(actual,{...row.output,creatorId:actor.id},JSON.stringify(c));
  }
});
test('partially specified transform VM ownership remains explicit',()=>{
  for(const args of [[1,0,2],[1,0,2,[1,2,3]]])assert.throws(()=>constructVisualEffect(args,99,{}),/partial visual-transform/);
});
