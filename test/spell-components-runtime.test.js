import test from 'node:test';
import assert from 'node:assert/strict';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';

test('component admission observes active custom spell columns and ruleset caps through canonical runtime',()=>{
  const s=new ModuleSession(null,{runStartupScripts:false});s.characterRules={
    classes:parse2da('2DA V2.0\n\nSpellCaster PlayerClass SpellTableColumn\n0 1 1 Custom'),
    spells:parse2da('2DA V2.0\n\nVS MetaMagic Custom Innate UserType\n0 vs 63 3 1 1')};
  const o=s.register('creature','caster',{creatureData:{ClassList:[{Class:0,ClassLevel:10}],FeatList:[{Feat:863},{Feat:860}]},stats:{feats:[863,860]}});
  o.nativeField8d4=0;const spell=s.spellBook.castingSpell(0);
  assert.deepEqual(s.spellBook.components(o,spell,0,0,0),{accepted:true,automaticStill:true,automaticSilent:true});
  s.characterRules.ruleset=parse2da('2DA V2.0\n\nLabel Value\n0 EPIC_AUTOMATIC_LESSER_STILL_LEVEL_CAP 3');
  assert.deepEqual(s.spellBook.components(o,spell,0,0,0),{accepted:false,clearConsumed:true,feedback:210});
});
test('ordinary component absence, exact exemption and metamagic rejection use active metadata without spending a slot',()=>{
  const s=new ModuleSession(null,{runStartupScripts:false});s.characterRules={classes:parse2da('2DA V2.0\n\nSpellCaster\n0 1'),
    spells:parse2da('2DA V2.0\n\nVS MetaMagic\n0 s 63')};
  const o=s.register('creature','caster',{creatureData:{ClassList:[{Class:0,ClassLevel:1}],FeatList:[]},stats:{feats:[]}});o.nativeField8d4=0;
  assert.equal(s.spellBook.components(o,s.spellBook.castingSpell(0),0,0,32).accepted,true);
  assert.equal(s.spellBook.components(o,s.spellBook.castingSpell(0),0,0,48).feedback,210);
  s.characterRules.spells=parse2da('2DA V2.0\n\nVS MetaMagic\n0 **** 0');
  assert.deepEqual(s.spellBook.components(o,s.spellBook.castingSpell(0),0,0,32),{accepted:false,clearConsumed:false,feedback:null});
});
