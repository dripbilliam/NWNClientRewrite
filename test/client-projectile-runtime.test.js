import fs from 'node:fs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {ClientObjectArray} from '../src/client_object_array.js';
import {GameObjectArray,OBJECT_INVALID} from '../src/game_object_array.js';
import {clientProjectileSpell,receiveClientSpellProjectile,updateClientProjectile} from '../src/client_projectile_runtime.js';
import {clientProjectileModelQuaternion} from '../src/client_projectile_orientation.js';
const native=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-ai-observations.json',import.meta.url)));
test('client projectile AI matches original timer/path, stage, loop/impact sound and destruction ordering',()=>{
 for(const row of native.rows){
  const c=row.case,calls=[],s={...c,faceCamera:0,position:[1,2,3],sound:c.sound?{}:null,lastTime:{day:9,time:900},impactDuration:25,destroyed:false},p={
   difference:()=>({day:0,time:c.delta}),updatePath:o=>{calls.push(['path',o.remaining>>>0]);o.remaining=c.pathRemaining;o.elapsed=c.pathElapsed<0?c.delta:c.pathElapsed;},
   camera:()=>calls.push(['camera']),getStage:o=>{calls.push(['stage']);return o.stage;},setStage:(o,n)=>{calls.push(['setStage',n]);o.stage=n;},
   createSound:()=>{if(c.soundFailure)return null;calls.push(['createSound','loop']);return{};},destroySound:()=>calls.push(['destroySound']),soundPriority:(_s,n)=>calls.push(['priority',n]),sound3d:(_s,n)=>calls.push(['3d',n]),soundLooping:(_s,n)=>calls.push(['loop',n]),updateSound:(_s,point,gain)=>calls.push(['soundPosition',point,gain]),playSound:()=>calls.push(['play']),stopSound:()=>calls.push(['stop']),
   oneShot:(_ref,point,priority,gain)=>calls.push(['oneShot','impact',point,priority,gain]),attachImpact:()=>calls.push(['impactLookup']),setScene:(_s,n)=>calls.push(['scene',n]),destroy:o=>{calls.push(['destroy']);o.destroyed=true;}
  };
  updateClientProjectile(s,{day:10,time:1000},p);
  const state={...Object.fromEntries(['remaining','elapsed','phase','loopStarted','stage','lastTime','destroyed'].map(k=>[k,s[k]])),sound:Boolean(s.sound)};
  assert.deepEqual(calls,row.calls,JSON.stringify(c));assert.deepEqual(state,row.state,JSON.stringify(c));
 }
 assert.equal(native.rows.length,1356);
});
test('client mirrors and internal projectiles have separate IDs, retain current canonical poses and cannot mutate authoritative IDs',()=>{
 const server=new GameObjectArray(),actor={objectType:5,position:[1,3,-2],orientation:[0,0,-1]};server.addInternalObject(actor);const cursor=[...server.nextObjectId],objects=new ClientObjectArray({objects:()=>server.objects.values(),render:()=>null});objects.sync();
 const mirror=objects.get(0x80000000),projectile={id:OBJECT_INVALID,objectType:8};assert.equal(objects.addInternal(projectile),0);assert.equal(objects.get(0),projectile);assert.equal(mirror.canonical,actor);assert.equal(actor.id,0);assert.deepEqual(server.nextObjectId,cursor);assert.deepEqual(mirror.position,[1,2,3]);
 actor.position=[4,6,-5];assert.deepEqual(mirror.position,[4,5,6]);server.delete(actor.id);objects.sync();assert.equal(objects.get(0x80000000),undefined);assert.equal(objects.get(0),projectile);objects.remove(projectile);assert.equal(objects.get(0),undefined);
 const replacement={...actor,id:OBJECT_INVALID};server.addInternalObject(replacement);objects.sync();assert.notEqual(objects.get(0x80000001),mirror);assert.equal(objects.addInternal({id:OBJECT_INVALID,objectType:8}),1);
});
test('multiplayer mirrors keep received uint32 IDs and native poses without exposing visual IDs to the server registry',()=>{
 const actor={id:0xffffffff,objectType:5,replicated:{position:[1,2,3],orientation:[0,1,0]}},canonical=new GameObjectArray({clientMode:true});canonical.addObjectAtPos(actor.id,actor);const before=structuredClone(actor),cursor=[...canonical.nextObjectId],objects=new ClientObjectArray({objects:()=>canonical.objects.values(),render:()=>null,nativePose:o=>o.replicated});objects.sync();
 const visual={objectType:8};objects.addInternal(visual);assert.equal(visual.id,0);assert.equal(objects.get(actor.id).canonical,actor);assert.deepEqual(objects.get(actor.id).position,[1,2,3]);assert.equal(canonical.get(0),undefined);assert.deepEqual(actor,before);assert.deepEqual(canonical.nextObjectId,cursor);
 actor.replicated.position=[4,5,6];assert.deepEqual(objects.get(actor.id).position,[4,5,6]);objects.remove(visual);assert.equal(objects.get(0),undefined);
});
test('active spell row controls projectile assets and enums without a spell-ID special case',()=>{
 const row={Proj:'1',ProjType:'SPIRAL',ProjModel:'MixedCaseProjectileLong',ProjSpwnPoint:'MONSTER99',ProjOrientation:'PATH',ProjSound:'shot',CastSound:'cast',CastHeadVisual:'head',CastHandVisual:'hand',CastGrndVisual:'ground'},table={columns:Object.keys(row),orderedRows:[row],defaultValue:'****'},spell=clientProjectileSpell({spells:table},0);
 assert.equal(spell.model,'MixedCaseProject');assert.equal(spell.projectilePath,6);assert.equal(spell.spawn,12);assert.equal(spell.facing,2);assert.equal(spell.projectileSound,'shot');assert.equal(spell.castGround,'ground');assert.equal(clientProjectileSpell({spells:table},-1),null);
});
test('receiver loads active asset, retains failed source-node fallback and cleans a failed model without allocating a server object',async()=>{
 const objects=new ClientObjectArray({objects:()=>[{id:99,objectType:5,position:[1,3,-2],orientation:[1,0,0]}],render:()=>null});objects.sync();const created=[],source=objects.get(0x80000063),header={sourceId:source.id,targetId:OBJECT_INVALID,from:[1,2,3],to:[4,5,6],duration:500,appearance:6,spellId:0,path:null},p={
  object:id=>objects.get(id),spell:()=>({useProjectile:1,projectilePath:1,spawn:1,facing:2,model:'authored',castHead:'h',castHand:'a',castGround:'g',castSound:'',projectileSound:''}),castVisuals:()=>{},model:()=>({}),nodePose:()=>0,worldTime:()=>({day:0,time:0}),register:o=>{objects.addInternal(o);created.push(o);},registerAI:()=>{},loadModel:async(o,name)=>{assert.equal(name,'authored');o.model={};return 1;},setPosition:(o,v)=>o.position=v,setOrientation:(o,v)=>o.orientation=v,setScene:()=>{},setStage:(o,n)=>o.stage=n,setTarget:(o,id)=>o.targetId=id,configurePath:(o,path)=>o.path=path,ready:()=>{},destroy:o=>{o.destroyed=true;objects.remove(o);}
 };
 const result=await receiveClientSpellProjectile(header,p);assert.equal(result.length,1);assert.deepEqual(result[0].position,[1,2,4]);assert.equal(result[0].targetId,OBJECT_INVALID);assert.equal(result[0].path,1);
 p.loadModel=async()=>0;await receiveClientSpellProjectile(header,p);assert.equal(created[1].destroyed,true);assert.equal(objects.get(created[1].id),undefined);assert.equal(source.canonical.id,99);
 p.spell=()=>({useProjectile:1,projectilePath:4,spawn:0,facing:0,model:'unavailable',castSound:'',projectileSound:''});await receiveClientSpellProjectile(header,p);assert.equal(created.length,3,'Native first model failure does not create four extra projectiles');
});
test('projectile model quaternion matches original vector yaw/pitch, rotation order, cutoff, normalization and embedded SSE CRT',()=>{
 const capture=JSON.parse(fs.readFileSync(new URL('../backups/animations/native-client-projectile-orientation-observations.json',import.meta.url))),view=new DataView(new ArrayBuffer(4));
 for(const row of capture.rows){const q=clientProjectileModelQuaternion(row.vector),bits=q?.map(v=>{view.setFloat32(0,v,true);return view.getUint32(0,true);})??null;assert.deepEqual(bits,row.quaternion,JSON.stringify(row.vector));assert.equal(q?1:0,row.result);}
 assert.equal(capture.rows.length,130);
});
