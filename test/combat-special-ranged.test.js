import test from 'node:test';
import assert from 'node:assert/strict';
import {resolveRangedSpecialAttack as special} from '../src/combat_special_ranged.js';
import {createCombatRound} from '../src/combat_round.js';
function fixture(){
  const actor={id:1,combatRound:createCombatRound()},target={id:2},data=actor.combatRound.attacks[0],trace=[];data.attackType=65000;data.result=1;data.damage[12]=1;data.roll=20;data.modifier=10;
  const p={creature:o=>{trace.push('cast');return o;},attackRoll:()=>trace.push('roll'),damage:()=>trace.push('damage'),postDamage:()=>trace.push('post'),miss:()=>trace.push('miss'),animations:()=>trace.push('animation'),
    limb:()=>1,skill:()=>0,random:{next:()=>{trace.push('draw');return 0;}},effect:(type,creatorId,integers,subtype)=>({type,creatorId,integers,subtype}),message:(type,fields)=>({type,...fields})};
  return{actor,target,data,p,trace};
}
test('ranged special performs normal native owners first, then called leg effects with active duration and penalties',async()=>{
  const {actor,target,data,p,trace}=fixture();await special(actor,target,500,{},p);
  assert.deepEqual(trace,['cast','cast','roll','damage','post','animation','draw']);
  assert.deepEqual(data.lists[0],[{type:37,creatorId:1,integers:[1,2,3],subtype:0,durationType:1,duration:24},{type:29,creatorId:1,integers:[20],subtype:0,durationType:1,duration:24}]);
});
test('called arm uses concentration signed BYTE and native inclusive success changes result to5 after animations',async()=>{
  const {actor,target,data,p,trace}=fixture();data.attackType=65001;data.roll=1;data.modifier=0;p.skill=()=>256;
  await special(actor,target,500,{},p);assert.equal(data.result,5);assert.deepEqual(data.lists[0],[]);assert.equal(trace.at(-1),'draw');
});
test('called arm failed resistance creates timed type11 with native subtype/type flag constants',async()=>{
  const {actor,target,data,p}=fixture();data.attackType=65001;await special(actor,target,500,{},p);
  assert.deepEqual(data.lists[0][0],{type:11,creatorId:1,integers:[2,0,28],subtype:0,durationType:1,duration:24});
});
test('absent limb produces distinct leg/arm feedback and result6 without a random draw',async()=>{
  for(const [type,code] of [[65000,29],[65001,30]]){
    const {actor,target,data,p}=fixture();data.attackType=type;p.limb=()=>0;p.random.next=()=>assert.fail('No resistance draw');
    await special(actor,target,500,{},p);assert.equal(data.result,6);assert.deepEqual(data.lists[3],[{type:3,integers:[code]}]);
  }
});
test('unknown specials fall through, misses resolve endpoint before animation, and zero damage becomes6 without limb lookup',async()=>{
  const {actor,target,data,p,trace}=fixture();data.attackType=9;data.result=4;
  await special(actor,target,500,{},p);assert.deepEqual(trace,['cast','cast','roll','miss','animation']);
  data.attackType=65000;data.result=1;data.damage.fill(0);p.limb=()=>assert.fail('No limb read');
  await special(actor,target,500,{},p);assert.equal(data.result,6);
});
