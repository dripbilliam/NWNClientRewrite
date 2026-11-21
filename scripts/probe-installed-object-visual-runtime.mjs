import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {parseGff} from '../src/gff.js';
import {writeGff,typedGff,gffRecord as R,gffField as F} from '../src/gff_writer.js';
import {objectAnimationOverrides,nativeAnimationName} from '../src/native_animation.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const install=process.argv[2]??'../FullDecomp/NwnRootInstall',output=process.argv[3]??'backups/animations/installed-object-visual-runtime-v1.json',report={};
const data=fields=>parseGff(writeGff('UTP ',R(fields))).root,word=(bytes,offset)=>new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength).getFloat32(offset,true);
try{
 const resolver=await openLocalModule(install,`${install}/data/nwm/Prelude.nwm`),git=typedGff(parseGff(await resolver.getResource('m0q1a',2023),'GIT ').root),placed=git.fields['Placeable List'].value[0];assert.ok(placed);
 // Preserve the installed placement and all its data, adding one visual root
 // only to the resolver's in-memory archive view. Original archives stay read-only.
 placed.fields.VisTransformList=F(15,[R({Scope:F(5,0),ScaleX:F(8,1.125)})]);resolver.module.entries.set('m0q1a:2023',new Uint8Array(writeGff('GIT ',git)));
 const s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0}).initialize(['m0q1a','m0q1d'],{character:await fs.readFile(`${install}/data/lcv/wizard.bic`)});
 await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];report.baselineDiagnostics=runtimeDiagnostics.records.length;const begin=runtimeDiagnostics.records.length;
 const gitObject=s.registry.get(s.sources.get('m0q1a:placeable:0'));assert.ok(gitObject);assert.equal(word(gitObject.nativeVisualTransforms2b0.get(0),4),1.125);
 assert.ok(runtimeDiagnostics.records.some(r=>r.code==='object.visual-presentation-unimplemented'&&r.context.objectId===gitObject.id));report.git={id:gitObject.id,sourceKey:gitObject.sourceKey,scale:1.125,automaticallyLoaded:true,inMemoryExtensionOnly:true};
 const placeable=s.register('placeable',`runtime:visual-fixture:${s.registry.nextObjectId[0]}`,{authored:{},areaId:0x7f000000,position:[0,0,0],deferTagLookup:true}),id=placeable.id,next=s.registry.nextObjectId[0];
 const timer=s.worldTimer;timer.paused=1;timer.pausedDay=77;timer.pausedTime=timer.dayLength-100;
 const fixture=data({VisTransformList:F(15,[R({Scope:F(5,0),ScaleX:F(14,R({TimerType:F(5,1),ValueFrom:F(8,1),ValueTo:F(8,1.25),LerpType:F(5,1),LerpDuration:F(8,.25),LerpProgress:F(8,.125),BehaviorFlags:F(5,9),RepeatsRemaining:F(5,7)}))})]),
  Material:F(14,R({ShaderParams:F(15,[R({Type:F(0,1),Int:F(5,23),Material:F(10,'mesh'),Param:F(10,'param')})])})),
  TextureReplace:F(14,R({TextureReplaceLi:F(15,[R({OldTexture:F(11,'stone'),NewTexture:F(11,'wood')})])})),
  MiscVisuals:F(14,R({TextBubbleText:F(10,'visual fixture')})),
 });
 await s.objectVisuals.load(placeable,fixture);const map=placeable.nativeVisualTransforms2b0,curve=map.get(0),v=new DataView(curve.buffer);
 assert.equal(word(curve,4),1.25);assert.equal(v.getUint32(40,true),77);assert.equal(v.getUint32(44,true),timer.dayLength-100);assert.equal(v.getUint32(56,true),78);assert.equal(v.getUint32(60,true),150);assert.equal(v.getUint32(24,true),0);assert.equal(v.getUint32(28,true),0);
 assert.equal(s.registry.get(id),placeable);assert.equal(s.registry.nextObjectId[0],next);assert.equal(placeable.areaId,0x7f000000);
 report.placeable={id,canonical:true,scopes:[...map.keys()],to:1.25,worldStart:[77,timer.dayLength-100],worldEnd:[78,150],discardedBehaviorAndRepeat:true,shaderRecords:placeable.nativeVisualPools[0x2b8].records.length,textureRecords:placeable.nativeVisualPools[0x2c8].records.length};
 const player=s.player,carrier=[...s.registry.objects.values()].find(o=>o.objectType===5&&o.nativeEquipment?.get(16,itemId=>s.registry.get(itemId))),item=carrier?.nativeEquipment.get(16,itemId=>s.registry.get(itemId));assert.ok(item,'An active installed creature must have a canonical right-hand item');assert.equal(item.possessorId,carrier.id);
 await s.objectVisuals.loadOwner(item,data({VisualTransform:F(14,R({ScaleX:F(8,2)}))}),0x140497bb0);const right=carrier.nativeHandVisualMaps[0xab0];assert.equal(word(right.get(0),4),2);assert.notEqual(right.get(0),item.nativeVisualTransforms2b0.get(0));
 const replacements=data({AnimationReplace:F(14,R({AnimationReplace:F(15,[R({OldAnimation:F(11,'pause1'),NewAnimation:F(11,'cpause1')})])}))});
 await s.objectVisuals.loadOwner(player,replacements,0x1404969c0);assert.equal(nativeAnimationName(0,{fieldDE:1,fieldDD:3,fieldE0:0},objectAnimationOverrides(player)),'cpause1');
 await s.objectVisuals.loadOwner(player,data({}),0x1404969c0);assert.equal(objectAnimationOverrides(player)[0].replacement,'cpause1');
 await s.objectVisuals.loadOwner(player,data({AnimationReplace:F(14,R({AnimationReplace:F(15,[])}))}),0x1404969c0);assert.deepEqual(objectAnimationOverrides(player),[]);
 report.actor={id:player.id,equippedActor:carrier.id,equippedItem:item.id,rightHandScale:2,replacementRetainedThenCleared:true};
 const missing=runtimeDiagnostics.records.slice(begin).filter(r=>r.code==='object.visual-presentation-unimplemented');assert.equal(missing.length,5);assert.ok(missing.every(r=>[id,item.id].includes(r.context.objectId)));
 report.missingPresentation=missing.map(r=>({code:r.code,objectId:r.context.objectId,owner:r.context.owner,message:r.message}));
 await s.lifecycle.destroy(placeable);assert.equal(s.registry.get(id),undefined);assert.equal(map.size,0);assert.equal(placeable.nativeVisualTransforms2b0,null);assert.equal(placeable.nativeMiscVisualFields[0x278],'');
 assert.ok(Object.values(placeable.nativeVisualPools).every(pool=>pool.records.length===0&&pool.capacity===0));assert.equal(s.registry.nextObjectId[0],next);
 report.inMemoryFixtureOnly=true;report.destroyed=id;report.nextObjectId=next;report.validation='PASS';await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
}catch(error){report.validation='FAIL';report.error=error.stack;await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.error(error);process.exitCode=1;}
