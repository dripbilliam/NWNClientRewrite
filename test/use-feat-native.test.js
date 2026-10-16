import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {useFeat,featActivationInfo} from '../src/use_feat.js';
import {parse2da} from '../src/area.js';

test('active feat metadata distinguishes conditional defaults from the unconditional HostileFeat output',()=>{
 const rules={feat:parse2da('2DA V2.0\nDEFAULT: 7\n\nFeat SpellId ReqAction TargetSelf HostileFeat\n0 123 **** **** **** ****\n1 124 -1 -5 2 -4\n2 125 50 0 0 1')};
 assert.deepEqual(featActivationInfo(rules,0),{spellId:-1,reqAction:1,targetSelf:0,hostile:0});
 assert.deepEqual(featActivationInfo(rules,1),{spellId:-1,reqAction:1,targetSelf:2,hostile:-4});
 assert.deepEqual(featActivationInfo(rules,2),{spellId:50,reqAction:0,targetSelf:0,hostile:1});
 const missingColumns={feat:parse2da('2DA V2.0\nDEFAULT: 7\n\nFeat\n0 123')};
 assert.deepEqual(featActivationInfo(missingColumns,0),{spellId:-1,reqAction:1,targetSelf:0,hostile:7});
});

test('complete UseFeat branching, form variants, immediate impact and queued casting match original instructions',async()=>{
  const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-use-feat-observations.json',import.meta.url)));
  for(const {case:c,result,calls}of oracle.rows){
    const actual=[],actor={id:99,nativeField771:c.state,nativeField89c:c.pc},target={id:100,nativeField97c:c.locked},item={baseItem:c.baseItem},effect={id:123,type:62};
    const info={spellId:c.spellId,reqAction:c.reqAction,targetSelf:c.targetSelf,hostile:c.hostile};
    const p={highest:(_o,id)=>{actual.push(['highest',id]);return c.highest;},hasFeat:(_o,id)=>{actual.push(['hasFeat',id]);return id===c.highest?c.owned:Number(c.extraFeats.includes(id));},
      object:id=>{actual.push(['object',id]);return c.targetExists?target:null;},asCreature:()=>{actual.push(['asCreature']);return c.targetCreature?target:null;},
      feat:id=>{actual.push(['feat',id]);return c.missingFeat?null:info;},reaction:(_o,id)=>{actual.push(['reaction',id]);return c.reaction;},remaining:(_o,id)=>{actual.push(['remaining',id]);return c.remaining;},feedback:(_o,id)=>actual.push(['feedback',id]),
      possessed:()=>{actual.push(['possessed']);return c.possessed;},ranged:()=>{actual.push(['ranged']);return c.ranged;},setMode:(_o,...args)=>actual.push(['mode',...args]),
      addAttack:(_o,...args)=>{actual.push(['attack',...args]);return c.addResult;},addSpecial:(_o,id)=>actual.push(['special',id]),
      equipped:(_o,slot)=>{actual.push(['equipped',slot]);return c.item?item:null;},base:item=>{actual.push(['base',item.baseItem]);return {ranged:c.baseRanged,monkWeapon:c.monkWeapon};},
      classCount:()=>c.classes.length,classType:(_o,i)=>{actual.push(['classType',i]);return c.classes[i];},monkClass:5,otherFlurryClass:40,
      relativeSize:()=>{actual.push(['relativeSize']);return c.relativeSize;},weaponOfChoice:(_o,id)=>{actual.push(['weaponOfChoice',id]);return c.weaponOfChoice;},random:()=>{actual.push(['random']);return c.random;},actionManager:(_o,n)=>actual.push(['manager',n]),
      creature:id=>{actual.push(['creature',id]);return c.targetCreature?target:null;},effects:()=>c.hasEffect?[effect]:[],setEffectInteger:(_e,...a)=>actual.push(['setInteger',...a]),removeEffect:(_o,id)=>actual.push(['remove',id]),
      spell:id=>{id>>>=0;actual.push(['spell',id]);if(c.missingSpell||c.missingChildren.includes(id))return null;if(id===c.spellId)return {targetType:c.targetMask,children:c.children.map((_,i)=>100+i),impactScript:'parent'};const index=id-100;return index>=0&&index<c.children.length?{featId:c.children[index],children:[],impactScript:`child${index}`} :null;},
      allocateImpact:()=>{actual.push(['allocate']);return c.allocationFail?null:{};},area:()=>{actual.push(['area']);return c.area?{id:7}:null;},hasStats:()=>c.hasStats,
      enqueue:(event,caller,recipient,_time,d)=>actual.push(['enqueue',event,recipient,caller,d.spellId,d.featId,d.casterId,d.targetId,d.itemId,d.position,d.script,d.areaId]),decrement:(_o,id)=>actual.push(['decrement',id]),
      addCast:(_o,r)=>{actual.push(['cast',r.spellId,r.classIndex,r.domainLevel,r.metamagic,r.spontaneous,r.position,r.targetId,r.location,r.front,r.cheat,r.path,r.instant,1,r.featId,r.casterLevel]);return c.addResult;},warning:message=>actual.push(['warning',message])};
    assert.equal(await useFeat(actor,c.requested,c.auxiliary,c.targetId,7,c.point,p),result,JSON.stringify(c));assert.deepEqual(actual,calls,JSON.stringify(c));
  }
});
