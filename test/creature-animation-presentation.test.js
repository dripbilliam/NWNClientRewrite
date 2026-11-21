import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {CreatureAnimationPresentation} from '../src/creature_animation_presentation.js';
import {nativeAnimationNames} from '../src/native_animation_names.js';
import {ModelAnimator} from '../src/model_animation.js';
import {parse2da} from '../src/area.js';
import {createAttackData} from '../src/combat_attack_data.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {parseGff} from '../src/gff.js';
import {writeGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
import {ModuleSession} from '../src/module_session.js';
import {ClientPausePresentation} from '../src/client_pause_presentation.js';
import {addPauseExclusion} from '../src/server_pause.js';
import {advanceLocalClocks} from '../scripts/advance-effect-clock.mjs';

function fixture(session=null){
  let now=100;const errors=[],objects=new Map(),rules={baseitems:parse2da('2DA V2.0\n\nWeaponWield WeaponType WeaponSize %AnimSlashL %AnimSlashR PrefAttackDist\n0 2 3 3 50 50 1.5'),
    appearance:parse2da('2DA V2.0\n\nSIZECATEGORY HITDIST PREFATCKDIST weaponscale targetheight\n0 3 .5 1.5 1 H')};
  const create=(id,position)=>{
    let actor={id,kind:id===1?'player':'creature',objectType:5,modelType:'P',tag:`actor${id}`,inventory:[],areaId:10,position,
      orientation:[1,0,0],animationState:0,lockOrientationId:OBJECT_INVALID,authored:{Appearance_Type:0,ClassList:[{Class:4}]}};
    if(session){const{id:_fixtureId,...data}=actor;actor=session.register('creature',`animation:${id}`,data);}
    objects.set(actor.id,actor);const render=new THREE.Group(),bone=new THREE.Group();bone.userData={mdlNode:'hand',mdlModel:'rig'};render.add(bone);
    const model={modelName:'rig',nodes:[{name:'hand'}],animations:nativeAnimationNames.filter(Boolean).map(name=>({name,length:1,tracks:[
      {node:'hand',property:'position',interpolation:'linear',frames:[{time:0,value:[0,0,0]},{time:1,value:[1,2,3]}]}]}))};
    return {actor,render,bone,animator:new ModelAnimator(model,render)};
  };
  const a=create(1,[0,0,0]),b=create(2,[2,0,0]);b.actor.lockOrientationId=a.actor.id;
  const p=new CreatureAnimationPresentation({object:id=>objects.get(id),rules:()=>rules,now:()=>now,report:(message,context)=>errors.push({message,context})});
  p.bind(a.actor,a.animator,a.render);p.bind(b.actor,b.animator,b.render);
  return{a,b,p,errors,objects,advance:value=>{now=value;p.update();}};
}

test('copied equipped items use live base-item state for weapon clips and range without an authored UTI clone',()=>{
 const f=fixture(),item={id:99,nativeItemLoaded:true,baseItem:0,authored:{},equipmentSlot:16};f.objects.set(item.id,item);f.a.actor.inventory.push(item.id);
 const binding=f.p.bindings.get(f.a.actor.id);f.p.refreshWeapon(binding);assert.equal(f.p.baseInfo(item).weaponWield,2);assert.equal(f.p.providers(binding).baseItem(item),0);assert.equal(f.p.providers(binding).preferredDistance(f.a.actor,1),1.5);
 item.authored.BaseItem=111;f.p.refreshWeapon(binding);assert.equal(f.p.baseInfo(item).weaponWield,2);assert.deepEqual(f.errors,[]);
});

test('actual model sampling freezes ordinary creature pose and advances excluded caster pose, then resumes both without a clock jump',async()=>{
 let clock;const reports=[],s=new ModuleSession(null,{runStartupScripts:false,onCombatMessage:event=>clock?.receive(event)}),f=fixture(s);s.player=f.a.actor;s.player.stats={};s.worldTimer.setTime(7,0);s.nativeServerPause.timer1.reset(s.worldTimer);s.nativeServerPause.timer2.reset(s.worldTimer);clock=new ClientPausePresentation({session:()=>s,report:(...a)=>reports.push(a)});clock.flush();f.p.now=id=>clock.now(id);f.p.update();
 advanceLocalClocks(s,250);clock.flush();f.p.update();assert.equal(f.a.animator.time,.25);assert.equal(f.b.animator.time,.25);const pose=f.b.bone.position.toArray();
 addPauseExclusion(s.nativeServerPause,f.a.actor.id,1);await s.setPauseState(1,1);clock.flush();advanceLocalClocks(s,500);clock.flush();f.p.update();assert.equal(f.a.animator.time,.75);assert.equal(f.b.animator.time,.25);assert.deepEqual(f.b.bone.position.toArray(),pose);assert.notDeepEqual(f.a.bone.position.toArray(),pose);
 await s.setPauseState(1,0);clock.flush();advanceLocalClocks(s,100);clock.flush();f.p.update();assert.equal(f.a.animator.time,.85);assert.equal(f.b.animator.time,.35);assert.notDeepEqual(f.b.bone.position.toArray(),pose);assert.deepEqual(f.errors,[]);assert.ok(!reports.some(r=>r[0]==='client.pause-clock-undefined'));
});

test('reaction for an unbound target does not request a nonexistent creature clock or reject the attacker animation',()=>{
 const{a,p,errors,advance}=fixture();p.now=id=>{assert.equal(id,a.actor.id);return 100;};a.actor.animationState=9;const attack=createAttackData();Object.assign(attack,{animationDuration:2000,reactionDelay:1000,reactionAnimation:14,attackDuration:2000,result:1,weaponAttackType:1});p.unbind(2);
 assert.equal(p.receive({type:5,data:{objects:[a.actor.id,2]},attack}),true);advance(100);assert.ok(a.animator.clip);assert.deepEqual(errors,[]);assert.equal(p.pending.length,0);
});

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

test('parsed16-byte animation replacement labels drive the actual model animator',()=>{
 const {a,p,errors,advance}=fixture();
 a.actor.authored=parseGff(writeGff('UTC ',R({Appearance_Type:F(2,0),ClassList:F(15,[R({Class:F(0,4)})]),
  AnimationReplace:F(14,R({AnimationReplace:F(15,[
   R({OldAnimation:F(11,'PAUSE1'),NewAnimation:F(11,'cpause1')}),
   R({OldAnimation:F(11,'pause1'),NewAnimation:F(11,'walk')}),
  ])})),
 }))).root;
 advance(100);assert.equal(a.animator.clip.name,'cpause1');
 advance(600);assert.ok(a.bone.position.length()>0);assert.equal(a.animator.clip.name,'cpause1');
 assert.equal(a.actor.id,1);assert.equal(p.object(a.actor.id),a.actor);assert.deepEqual(errors,[]);
});

test('canonical runtime replacement pools drive subsequent animation selection across retain and clear reloads',async()=>{
 const s=new ModuleSession(null),{a,p,errors,advance}=fixture(s),id=a.actor.id,next=s.registry.nextObjectId[0],replacement=name=>parseGff(writeGff('UTC ',R({AnimationReplace:F(14,R({AnimationReplace:F(15,name?[R({OldAnimation:F(11,'pause1'),NewAnimation:F(11,name)})]:[])}))}))).root;
 a.actor.authored.AnimationReplace={AnimationReplaceList:[{OldAnimation:'pause1',NewAnimation:'cpause1'}]};advance(100);assert.equal(a.animator.clip.name,'cpause1');
 const binding=p.bindings.get(id),empty=parseGff(writeGff('UTC ',R({}))).root;
 await s.objectVisuals.loadOwner(a.actor,empty,0x1404969c0);p.play(binding,0,200);assert.equal(a.animator.clip.name,'cpause1');
 await s.objectVisuals.loadOwner(a.actor,replacement('walk'),0x1404969c0);p.play(binding,0,300);assert.equal(a.animator.clip.name,'walk');
 await s.objectVisuals.loadOwner(a.actor,empty,0x1404969c0);p.play(binding,0,400);assert.equal(a.animator.clip.name,'walk');
 await s.objectVisuals.loadOwner(a.actor,replacement(null),0x1404969c0);p.play(binding,0,500);assert.equal(a.animator.clip.name,'pause1');advance(1000);
 assert.ok(a.bone.position.length()>0);assert.equal(s.registry.get(id),a.actor);assert.equal(s.registry.nextObjectId[0],next);assert.deepEqual(errors,[]);
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

test('unbinding a removed creature drops only its owned presentation and pending cues',()=>{
 const {a,b,p}=fixture();p.pending.push({id:a.actor.id,animation:63},{id:b.actor.id,animation:1});
 p.unbind(a.actor.id);assert.equal(a.animator.presentationOwned,false);assert.equal(p.bindings.has(a.actor.id),false);
 assert.equal(p.bindings.get(b.actor.id).actor,b.actor);assert.deepEqual(p.pending,[{id:b.actor.id,animation:1}]);
});
