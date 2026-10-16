import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {initializeBonusFeats,applyBonusFeat,removeBonusFeat,hasBonusFeat,bonusFeats} from '../src/bonus_feat_effect.js';
import {hasNativeFeat,removeNativeFeat,FeatUsePool} from '../src/feat_uses.js';
import {ModuleSession} from '../src/module_session.js';
const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-bonus-feat-observations.json',import.meta.url)));
test('bonus feat handlers, pool growth, group removal and ordinary membership match complete original owners',()=>{
 assert.equal(oracle.binarySha256,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.rows.length,2876);
 for(const row of oracle.rows){const c=row.case,o={objectType:c.creature===false?6:5,nativeBonusFeats20:(c.bonuses??[]).map(v=>v&65535),nativeBonusFeatCapacity2c:c.capacity??c.bonuses?.length??0,
  creatureData:{FeatList:(c.permanent??[]).map(Feat=>({Feat})),ClassList:(c.classes??[]).map(Class=>({Class}))},effects:(c.effects??[]).map(e=>({type:e.type??83,id:BigInt(e.id??78).toString(16).padStart(16,'0'),integers:[e.feat??289]}))},effect={id:'000000000000004d',integers:[c.id??289]},previous=o.nativeBonusFeatCapacity2c;let result;
  if(c.mode==='apply')result=applyBonusFeat(o,effect);else if(c.mode==='remove')result=removeBonusFeat(o,effect);else if(c.mode==='hasBonus')result=hasBonusFeat(o,c.id??289);else result=hasNativeFeat(o,c.id??289,()=>c.armor??0);
  assert.equal(result,row.result,JSON.stringify(c));assert.deepEqual(bonusFeats(o),row.bonuses,JSON.stringify(c));assert.equal(o.nativeBonusFeatCapacity2c,row.capacity,JSON.stringify(c));
  const realloc=o.nativeBonusFeatCapacity2c>previous?[['realloc',o.nativeBonusFeatCapacity2c*2]]:[];assert.deepEqual(realloc,row.calls,JSON.stringify(c));
 }
});
test('live bonus pool aliases the legacy adapter without changing permanent feat storage or source object identity',()=>{
 const s=new ModuleSession(null),o=s.register('creature','bonus-owner',{creatureData:{FeatList:[{Feat:289}],ClassList:[]},stats:{feats:[289]},pendingFeats:[289]});assert.equal(o.pendingFeats,o.nativeBonusFeats20);assert.equal(initializeBonusFeats(o),o.pendingFeats);
 o.featUsePool=new FeatUsePool();removeNativeFeat(o,289);assert.equal(o.creatureData.FeatList.length,0);assert.equal(hasNativeFeat(o,289),1);assert.deepEqual(o.stats.feats,[289]);assert.equal(s.registry.get(o.id),o);
});
test('EffectBonusFeat constructor validates narrowed active feat rows but retains its raw INT and creator even when invalid',()=>{
 assert.equal(oracle.constructors.length,18);
 for(const row of oracle.constructors){const c=row.case;if(c.pop===0||c.push===0){assert.equal(row.result,c.pop===0?0xfffffd81:0xfffffd82);continue;}
  const s=new ModuleSession(null),rows=Array.from({length:1000},()=>({Feat:'****'}));if(c.validFeat&&(c.id&65535)<1000)rows[c.id&65535]={Feat:'0'};s.characterRules={feat:{orderedRows:rows}};
  const e=s.commands.EffectBonusFeat([c.id],{self:99});assert.deepEqual({type:e.type,subtype:e.subtype,durationType:e.durationType,creatorId:e.creatorId,integers:e.integers},row.output,JSON.stringify(c));assert.equal(row.result,0);
 }
});
