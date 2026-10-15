import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {CreatureAnimationPresentation} from '../src/creature_animation_presentation.js';
import {nativeAnimationNames} from '../src/native_animation_names.js';
import {ModelAnimator} from '../src/model_animation.js';
import {parse2da} from '../src/area.js';
import {createAttackData} from '../src/combat_attack_data.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';

function fixture(){
  let now=100;const errors=[],objects=new Map(),rules={baseitems:parse2da('2DA V2.0\n\nWeaponWield WeaponType WeaponSize %AnimSlashL %AnimSlashR PrefAttackDist\n0 2 3 3 50 50 1.5'),
    appearance:parse2da('2DA V2.0\n\nSIZECATEGORY HITDIST PREFATCKDIST weaponscale targetheight\n0 3 .5 1.5 1 H')};
  const create=(id,position)=>{
    const actor={id,kind:id===1?'player':'creature',objectType:5,modelType:'P',tag:`actor${id}`,inventory:[],areaId:10,position,
      orientation:[1,0,0],animationState:0,lockOrientationId:OBJECT_INVALID,authored:{Appearance_Type:0,ClassList:[{Class:4}]}};
    objects.set(id,actor);const render=new THREE.Group(),bone=new THREE.Group();bone.userData={mdlNode:'hand',mdlModel:'rig'};render.add(bone);
    const model={modelName:'rig',nodes:[{name:'hand'}],animations:nativeAnimationNames.filter(Boolean).map(name=>({name,length:1,tracks:[
      {node:'hand',property:'position',interpolation:'linear',frames:[{time:0,value:[0,0,0]},{time:1,value:[1,2,3]}]}]}))};
    return {actor,render,bone,animator:new ModelAnimator(model,render)};
  };
  const a=create(1,[0,0,0]),b=create(2,[2,0,0]);b.actor.lockOrientationId=a.actor.id;
  const p=new CreatureAnimationPresentation({object:id=>objects.get(id),rules:()=>rules,now:()=>now,report:(message,context)=>errors.push({message,context})});
  p.bind(a.actor,a.animator,a.render);p.bind(b.actor,b.animator,b.render);
  return{a,b,p,errors,objects,advance:value=>{now=value;p.update();}};
}

test('canonical attack drives sampled swing/reaction poses, then death holds without restarting an idle clip',()=>{
  const {a,b,p,errors,advance}=fixture();advance(100);
  const data=createAttackData();data.animationDuration=2000;data.reactionDelay=1000;data.reactionAnimation=14;data.attackDuration=2000;data.result=1;data.weaponAttackType=1;
  a.actor.animationState=9;assert.equal(p.receive({type:5,data:{objects:[1,2]},attack:data}),true);
  advance(100);const swing=a.animator.clip.name;assert.notEqual(swing,'pause1');assert.notEqual(swing,'nwreadyr');
  advance(600);assert.ok(a.bone.position.length()>0);assert.equal(b.animator.clip.name,'pause1');
  advance(1100);assert.notEqual(b.animator.clip.name,'pause1');advance(1600);assert.ok(b.bone.position.length()>0);
  b.actor.animationState=8;advance(1700);assert.equal(b.animator.clip.name,'kdbck');
  advance(2200);assert.equal(b.animator.time,.5);
  advance(2700);assert.equal(b.animator.clip.name,'kdbckdie');
  advance(3700);assert.equal(b.animator.clip.name,'deadbck');
  advance(6000);assert.equal(b.animator.clip.name,'deadbck');assert.equal(b.animator.time,1);assert.equal(b.animator.playing,false);
  assert.ok(p.snapshot().events.some(e=>e.objectId===a.actor.id&&e.clip===swing));assert.deepEqual(errors,[]);
  assert.equal(data.reactionAnimation,14);assert.equal(a.actor.id,1);assert.equal(b.actor.id,2);
});

test('live knockdown completes its fall and recovery before returning to ready',()=>{
  const {a,errors,advance}=fixture();advance(100);a.actor.animationState=5;advance(200);
  assert.equal(a.animator.clip.name,'kdfnt');advance(1200);assert.equal(a.animator.clip.name,'kdfntps');
  a.actor.animationState=1;advance(1500);assert.equal(a.animator.clip.name,'gustandf');
  advance(2500);assert.equal(a.animator.clip.name,'nwreadyr');assert.deepEqual(errors,[]);
});
test('ambient one-shot transitions return to idle and looping animation states without presentation failures',()=>{
  const {a,p,errors,advance}=fixture();advance(100);
  a.actor.animationState=53;advance(200);assert.equal(p.bindings.get(a.actor.id).current.loop,false);
  advance(1400);a.actor.animationState=54;advance(1500);advance(2600);
  a.actor.animationState=0;advance(2700);assert.equal(a.animator.clip.name,'pause1');
  a.actor.animationState=57;advance(2800);assert.equal(p.bindings.get(a.actor.id).current.loop,true);
  a.actor.animationState=2;advance(2900);assert.equal(a.animator.clip.name,'walk');assert.deepEqual(errors,[]);
});

test('presentation reports unavailable clips once and never fabricates a replacement clip or changes server state',()=>{
  const {a,p,errors,advance}=fixture();a.animator.model.animations=a.animator.model.animations.filter(c=>c.name!=='deadbck');
  a.actor.animationState=8;advance(100);advance(200);assert.equal(errors.length,1);assert.match(errors[0].message,/unavailable clip deadbck/);
  assert.equal(a.actor.animationState,8);assert.equal(a.actor.id,1);assert.equal(a.animator.clip,null);
  p.clear();assert.equal(a.animator.presentationOwned,false);assert.equal(p.bindings.size,0);
});
