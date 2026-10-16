import {useFeat,featActivationInfo,featActivationSpell} from './use_feat.js';
import {addSpecialAttack} from './combat_round.js';
import {manageObjectActions} from './object_actions.js';
import {creatureRoot} from './creature_rules.js';
import {intEntry} from './combat_stats.js';
import {receiveFeatInput} from './combat_input.js';
import {scriptUseFeat} from './script_use_feat.js';

// Canonical adapter shared by script and decoded player feat activation.
// Feat use pools, spell/effect ownership and queued impacts remain shared.
export class FeatRuntime{
  constructor(session){this.session=session;}
  providers(){
    const s=this.session,c=s.combat;
    return {highest:(...a)=>c.highestFeat(...a),hasFeat:(...a)=>c.hasFeat(...a),remaining:(...a)=>c.remainingUses(...a),
      object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      feat:id=>featActivationInfo(s.characterRules,id),spell:id=>featActivationSpell(s.characterRules,id),reaction:(...a)=>s.aiReaction(...a),
      feedback:(...a)=>s.spells.feedback(...a),possessed:o=>Number(o.isPossessedFamiliar??false),ranged:o=>c.rangedEquipped(o),
      equipped:(o,slot)=>s.equipmentSlot(o,slot),base:i=>{const base=s.items.baseInfo(i);if(!base)throw new Error('Native feat weapon base storage is unavailable');return {...base,monkWeapon:intEntry(s.characterRules.baseitems,i.baseItem,'IsMonkWeapon').value};},
      addAttack:(...a)=>c.requestAttack(...a),addSpecial:(o,id)=>addSpecialAttack(o.combatRound,id,message=>c.warning(o,message)),setMode:(...a)=>c.setCombatMode(...a),
      classCount:o=>creatureRoot(o).ClassList.length,classType:(o,index)=>creatureRoot(o).ClassList[index]?.Class??255,monkClass:5,otherFlurryClass:40,
      relativeSize:(o,i)=>s.weaponSelectionProviders(o).relativeSize(o,i),weaponOfChoice:(o,base)=>{const row=s.characterRules.baseitems.orderedRows[base>>>0];if(!row)return 0;const entry=intEntry(s.characterRules.baseitems,base,'WeaponOfChoiceFeat');return c.hasFeat(o,entry.found?entry.value&65535:65535);},
      random:()=>s.random.next(),actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(c.broadcastProviders().client(o.id)),clearActions:o=>c.clearActions(o)}),
      effects:o=>o.effects,setEffectInteger:(e,index,value)=>{if(!Array.isArray(e.integers)||index>=e.integers.length)throw new Error('Native polymorph effect integer storage is unavailable');e.integers[index]=value|0;},removeEffect:(o,id)=>s.effects.remove(o.id,id),
      allocateImpact:()=>({}),area:o=>s.registry.get(o.areaId)??null,enqueue:(...a)=>c.enqueueEvent(...a),hasStats:o=>Boolean(o.stats),decrement:(...a)=>c.decrementUses(...a),
      addCast:(o,r)=>s.spells.add(o,r),warning:message=>c.warning(s.player,message)};
  }
  use(actor,id,auxiliary,targetId,areaId,point){if(actor?.objectType!==5)return 0;return useFeat(actor,id,auxiliary,targetId,areaId,point,this.providers());}
  script(args,frame){
    const s=this.session;
    return scriptUseFeat(args,frame.self,{object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,
      asObject:o=>o.objectType>4?o:null,position:o=>[Math.fround(o.position[0]),Math.fround(-o.position[2]),Math.fround(o.position[1])],
      area:o=>s.registry.get(o.areaId)??null,areaById:id=>{const o=s.registry.get(id);return o?.kind==='area'?o:null;},
      spell:id=>featActivationSpell(s.characterRules,id),use:(...a)=>this.use(...a)});
  }
  input(request){
    const s=this.session;let word=0,axis=0;
    return receiveFeatInput(null,{clientObject:()=>s.player,asCreature:o=>o?.objectType===5?o:null,overflow:()=>0,underflow:()=>0,
      readWord:()=>word++===0?request.featId:request.auxiliary,readObjectId:()=>request.targetId,readFloat:()=>request.position[axis++],
      area:o=>s.registry.get(o.areaId)??null,use:(...a)=>this.use(...a)});
  }
}
