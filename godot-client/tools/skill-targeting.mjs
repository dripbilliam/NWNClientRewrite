import {NetworkSpellTargeting} from '../../src/network_spell_targeting.js';
import {OBJECT_INVALID} from '../../src/game_object_array.js';

// Original quickbar85c8f0 type3 -> action target702c30 mode2. The parent
// targeter continues to own spells/items/feats/server targets and lifetimes.
export class NativeSkillTargeting extends NetworkSpellTargeting{
 async begin(binding){
  if(binding.type!==3)return super.begin(binding);
  const value=binding.intParam;
  if(!Number.isInteger(value)||value< -0x80000000||value>0xffffffff)throw Error('Skill shortcut metadata is unavailable');
  this.reset();const actor=this.actor();if(!actor)throw Error('Controlled skill user is unavailable');
  const packedSkill=value|0;
  // Native initializer tests the full packed value, not just the skill BYTE.
  if(packedSkill===10)return this.submit({kind:'mode',modeId:2,targetId:OBJECT_INVALID});
  const targetTypes=packedSkill===9?[[10,37],[9,37]]:[[5,37]];
  this.pending={skillPlan:{packedSkill,targetTypes},controlledId:actor.id,world:this.world(),context:structuredClone(this.context())};
  if(packedSkill===22)return this.select(actor,[0,0,0]);
  this.onChange({skillId:packedSkill&255,cursor:37,badCursor:39,targetTypes});return{targeting:true};
 }
 presentation(target){
  if(!this.pending?.skillPlan)return super.presentation(target);
  let pending;try{pending=this.current();}catch{return null;}
  const valid=Boolean(target&&!target.replicationRemoved&&pending.skillPlan.targetTypes.some(([type])=>type===target.objectType));
  return{valid,cursor:valid?37:39,preview:null};
 }
 async select(target,position){
  if(!this.pending?.skillPlan)return super.select(target,position);
  const pending=this.current(),plan=pending.skillPlan;
  if(!target||target.replicationRemoved||!plan.targetTypes.some(([type])=>type===target.objectType))throw Error('That target is not valid for this skill');
  this.reset();return this.submit({kind:'skill',packedSkill:plan.packedSkill,targetId:target.id,position:[0,0,0]});
 }
}
