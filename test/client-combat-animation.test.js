import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {selectClientMeleeAnimation,clientWeaponAnimationClass,clientAttackAnimationRecord} from '../src/client_combat_animation.js';
import {NativeRandom} from '../src/native_random.js';
import {createAttackData} from '../src/combat_attack_data.js';
import {deathAnimation} from '../src/death_effects.js';
const render=v=>[v[0],v[2],-v[1]];

test('death body/animation selection matches60 native animation-phase observations',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-client-combat-animation-observations.json',import.meta.url)));
  assert.equal(oracle.deathObservations.length,60);
  for(const c of oracle.deathObservations){
    const pose=deathAnimation({nativeBodyState:c.body,position:[0,0,0],orientation:render(c.orientation)},c.source?{position:render(c.source)}:null);
    assert.deepEqual(pose??{body:c.body&255,animation:65535},c.result,JSON.stringify(c));
  }
});

test('client melee animation choices, directional reactions, side changes and RNG match2592 native executions',()=>{
  const oracle=JSON.parse(readFileSync(new URL('../backups/animations/native-client-combat-animation-observations.json',import.meta.url)));
  assert.equal(oracle.observations.length,2592);
  for(const c of oracle.observations){
    const context={fieldDD:c.style,fieldE0:c.side},actor={id:21,position:render(c.position),side:c.side},target={id:22,objectType:5,position:[0,0,0]};
    const record={targetId:22,reaction:c.reaction,weaponAttackType:1},random=new NativeRandom(c.seed);
    const distance=Math.hypot(...c.position),reach=distance+(c.branch===1?1:c.branch===3?-1:0);
    const p={context:()=>context,target:()=>target,hitDistance:()=>0,preferredDistance:()=>reach,baseAnimation:()=>c.targetBase,
      orientation:()=>render(c.orientation),lockTarget:()=>c.lockTarget,targetHeight:()=>c.height,
      hasMonkClass:()=>c.monk,equipped:()=>c.shield?{id:101}:null,baseItem:()=>14,
      attackWeapon:()=>c.weapon?{id:100}:null,baseInfo:()=>c.validBase?{slashLeft:c.slashLeft,slashRight:c.slashRight}:null,random:()=>random.next()};
    const animation=selectClientMeleeAnimation(actor,record,p);
    assert.deepEqual({animation,reaction:record.reaction,side:actor.side,contextSide:context.fieldE0,draws:random.draws},c.result,JSON.stringify(c));
  }
});

test('client weapon class follows relative size, shield, dual wield and all ranged wield classes',()=>{
  let right=null,left=null,context={fieldDD:0,fieldDF:0},size=0;
  const p={context:()=>context,equipped:(o,slot)=>slot===16?right:left,baseInfo:i=>i,weaponSize:()=>size,warning:()=>assert.fail()};
  assert.equal(clientWeaponAnimationClass({},p),1);assert.equal(context.fieldDF,2);
  left={weaponWield:7,weaponType:0};assert.equal(clientWeaponAnimationClass({},p),2);
  right={weaponWield:2,weaponType:3};assert.equal(clientWeaponAnimationClass({},p),4);
  left=null;assert.equal(clientWeaponAnimationClass({},p),3);
  left={weaponWield:2,weaponType:1};assert.equal(clientWeaponAnimationClass({},p),5);assert.equal(context.fieldDF,1);
  size=1;left=null;assert.equal(clientWeaponAnimationClass({},p),6);
  for(const [wield,style] of [[4,8],[8,7],[5,9],[6,10],[10,11]]){
    right={weaponWield:wield,weaponType:3};assert.equal(clientWeaponAnimationClass({},p),style);
  }
});

test('client attack adaptation keeps server data independent and retains canonical uint32 IDs and WORD timing',()=>{
  const data=createAttackData();data.animationDuration=65535;data.result=4;data.reactionAnimation=12;data.attackDuration=1734;
  data.reactionDelay=867;data.ranged=0;data.weaponAttackType=1;
  const record=clientAttackAnimationRecord(data,0x80000001);record.reaction=207;
  assert.equal(record.targetId,0x80000001);assert.equal(record.duration,65535);assert.equal(record.reactionDuration,1734);
  assert.equal(data.reactionAnimation,12);
});
