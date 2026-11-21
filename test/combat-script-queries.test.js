import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {hasFeatEffectApplied,hasSpellEffectApplied} from '../src/feat_effect.js';
import {arcaneSpellFailure} from '../src/arcane_spell_failure.js';
import {scriptIntToFloat} from '../src/script_scalar.js';
import {abilityModifierCells,scriptAbilityModifier} from '../src/ability_modifier_cache.js';
import {initializeTalentSpellState,TalentRuntime} from '../src/talent_runtime.js';
import {ModuleSession} from '../src/module_session.js';
import {parse2da} from '../src/area.js';
import {scriptDistanceBetween} from '../src/script_geometry.js';
import {playableRacialType} from '../src/playable_race.js';
const capture=JSON.parse(readFileSync(new URL('../backups/animations/native-combat-query-observations.json',import.meta.url)));

test('feat/spell effect queries match96 original executions without type, exposure or duration filtering',()=>{
  assert.equal(capture.effects.length,48);
  for(const {case:c,feat,spell} of capture.effects){
    const row={Feat:c.valid?'0':'****',SpellId:String(c.spell)},rules={feat:{rows:new Map([[0,row]]),orderedRows:[row]}};
    const o={effects:c.entries.map(spellId=>({spellId,type:0,exposed:false,durationType:0}))};
    assert.equal(hasFeatEffectApplied(o,65536,rules),feat);assert.equal(hasSpellEffectApplied(o,c.spell),spell);
  }
});
test('arcane-failure query matches343 native signed BYTE sum and clamp observations',()=>{
  assert.equal(capture.arcane.length,343);
  for(const c of capture.arcane)assert.equal(arcaneSpellFailure({nativeArcaneEffectD78:c.bytes[0],nativeArcaneChestD79:c.bytes[1],nativeArcaneShieldD7a:c.bytes[2]}),c.result,JSON.stringify(c));
  assert.throws(()=>arcaneSpellFailure({nativeArcaneFailurePropertiesPending:true}),/property owner/);
});
test('IntToFloat and ability modifier getters match102 original wrapper observations',()=>{
  assert.equal(capture.scalar.length+capture.abilities.length,102);
  for(const c of capture.scalar)assert.equal(scriptIntToFloat(c.input),c.result);
  for(const {case:c,result} of capture.abilities){const o=Object.fromEntries(abilityModifierCells.map(field=>[field,c.value]));assert.equal(scriptAbilityModifier(c.present?o:null,c.input),result);}
});
test('between-object distance returns0 for invalid lookup and retains3D distance across different areas; playable race uses the native seven constants',()=>{
  const a={areaId:1,position:[0,0,0]},b={areaId:2,position:[3,12,-4]};assert.equal(scriptDistanceBetween(a,b),13);assert.equal(scriptDistanceBetween(null,b),0);
  for(const race of [-1,0,1,2,3,4,5,6,7,28,65536])assert.equal(playableRacialType({objectType:5,stats:{race}}),Number((race&65535)<=6));
  assert.equal(playableRacialType({objectType:9,stats:{race:0}}),0);
});
test('talent state owns constructor pools for caster/noncaster classes before the separate GFF import',async()=>{
  const s=new ModuleSession(null);s.characterRules={classes:parse2da('2DA V2.0\n\nSpellCaster MemorizesSpells\n0 0 0\n1 1 1'),spells:parse2da('2DA V2.0\n\nInnate Category\n0 1 16')};
  const o=s.register('creature','o',{authored:{ClassList:[{Class:0,SpellsPerDayList:[{NumSpellsLeft:256},{NumSpellsLeft:257}]}],SpecAbilityList:[{Spell:65536,SpellFlags:2,SpellCasterLevel:255}]}});
  initializeTalentSpellState(o,s.characterRules);assert.deepEqual(o.nativeSpellLikeAbilities,[{id:0,remaining:1,casterLevel:15}]);assert.deepEqual(o.nativeTalentClasses[0].perDay.slice(0,2),[0,1]);
  const runtime=new TalentRuntime(s);assert.equal(runtime.hasSpell(o,0),1);
  o.authored={ClassList:[{Class:0}]};initializeTalentSpellState(o,s.characterRules);assert.equal(runtime.hasSpell(o,0),0);
  o.authored={ClassList:[{Class:1}]};initializeTalentSpellState(o,s.characterRules);assert.deepEqual(runtime.spellPool(o,0,'memorized'),Array.from({length:10},()=>[]));
  o.authored={ClassList:[{Class:0,KnownList0:[{Spell:0}]}]};initializeTalentSpellState(o,s.characterRules);assert.deepEqual(runtime.spellPool(o,0,'known'),Array.from({length:10},()=>[]));
});
