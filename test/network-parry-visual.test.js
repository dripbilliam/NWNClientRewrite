import test from 'node:test';
import assert from 'node:assert/strict';
import {Group} from 'three';
import {parse2da} from '../src/area.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {NetworkParryVisual} from '../src/network_parry_visual.js';
import {NetworkCombatPresentation} from '../src/network_combat_presentation.js';
import {clientAttackHit} from '../src/client_attack_playback.js';
import fs from 'node:fs';

function fixture(){
 const actor={id:0xffffffff,objectType:5,areaId:10,appearance:{appearance:0,equipment:[]},replicated:{position:[1,2,3],facingTarget:0x80000012,animation:200}},target={id:0x80000012,objectType:5,areaId:10,appearance:{appearance:0,equipment:[{slot:16,item:{}}]},replicated:{position:[5,8,2],animation:206}},decoy={...structuredClone(target),id:0x80000013};
 const canonical=new Map([actor,target,decoy].map(o=>[o.id,o])),scene={world:{areaId:10,registry:{get:id=>canonical.get(id)}},root:new Group(),objects:new Map(),motion:{objects:new Map([[actor.id,{orientation:[1,0,0]}]])},tables:{appearance:parse2da('2DA V2.0\n\nCREPERSPACE ABORTONPARRY\n0 .4 1')},closed:false};
 for(const o of canonical.values()){
  const data={modelName:'parry_test',nodes:[{name:'base',parent:'NULL',position:[0,0,0],orientation:[0,0,0,1]},{name:'impact',parent:'base',position:[0,0,1],orientation:[0,0,0,1]}]},body=createModelHierarchy(data).root,wrapper=new Group();body.userData.mdlRoot=data.modelName;wrapper.position.set(o.replicated.position[0],o.replicated.position[2],-o.replicated.position[1]);wrapper.add(body);scene.root.add(wrapper);scene.objects.set(o.id,{wrapper,models:[{root:body}],combat:{visual:o.replicated.animation,failures:new Set(),base:0},model18:null});
 }
 const effects=[],reports=[];scene.areaVisuals={receive:e=>{effects.push(e);return Promise.resolve();}};scene.poses=visualLocalPoseServices({sceneRoot:scene.root});const owner=new NetworkParryVisual(scene);
 scene.combat=new NetworkCombatPresentation({world:scene.world,bindings:scene.objects,tables:scene.tables,pose:()=>null,context:()=>null,report:(...args)=>reports.push(args),parryEffect:o=>owner.receive(o)});
 return{actor,target,decoy,scene,effects,reports,owner,before:JSON.stringify([...canonical])};
}
test('actual parry hit branch uses facing target, displayed pose and impact node without changing canonical actors',()=>{
 const f=fixture(),b=f.scene.objects.get(f.actor.id);b.wrapper.position.set(2,4,-3);
 clientAttackHit({type:1,sourceId:f.actor.id,targetId:f.decoy.id,ranged:0,result:2,damage:0,weaponAttackType:1},f.scene.combat.providers());
 assert.deepEqual(f.effects,[{visualId:118,position:[Math.fround(5-Math.fround(.4*2)),8,7]}]);assert.equal(b.combat.visual,0);assert.ok(f.reports.some(r=>r[0]==='network.scene-weapon-effect-unhandled'));assert.equal(f.reports.some(r=>r[0]==='network.scene-combat-effect-unhandled'),false);
 assert.equal(JSON.stringify([f.actor,f.target,f.decoy].map(o=>[o.id,o])),f.before);
});
test('missing/removed/out-of-area facing targets never substitute the attack-record target',()=>{
 for(const change of [{facingTarget:123},{removed:true},{area:11}]){const f=fixture();if(change.facingTarget)f.actor.replicated.facingTarget=change.facingTarget;if(change.removed)f.target.replicationRemoved=true;if(change.area)f.target.areaId=change.area;assert.equal(f.owner.receive(f.actor),0);assert.deepEqual(f.effects,[]);}
});
test('missing impact nodes and missing motion are diagnosed; disposed scenes never spawn effects',()=>{
 const a=fixture();a.scene.objects.get(a.actor.id).wrapper.traverse(o=>{if(o.userData.mdlNode==='impact')o.userData.mdlNode='absent';});assert.equal(a.owner.receive(a.actor),0);assert.deepEqual(a.effects,[]);assert.equal(a.reports[0][0],'network.scene-parry-warning');
 const b=fixture();b.scene.motion.objects.clear();assert.equal(b.owner.receive(b.actor),0);assert.equal(b.reports[0][0],'network.scene-combat-effect-unhandled');
 const c=fixture();c.scene.closed=true;assert.equal(c.owner.receive(c.actor),0);assert.deepEqual(c.effects,[]);
});
test('model18 has native robe semantics and preserves the explicit unsupported-robe diagnostic',()=>{
 const oracle=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-parry-model-query-observations.json',import.meta.url)));assert.equal(oracle.target,'3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a');assert.equal(oracle.cases.length,18);for(const row of oracle.cases)assert.equal(row.value,row.kind==='body'&&row.present);
 const f=fixture(),p=f.scene.combat.providers(),b=f.scene.objects.get(f.actor.id);assert.equal(p.hasModel(f.actor,18),false);b.model18={};assert.equal(p.hasModel(f.actor,18),true);b.model18Unavailable=true;assert.throws(()=>p.hasModel(f.actor,18),/robe model18/);assert.throws(()=>p.hasModel(f.actor,19),/not connected/);
});
