// Offline production scene regression using existing installed/cached resources.
// Writes derived animation metadata only; never joins or fetches from a server.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {NetworkScene,networkObjectPose,networkAnimationContext} from '../src/network_scene.js';
import {NetworkCombatPresentation} from '../src/network_combat_presentation.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
const download=JSON.parse(await fs.readFile('backups/animations/arelith-fresh-download-v2.json'));
const advertisement=JSON.parse(await fs.readFile('backups/animations/arelith-authenticated-advertisement-v1.json'));
const managedMatrices=process.argv.includes('--managed-matrices');
const report={scope:'Offline cached Arelith resource context, production scene/animation; no live visual acceptance',managedMatrices,httpAttempts:0,joins:0,checks:[],issues:[]};
const resources=installedNetworkResources({install:'../FullDecomp/NwnRootInstall',cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline probe only');}}});
let scene,sources;
try{
 const context=await resolveServerResources(advertisement.requirements,{...resources,language:0});assert.ok(context.ready);
 const resolver=await resources.openModule(null,context.resolved);sources=new ModelSourceCache(resolver);
 const id=4294967091,areaId=1,object={id,areaId,objectType:5,appearance:{appearance:864,gender:0,phenotype:0,head:25,bodyParts:[],equipment:[]},replicated:{position:[0,0,0],orientation:{yaw:0},animation:0,stats:{racialType:0}}};
 const objects=new Map([[id,object]]),world={areaId,localObjectId:id,registry:{objects,get:id=>objects.get(id)}};
 scene=new NetworkScene({world,resolver,report:(...issue)=>report.issues.push(issue),loadAsset:async name=>({model:await sources.load(name)}),instantiate:asset=>{const hierarchy=createModelHierarchy(asset.model,{managedMatrices});return{...hierarchy,animator:asset.model.animations.length?new ModelAnimator(asset.model,hierarchy.root):null,dispose:()=>{}};},releaseAsset:()=>{}});
 if(managedMatrices)scene.manageLocalMatrices();
 scene.area={id:areaId};scene.tables={};for(const name of ['appearance','racialtypes','gender','phenotype','capart','parts_robe','baseitems','tailmodel','wingmodel','cloakmodel'])scene.tables[name]=parse2da(decodeResourceText(await resolver.getResource(name,2017)));
 scene.combat=new NetworkCombatPresentation({world,bindings:scene.objects,tables:scene.tables,pose:networkObjectPose,context:networkAnimationContext,report:(...issue)=>report.issues.push(issue)});
 const tail=[...scene.tables.tailmodel.rows].find(([,row])=>row.MODEL?.toLowerCase()==='c_golstone');assert.ok(tail);object.appearance.fieldAA4=tail[0];report.tailId=tail[0];
 await scene.sync();const binding=scene.objects.get(id);assert.ok(binding,JSON.stringify(report.issues));
 const body=binding.models[0],visible=binding.models.find(m=>m.resourceName==='c_golstone');assert.ok(visible);assert.equal(body.model.animations.length,0);assert.equal(body.animator,null);assert.equal(binding.animator,visible.animator);assert.equal(visible.nativeVisualScope,253);
 report.resources=binding.models.map(m=>m.resourceName);
 const hits=scene.combat.events.length;visible.animator.eventDispatcher.dispatch('hit',0);assert.equal(scene.combat.events.length,hits+1);assert.equal(scene.combat.events.at(-1).objectId,id);report.checks.push({kind:'attachment-hit-event',objectId:id});
 for(const [animation,clip]of [[0,'cpause1'],[3,'cwalk'],[4,'crun']]){
  object.replicated.animation=animation;await scene.sync();assert.equal(visible.animator.clip.name,clip);scene.update(.12);assert.ok(visible.animator.time>0);assert.equal(scene.snapshot().objects[0].clip,clip);report.checks.push({kind:'replicated',animation,clip,time:visible.animator.time});
 }
 // Timed cast/attack playback and hit ownership must use the visible model too.
 for(const [animation,clip]of [[17,'ccastout'],[200,'ca1slashl']]){
  const selected=scene.combat.clip(object,animation);assert.equal(selected.name,clip);assert.equal(selected.animator,visible.animator);scene.combat.play(object,animation,1,false);scene.update(.12);assert.equal(visible.animator.clip.name,clip);assert.ok(visible.animator.time>0);report.checks.push({kind:'action',animation,clip,time:visible.animator.time});
 }
 // Keyboard preview uses the same selected controller and does not move authority.
 const motion=scene.motion.objects.get(id),canonical=object.replicated.position.slice();motion.previewBase=true;motion.active=true;motion.animation=3;motion.previewAnimationPending=true;scene.update(.02);assert.equal(visible.animator.clip.name,'cwalk');assert.deepEqual(object.replicated.position,canonical);report.checks.push({kind:'keyboard',clip:visible.animator.clip.name});
 // Reverting removes the old event listener/controller and restores body playback.
 const oldListener=binding.combat.hitListener;object.appearance.appearance=56;object.appearance.fieldAA4=0;object.replicated.animation=0;motion.previewBase=false;motion.active=false;await scene.sync();const restored=scene.objects.get(id);assert.notEqual(restored,binding);assert.equal(scene.instances.has(visible),false);assert.equal(scene.combat.animators.has(visible.animator),false);assert.equal(visible.animator.eventDispatcher.listeners.includes(oldListener),false);assert.equal(restored.animator,restored.models[0].animator);assert.equal(restored.animator.clip.name,'cpause1');report.checks.push({kind:'revert',clip:restored.animator.clip.name});
 assert.equal(report.issues.some(([code])=>/scene-animation-unavailable|scene-combat-unhandled|drive-animation-unavailable|scene-object-failed/.test(code)),false,JSON.stringify(report.issues));assert.equal(report.httpAttempts,0);report.success=true;
}catch(error){report.failure=error.stack;process.exitCode=1;}
finally{await scene?.dispose();sources?.dispose();resources.close();await fs.writeFile(`backups/animations/${managedMatrices?'managed-matrices-transformed':'creation-experience-transformed-animation'}-v1.json`,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));}
