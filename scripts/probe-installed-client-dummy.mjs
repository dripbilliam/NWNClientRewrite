import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {ClientProjectilePresentation} from '../src/client_projectile_presentation.js';
import {clientProjectileSpell} from '../src/client_projectile_runtime.js';
import {serverObjectIdForClient} from '../src/client_projectile_message.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
import {parseModel} from '../src/model_parser.js';
import {inheritAnimations} from '../src/mdl_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {ModelAnimator} from '../src/model_animation.js';
import {visualLocalPoseServices} from '../src/visual_scene_pose.js';
import {clientProjectileModelQuaternion} from '../src/client_projectile_orientation.js';
import {NativeRandom} from '../src/native_random.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-client-dummy-v1.json',report={};let presentation;
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize([],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)}),choices=[];
 for(const cls of s.player.nativeTalentClasses)for(const slots of cls.memorized)for(const slot of slots){const spell=slot?.ready?clientProjectileSpell(s.characterRules,slot.id):null;if(spell?.useProjectile&&[1,2,5,6].includes(spell.projectilePath)&&spell.model)choices.push({id:slot.id,spell});}
 const choice=choices[0];assert.ok(choice);const scene=new THREE.Group(),poses=visualLocalPoseServices({sceneRoot:scene}),models=[],destroyed=[],diagnostics=[],sounds=[],basis=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),inverse=basis.clone().invert();let time=0;
 const ids=[...s.registry.nextObjectId];presentation=new ClientProjectilePresentation({objects:()=>[s.player],renderFor:()=>null,playerId:()=>serverObjectIdForClient(s.player.id),rules:()=>s.characterRules,now:()=>({day:0,time}),dayLength:()=>7200000,random:new NativeRandom(1),
  loadModel:async resourceName=>{const model=parseModel(await resolver.getResource(resourceName,2002));await inheritAnimations(model,async name=>parseModel(await resolver.getResource(name,2002)));const root=createModelHierarchy(model).root;root.userData.mdlRoot=model.modelName;const loaded={root,model,resourceName,animator:new ModelAnimator(model,root)};models.push(loaded);return loaded;},destroyModel:m=>{destroyed.push(m.resourceName);m.root.removeFromParent();},
  modelFor:r=>poses.modelHandle(r),nodePose:(...args)=>poses.nodePoseInto(...args),orient:(m,v)=>{const q=clientProjectileModelQuaternion(v);if(q)m.root.quaternion.copy(basis).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(inverse);},scene,report:(code,message,data)=>diagnostics.push({code,message,data}),oneShot:e=>sounds.push(e),impactAttachment:{attach:(...args)=>poses.setParent(...args),setNodePose:(...args)=>poses.setNodePose(...args),forget:m=>poses.forgetAttachment(m),updateAttachments:()=>poses.updateAttachments()}});
 // A missing source also exercises the native header-origin fallback. No source
 // body/conjure fixture or server mutation is needed for this target lifecycle.
 await presentation.receive({header:{sourceId:OBJECT_INVALID,targetId:0x8000ffff,from:[1,2,3],to:[4,5,6],duration:500,appearance:6,spellId:choice.id,path:null}});
 const dummy=[...presentation.dummies.ai][0];assert.ok(dummy);assert.equal(dummy.model.resourceName,'c_dummy');assert.equal(dummy.appearance,201);assert.ok(dummy.model.model.nodes.some(n=>n.name.toLowerCase()==='impact'));assert.equal(dummy.duration,1000);
 report.choice={id:choice.id,model:choice.spell.model,path:choice.spell.projectilePath};report.created=structuredClone(presentation.snapshot());report.dummyModel={name:dummy.model.model.modelName,parts:dummy.model.model.nodes.map(n=>n.name),appearance:dummy.appearance};report.frames=[];
 for(const t of [500,501,999,1000]){time=t;presentation.update(.016);report.frames.push({time,snapshot:structuredClone(presentation.snapshot())});}
 assert.equal(presentation.stats.failed,0,JSON.stringify(diagnostics));assert.equal(presentation.dummies.stats.failed,0);assert.ok(presentation.events.some(e=>e.kind==='impactAttach'&&e.attached));assert.equal(presentation.active.size,0);assert.equal(presentation.dummies.owned.size,0);assert.equal(scene.children.length,0);assert.deepEqual(s.registry.nextObjectId,ids);
 report.knownAudioGaps=diagnostics.filter(d=>d.code==='visual.projectile-loop-audio-unimplemented');for(const d of report.knownAudioGaps)assert.equal(d.data.resRef,choice.spell.projectileSound);
 assert.deepEqual(diagnostics.filter(d=>/failed|unimplemented|anchor-unavailable/.test(d.code)&&!report.knownAudioGaps.includes(d)),[]);report.loaded=models.map(m=>m.resourceName);report.destroyed=destroyed;report.diagnostics=diagnostics;report.sounds=sounds;report.validation='PASS';report.limits='Read-only installed wizard active projectile metadata and real c_dummy/projectile MDL hierarchy/animator/pose services through missing source/target, internal ID allocation, attachment, expiry and cleanup. Known moving loop audio gap is retained and checked against active projectile sound. Headless Three scene, not browser pixels, actual network deletion, native full model/cache/display or complete campaign.';
}catch(error){report.validation='FAIL';report.error=error.stack;process.exitCode=1;}finally{presentation?.dispose();}
await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({validation:report.validation,choice:report.choice,loaded:report.loaded,error:report.error}));
