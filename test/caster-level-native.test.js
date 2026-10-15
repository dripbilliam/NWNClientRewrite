import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {parse2da} from '../src/area.js';
import {casterLevel,nativeClassLevel,nativeClassIndex,nativeFeatSourceClass} from '../src/spell_caster_level.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-caster-level-observations.json',import.meta.url)));
assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');
function fixture(c){
  const rows=c.classes??[{type:0,level:7,penalty:0},{type:1,level:3,penalty:1}],object={objectType:c.type??5,
    creatureData:{ClassList:rows.map(r=>({Class:r.type,ClassLevel:r.level,skillPenaltyByte:r.penalty??0})),LvlStatList:(c.history??[]).map(r=>({LvlStatClass:r.class,FeatList:r.feats.map(Feat=>({Feat}))}))},
    nativeCasterLevel344:c.aoeLevel??17,nativeCasterOverride820:c.overrideFlag??0,nativeCasterOverride824:c.overrideLevel??-20,
    nativeEquipmentLock97c:c.equipmentOverride??0,nativeSpellId218:1,nativeSpellClass22c:c.index??0,nativeSpellFeat23c:c.feat??65535};
  [object.nativeSpellOverride9e8,object.nativeSpellOverride9ec,object.nativeSpellOverride9f0]=c.overrideIds??[1,2,3];
  const rules={classes:parse2da(`2DA V2.0\n\nSpellCaster MinCastingLevel CLMultiplier\n0 ${c.spellCaster??1} ${c.minimum??1} ${c.factor??1}\n1 ${c.spellCaster??1} ${c.minimum??1} ${c.factor??1}`)};
  const p={asCreature:o=>o.objectType===5?o:null,asPlaceable:o=>o.objectType===9?o:null,asAreaOfEffect:o=>o.objectType===11?o:null,
    classLevel:(o,...args)=>nativeClassLevel(o,...args,rules),classIndex:nativeClassIndex,featSource:nativeFeatSourceClass,
    effects:()=>c.effects??[],effectInteger:e=>e.level,abilityLevel:()=>c.abilityLevel??255,spell:()=>c.spellExists===false?null:{innate:c.innate??1}};
  return{object,rules,p};
}
test('class slot, caster scaling, penalty and acquisition-source queries match original owners',()=>{
  for(const row of oracle.rows.filter(row=>row.case.mode)){const c=row.case,{object,rules}=fixture(c);
    const value=c.mode==='class'?nativeClassLevel(object,c.index??0,c.negative??1,c.multiply??1,rules):c.mode==='index'?nativeClassIndex(object,c.classType):nativeFeatSourceClass(object,c.feat);
    assert.equal(value,row.value,JSON.stringify(c));
  }
});
test('caster level matches original override, first polymorph effect, class/feat/spell-like and fallback branches',()=>{
  for(const row of oracle.rows.filter(row=>!row.case.mode)){const {object,p}=fixture(row.case);assert.equal(casterLevel(object,p),row.value,JSON.stringify(row.case));}
});
test('selected missing class multiplier/minimum cells fail instead of inventing native uninitialized values',()=>{
  const {object}=fixture({});object.creatureData.ClassList[0].ClassLevel=7;
  assert.throws(()=>nativeClassLevel(object,0,1,1,{classes:parse2da('2DA V2.0\n\nSpellCaster\n0 1')}),/uninitialized/);
  assert.throws(()=>nativeClassLevel(object,0,1,1,{classes:parse2da('2DA V2.0\n\nSpellCaster MinCastingLevel\n0 1 0')}),/uninitialized/);
  assert.equal(nativeClassLevel(object,0,1,0,{}),7);
});
test('live caster query uses canonical class penalty, active multiplier and spell-like fields',()=>{
  const s=new ModuleSession(null,{runStartupScripts:false});s.characterRules={classes:parse2da('2DA V2.0\n\nSpellCaster MinCastingLevel CLMultiplier\n0 1 3 .5'),spells:parse2da('2DA V2.0\n\nInnate\n0 1')};
  const o=s.register('creature','caster',{creatureData:{ClassList:[{Class:0,ClassLevel:9,skillPenaltyByte:2}]},nativeSpellId218:0,nativeSpellClass22c:0});
  assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),3);
  o.nativeSpellClass22c=254;o.nativeSpellLikeAbilities=[{id:0,casterLevel:7,remaining:0}];assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),7);
  o.nativeSpellLikeAbilities=[];o.nativeSpellId218=-1;assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),255);
  o.nativeCasterOverride820=2;o.nativeCasterOverride824=23;assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),23);
  assert.equal(s.commands.GetCasterLevel([0x7f000000],{self:o.id}),0);
  o.nativeCasterOverride820=0;o.nativeSpellId218=0;o.nativeSpellClass22c=0;o.nativeSpellOverride9e8=0;
  o.nativeField97c=1;assert.equal(o.nativeEquipmentLock97c,1);assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),9);
  o.nativeEquipmentLock97c=0;assert.equal(o.nativeField97c,0);assert.equal(s.commands.GetCasterLevel([o.id],{self:o.id}),3);
  assert.throws(()=>s.register('creature','conflict',{nativeField97c:1,nativeEquipmentLock97c:0}),/Conflicting.*97c/);
});
