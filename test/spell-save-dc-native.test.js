import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parse2da} from '../src/area.js';
import {computeSpellSaveDC} from '../src/spell_save_dc.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-spell-save-dc-observations.json',import.meta.url)));
test('spell save DC matches untouched native class, focus and override branches',()=>{
  for(const row of oracle.rows){
    const c=row.case,actor={nativeCasterOverride820:c.override??0,nativeEquipmentLock97c:Number(c.equipment??0),nativeSpellOverride9e8:c.overrideSpell??1,
      nativeSpellOverride9ec:-1,nativeSpellOverride9f0:-1,nativeSpellClass22c:c.class??0,nativeSpellDomain21c:c.domain??0,nativeSpellFeat23c:c.feat??65535},abilityCalls=[];
    const rules={ruleset:parse2da(`2DA V2.0\n\nLabel Value\n${Object.entries(c.rulesOverrides??{}).map(([label,value],i)=>`${i} ${label} ${value}`).join('\n')}`)};
    const p={spell:id=>c.spellExists===false||id===2&&c.masterMissing?null:{id,master:2,innate:c.innate??1},
      effects:()=>c.effects?.map(type=>({type}))??[],effectInteger:(_e,index)=>index===5?c.effectFlag??1:c.effectAbility??5,
      classIndex:()=>c.sourceIndex??0,classAbility:()=>c.classAbility??3,classPrimaryAbility:()=>c.primaryAbility??0,
      abilityMod:(_o,index)=>{if(actor.nativeSpellClass22c!==254||actor.nativeEquipmentLock97c!==0&&actor.nativeSpellOverride9e8===1)abilityCalls.push(index);return index<6?(c.abilityMods??[0,1,2,3,4,5])[index]:0;},
      featSource:()=>c.sourceType??10,classLevel:()=>c.classLevel??3,castingMod:()=>c.modifier??3,classType:()=>c.classType??10,
      negativeLevels:()=>c.penalty??0,level:()=>c.level??1,school:()=>c.school??0,hasFeat:(_o,id)=>c.feats?.includes(id)?c.featResult??1:0};
    assert.equal(computeSpellSaveDC(actor,1,rules,p),row.result,JSON.stringify(c));assert.deepEqual(abilityCalls,row.abilityCalls,JSON.stringify(c));
  }
});
