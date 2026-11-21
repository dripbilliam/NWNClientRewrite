import test from 'node:test';
import assert from 'node:assert/strict';
import {prepareVisualDefinition} from './visual-definition.mjs';
import {createVisualDefinitionStaging} from './staging-visual-definition.mjs';
import {createRigFixture} from './rig-fixture.mjs';
import {phaseOracle} from './visual-phases-oracle.mjs';

const table=(rows=[],defaultValue='')=>({defaultValue,columns:[...new Set(rows.filter(Boolean).flatMap(Object.keys))],orderedRows:rows,rows:new Map(rows.map((row,index)=>[String(index),row]))});
function fixture({visual={},programs=[],type=5}={}){
 const actor={id:1,objectType:type,appearance:{appearance:0}},source={id:2,objectType:5,appearance:{appearance:0}},objects=new Map([[1,actor],[2,source]]),requests=[];
 const tables={visuals:table([visual]),programs:table(programs),appearance:table([{SIZECATEGORY:3}])};
 const record={visualId:0,sourceId:2,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]},delivery:{instant:0,sourcePart:0,targetPart:0,point:[.123456789,0,0]}};
 const context={actorId:1,record,objects,tables,modelFor:id=>objects.has(id)?{parts:['base','impact','headconjure','handconjure'],loadedName:type===9?'plc_house':'door_test'}:null,resource:async name=>{requests.push(name);return{authoredResource:name};}};
 return{actor,source,context,requests,tables,record,run:()=>prepareVisualDefinition(context)};
}

test('original loader selects geometry aliases in order, caches only resources and retains independent model handles',async()=>{
 const f=fixture({visual:{Imp_Root_M_Node:'ground',Imp_Impact_Node:'same',Imp_HeadCon_Node:'same',ProgFX_Duration:0},programs:[{Type:4,param7:'must_not_load'}]}),definition=await f.run();
 assert.deepEqual(f.requests,['ground','same']);assert.deepEqual(definition.state.models88.map(row=>row.alias),['fxground','fximpact','fxhead']);
 assert.deepEqual(definition.state.models88.map(row=>row.id),[1,2,3]);assert.ok(definition.state.models88.every(row=>row.priority===3));assert.deepEqual(definition.state.retiredDc,[0,0,0]);assert.deepEqual(definition.state.programsD0,[65535,65535,65535]);assert.deepEqual(definition.programs,{});
 assert.equal(definition.state.sourceAnchor28,'handconjure');assert.equal(definition.state.targetAnchor38,'impact');assert.equal(definition.state.point48[0],Math.fround(.123456789));assert.equal(definition.state.closedEc,1);
});

test('all three program phases preserve typed table outputs and prefetch their actual resource columns',async()=>{
 const f=fixture({visual:{ProgFX_Impact:0,ProgFX_Duration:1,ProgFX_Cessation:2,SoundDuration:'loop',ShakeType:2,ShakeDuration:'1.25',ShakeDelay:'.2'},programs:[{Type:4,param1:'duration',param2:'1.5',param3:1,param4:2,param5:3,param6:1,param7:'lightmodel'},{Type:7,param1:'beammodel',param2:'wrong_clip',param6:'right_clip'},{Type:12,param2:'failmodel'}]}),definition=await f.run();
 assert.deepEqual(f.requests,['lightmodel','beammodel','failmodel']);assert.equal(definition.state.programRemainingCc,1000);
 assert.equal(definition.programs[1].string.param6.value,'right_clip');assert.equal(definition.programs[0].float.param2.value,1.5);assert.deepEqual(definition.programs[0].integer.param3,{found:true,value:1});assert.equal(definition.programs[2].resource,'failmodel');assert.equal(definition.visual.string.SoundDuration.value,'loop');assert.equal(definition.visual.float.ShakeDuration.value,1.25);
});

test('instant effects omit duration and cessation program resources exactly as the original loader does',async()=>{
 const f=fixture({visual:{ProgFX_Impact:0,ProgFX_Duration:1,ProgFX_Cessation:2},programs:[{Type:7,param1:'impactbeam'},{Type:4,param7:'duration'},{Type:12,param2:'cessation'}]});f.record.delivery.instant=1;
 const result=await f.run();assert.deepEqual(result.state.programsD0,[0,65535,65535]);assert.deepEqual(f.requests,['impactbeam']);assert.equal(result.state.durationFc,0);
});

test('quality, size and violence variants retain native found/default query semantics',async()=>{
 const f=fixture({visual:{Imp_Root_M_Node:'medium',Imp_Root_L_Node:'large',Imp_Root_H_Node:'huge',LowQuality:'cheap'}});f.tables.appearance.orderedRows[0].SIZECATEGORY=5;f.context.settings={quality64:0,violence40:2};
 const result=await f.run();assert.deepEqual(f.requests,['cheap']);assert.equal(result.state.models88[0].resource,'cheap');
});

test('missing model resources retain native warning/retirement fields without dropping other model slots',async()=>{
 const f=fixture({visual:{Imp_Root_M_Node:'good',Imp_Impact_Node:'missing',Imp_HeadCon_Node:'good'}});f.context.resource=async name=>{f.requests.push(name);if(name==='missing')throw Error('authored missing');return{};};
 const result=await f.run();assert.deepEqual(result.state.retiredDc,[0,1,0]);assert.equal(result.state.models88[1],null);assert.equal(result.warnings.filter(row=>row.code==='visual.resource-unavailable').length,1);assert.equal(result.warnings.filter(row=>row.code==='visual.native-model-warning').length,1);assert.deepEqual(f.requests,['good','missing']);
});

test('pending resources cannot publish after target replacement or explicit scope retirement',async()=>{
 for(const reason of ['target','scope']){
  const f=fixture({visual:{Imp_Root_M_Node:'first',Imp_Impact_Node:'later'}});let release;const wait=new Promise(resolve=>release=resolve);f.context.current=()=>!f.retired;f.context.resource=async name=>{f.requests.push(name);await wait;return{};};
  const work=f.run();if(reason==='scope')f.retired=true;else f.context.objects.set(1,{...f.actor});release();assert.equal(await work,null);assert.deepEqual(f.requests,['first']);
 }
});

test('unsupported controller maps and body transforms fail before any resource IO',async()=>{
 for(const change of [f=>f.record.bodyPart=1,f=>f.record.transform.scale=2,f=>f.record.networkTransform={legacy:true}]){
  const f=fixture({visual:{Imp_Root_M_Node:'not_loaded'}});change(f);await assert.rejects(f.run(),/not implemented|not connected/);assert.deepEqual(f.requests,[]);
 }
});

test('definition staging rejects a delayed shape replacement or same-number world reconnect',async()=>{
 for(const retire of ['binding','world']){
  const f=createRigFixture(),owner={...f.presentation,area:{id:7},closed:false},world={areaId:7,registry:f.presentation.world.registry},frontend={world,areaGeneration:1};world.registry.get(1).areaId=7;owner.tables={appearance:table([{SIZECATEGORY:3}]),visualeffects:table([{Imp_Root_M_Node:'authored'}]),progfx:table([])};
  let release,called=false;const waiting=new Promise(resolve=>release=resolve),run=createVisualDefinitionStaging({presentation:()=>owner,frontend,resource:()=>{called=true;return waiting;}});
  const record={visualId:0,sourceId:1,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}};
  const work=run({actorId:1,record});assert.equal(called,true);if(retire==='binding')owner.objects.set(1,{...owner.objects.get(1)});else frontend.world={...world};release({authored:true});assert.equal(await work,null);
 }
});

test('positive staging/probe reads actual physical host metadata and excludes removed or out-of-area actors',async()=>{
 const f=createRigFixture(),actor=f.presentation.world.registry.get(1);actor.areaId=7;
 const owner={...f.presentation,area:{id:7},closed:false,tables:{appearance:table([{SIZECATEGORY:3}]),visualeffects:table([{Imp_Root_M_Node:'authored'}]),progfx:table([])}},world={areaId:7,registry:f.presentation.world.registry},frontend={world,areaGeneration:1},requests=[];
 const run=createVisualDefinitionStaging({presentation:()=>owner,frontend,resource:async name=>{requests.push(name);return{authored:true};}});
 const result=await run.probe(1);assert.equal(result.kind,'visual-definition');assert.deepEqual(requests,['authored']);assert.equal(result.state.sourceAnchor28,'root');
 actor.replicationRemoved=true;await assert.rejects(run.probe(1),/target type/);actor.replicationRemoved=false;actor.areaId=8;await assert.rejects(run.probe(1),/target type/);assert.deepEqual(requests,['authored']);
});

test('phase oracle inputs remain immutable and exercise complete phase traces deterministically',()=>{
 const first=phaseOracle(),second=phaseOracle();assert.deepEqual(first,second);assert.equal(first.cases.length,96);assert.equal(first.cases[0].steps.length,25);assert.deepEqual(first.cases[0].config.initial.retiredDc,[0,0,0]);assert.equal(first.milliseconds.find(row=>row.value==='NaN').long,'-9223372036854775808');
 const calls=new Set(first.cases.flatMap(row=>row.steps.flatMap(step=>step.trace.map(call=>call[0]))));
 for(const name of ['startProgram','loadProgram','clearProgram','updateProgram','stopProgram','detachProcedural','destroyProcedural','shakeOnce','shakeLoop','stopSound','destroySound','destroyControllers'])assert.ok(calls.has(name),name);
});
