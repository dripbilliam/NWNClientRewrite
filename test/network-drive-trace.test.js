import test from 'node:test';import assert from 'node:assert/strict';import {Group} from 'three';import {NetworkScene} from '../src/network_scene.js';
function fixture(){
 const actor={id:1,objectType:5,areaId:7,replicated:{position:[10,20,0],orientation:[1,0,0],walkRate:2200,runRate:4400,animation:0,field8D4:2}},world={areaId:7,localObjectId:1,registry:{get:id=>id===1?actor:null}},scene=new NetworkScene({world,resolver:{},report:()=>{},loadAsset:()=>{},instantiate:()=>{},releaseAsset:()=>{}});scene.area={id:7};const motion=scene.motion.ensure(actor);motion.position=[11,20,0];motion.render=[10.25,20,0];return{scene,actor,motion};
}
test('preview trace captures predicted origin independently of displayed correction and remains detached',async()=>{
 const f=fixture(),before=structuredClone(f.actor);f.scene.driveGeometry={query:async(_actor,{capture}={})=>{const trace={queries:[]};capture?.(trace);return async(from,to)=>{trace.queries.push({from:from.slice(),to:to.slice(),clear:true});return true;};}};
 let trace;const path=await f.scene.previewKeyboard(1,3,{capture:t=>trace=t});assert.deepEqual(trace.from,[11,20,0]);assert.deepEqual(trace.render,[10.25,20,0]);assert.equal(trace.applied,true);assert.deepEqual(trace.query.queries[0].from,trace.from);assert.deepEqual(trace.query.queries[0].to,path.target);assert.equal(trace.query.queries.length,1);assert.ok(trace.completedAt>=trace.startedAt);
 trace.from[0]=900;trace.render[0]=900;trace.plan.target[0]=900;assert.equal(f.motion.position[0],11);assert.equal(f.motion.render[0],10.25);assert.equal(f.motion.path[0][0],11);assert.ok(f.motion.path[1][0]<13);assert.deepEqual(f.actor,before);
});
test('a superseded asynchronous preview is traced as unapplied instead of an observed null path',async()=>{
 const f=fixture();let release;const gate=new Promise(r=>release=r);f.scene.driveGeometry={query:async()=>{await gate;return async()=>true;}};let trace;const work=f.scene.previewKeyboard(1,3,{capture:t=>trace=t});f.scene.endKeyboard(1);release();assert.equal(await work,undefined);assert.equal(trace.applied,false);assert.equal(f.motion.active,false);
});

test('scene path completion publishes the native resting animation to motion as well as the model',()=>{
 const f=fixture();f.actor.appearance={equipment:[]};f.scene.tables={};const played=[],animator={model:{animations:[{name:'pause1'}]},play:(name)=>{played.push(name);return true;}};f.scene.objects.set(1,{wrapper:new Group(),models:[{animator}],animation:79,bodyType:1});const canonical=structuredClone(f.actor);
 f.scene.motion.previewDrive(f.actor,{target:[11.001,20,0],facing:[1,0,0],animation:79});f.scene.update(.016);
 assert.equal(f.motion.active,false);assert.equal(f.motion.animation,0);assert.equal(f.scene.objects.get(1).animation,0);assert.deepEqual(played,['pause1']);assert.deepEqual(f.actor,canonical);
});

test('completion updates motion even when the combat animation owner consumes the resting request',()=>{
 const f=fixture();f.motion.restingBase=1;f.scene.objects.set(1,{wrapper:new Group(),models:[],animation:79,bodyType:0});const requested=[];f.scene.combat={base:(_actor,id)=>{requested.push(id);return true;},update:()=>{},speedFor:()=>1};f.scene.motion.previewDrive(f.actor,{target:[11.001,20,0],facing:[1,0,0],animation:79});f.scene.update(.016);assert.equal(f.motion.animation,1);assert.equal(f.scene.objects.get(1).animation,1);assert.deepEqual(requested,[1]);
});

test('asynchronous collision work replans from the current pose before installing a path',async()=>{
 const f=fixture();let release;const gate=new Promise(r=>release=r),queries=[];f.scene.driveGeometry={query:async()=>{if(queries.length===0)await gate;return async(from,to)=>{queries.push({from:from.slice(),to:to.slice()});return true;};}};let trace;const work=f.scene.previewKeyboard(1,3,{capture:t=>trace=t});f.motion.position=[11.5,20,0];f.motion.render=[10.75,20,0];release();await work;
 assert.equal(queries.length,2);assert.deepEqual(queries.at(-1).from,[11.5,20,0]);assert.deepEqual(f.motion.path[0],queries.at(-1).from);assert.deepEqual(f.motion.path[1],queries.at(-1).to);assert.deepEqual(trace.from,[11.5,20,0]);assert.equal(trace.applied,true);
});

test('a server animation interruption during geometry loading prevents a late movement preview',async()=>{
 const f=fixture();let release;const gate=new Promise(r=>release=r);f.scene.driveGeometry={query:async()=>{await gate;return async()=>true;}};let trace;const work=f.scene.previewKeyboard(1,3,{capture:t=>trace=t});f.actor.replicated.animation=6;release();assert.equal(await work,undefined);assert.equal(f.motion.active,false);assert.equal(trace.applied,false);
});

test('loss of server movement control or replacement of the actor cancels pending prediction',async()=>{
 for(const change of [f=>f.actor.replicated.field8D4=0,f=>{const replacement=structuredClone(f.actor);f.scene.world.registry.get=()=>replacement;}]){
  const f=fixture();let release;const gate=new Promise(r=>release=r);f.scene.driveGeometry={query:async()=>{await gate;return async()=>true;}};const work=f.scene.previewKeyboard(1,3);change(f);release();assert.equal(await work,undefined);assert.equal(f.motion.active,false);
 }
});

test('prediction retries use current facing and rates, and repeated changing inputs have bounded work',async()=>{
 const f=fixture();let release;const gate=new Promise(r=>release=r),targets=[];f.scene.driveGeometry={query:async()=>{if(targets.length===0)await gate;return async(_from,to)=>{targets.push(to.slice());return true;};}};const work=f.scene.previewKeyboard(1,3);f.motion.orientation=[0,1,0];f.motion.runRate=8800;release();await work;assert.equal(targets.length,2);assert.equal(targets.at(-1)[0],11);assert.ok(targets.at(-1)[1]>23.5);assert.deepEqual(f.motion.path[1],targets.at(-1));
 const g=fixture();let calls=0;g.scene.driveGeometry={query:async()=>{calls++;g.motion.position[0]+=.1;return async()=>true;}};assert.equal(await g.scene.previewKeyboard(1,3),undefined);assert.equal(calls,3);assert.equal(g.motion.active,false);
});

test('a full create on the same proxy invalidates pending preview IO with the old motion lifetime',async()=>{
 const f=fixture();let release;f.scene.driveGeometry={query:async()=>{await new Promise(r=>release=r);return async()=>true;}};
 const work=f.scene.previewKeyboard(1,3);f.actor.replicated.position=[30,40,0];f.scene.motion.observe(f.actor,{position:[30,40,0],animation:0,path:[]},true);const fresh=f.scene.motion.objects.get(1);assert.notEqual(fresh,f.motion);
 release();assert.equal(await work,undefined);assert.deepEqual(fresh.path,[]);assert.equal(fresh.active,false);
});

test('the first input for a replacement canonical actor cannot plan from the previous actor pose',async()=>{
 const f=fixture(),replacement=structuredClone(f.actor);replacement.replicated.position=[30,40,0];f.scene.world.registry.get=()=>replacement;
 const context=f.scene.keyboardPose(1);assert.deepEqual(context.position,[30,40,0]);assert.notEqual(context.motionLifetime,f.motion.lifetime);
 f.scene.driveGeometry={query:async()=>async()=>true};const path=await f.scene.previewKeyboard(1,3),fresh=f.scene.motion.objects.get(1);assert.notEqual(fresh,f.motion);assert.deepEqual(fresh.path[0],[30,40,0]);assert.ok(path.target[0]>30);
});

test('release of an old keyboard context cannot stop the current motion lifetime',()=>{
 const f=fixture();f.scene.motion.observe(f.actor,{animation:0,path:[]},true);const fresh=f.scene.motion.objects.get(1);fresh.driveHeld=true;
 f.scene.endKeyboard(1,f.motion.lifetime);assert.equal(fresh.driveHeld,true);f.scene.endKeyboard(1,fresh.lifetime);assert.equal(fresh.driveHeld,false);
});
test('ready collision preview installs in the current frame and heading publication stays presentation-owned',()=>{
 const f=fixture(),canonical=structuredClone(f.actor);f.scene.driveGeometry={query:()=>()=>true};const path=f.scene.previewKeyboard(1,3);assert.equal(typeof path.then,'undefined');assert.equal(f.motion.active,true);assert.deepEqual(f.motion.path[1],path.target);
 f.scene.motion.applyDriveHeading(1,385,f.motion.lifetime);assert.ok(Math.abs(Math.atan2(f.motion.orientation[1],f.motion.orientation[0])*180/Math.PI-38.5)<1e-5);assert.deepEqual(f.actor,canonical);
 f.scene.motion.observe(f.actor,{animation:0,path:[]},true);const fresh=f.scene.motion.objects.get(1),before=fresh.orientation.slice();f.scene.motion.applyDriveHeading(1,900,f.motion.lifetime);assert.deepEqual(fresh.orientation,before);
});
