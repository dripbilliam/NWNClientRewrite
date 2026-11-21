import {test} from 'node:test';import assert from 'node:assert/strict';
import {prepareAreaVisualDefinition} from './area-visual-definition.mjs';import {createVisualDefinitionStaging} from './staging-visual-definition.mjs';
const table=row=>({defaultValue:'',columns:Object.keys(row),orderedRows:[row],rows:new Map([['0',row]])});
const message={visualId:0,position:[1.23456789,-2,3]};
test('area model selection uses native physical column order and skips absent/empty entries',async()=>{
 for(const row of [{Imp_HeadCon_Node:'head',Imp_Impact_Node:'impact',Imp_Root_M_Node:'root'},{Imp_HeadCon_Node:'',Imp_Impact_Node:'impact'},{Imp_Impact_Node:'impact',Imp_Root_M_Node:'root'}]){
  const reads=[],result=await prepareAreaVisualDefinition({message,table:table(row),resource:async name=>{reads.push(name);return{authored:true};}});
  assert.deepEqual(reads,[Object.values(row).find(Boolean)]);assert.equal(result.kind,'area-visual-definition');assert.equal(result.state.model.resource,reads[0]);assert.equal(result.state.instant190,1);assert.equal(result.state.position[0],Math.fround(message.position[0]));assert.equal(result.state.objectType,11);assert.equal(result.state.phase184,0);
 }
});
test('failed/missing and retired area resource loads cannot publish a definition; unsupported transforms fail before IO',async()=>{
 await assert.rejects(prepareAreaVisualDefinition({message,table:table({Imp_Impact_Node:'impact'}),resource:async()=>null}),/resource/);
 let live=true,resolve;const work=prepareAreaVisualDefinition({message,table:table({Imp_Impact_Node:'impact'}),resource:()=>new Promise(r=>resolve=r),current:()=>live});live=false;resolve({authored:true});assert.equal(await work,null);
 await assert.rejects(prepareAreaVisualDefinition({message:{...message,visualTransform:{legacy:true}},table:table({}),resource:()=>{throw Error('IO should not run');}}),/controller/);
});
test('native area staging needs current world/area ownership, without needing a canonical target binding',async()=>{
 const owner={area:{id:7},objects:new Map(),tables:{visualeffects:table({Imp_Impact_Node:'impact'})}},frontend={world:{areaId:7},areaGeneration:1};
 const stage=createVisualDefinitionStaging({presentation:()=>owner,frontend,resource:async()=>({authored:true})});
 assert.equal((await stage({kind:'area-visual',message})).kind,'area-visual-definition');assert.equal(owner.objects.size,0);
 let resolve;const delayed=createVisualDefinitionStaging({presentation:()=>owner,frontend,resource:()=>new Promise(r=>resolve=r)});const work=delayed({kind:'area-visual',message});frontend.world={areaId:7};resolve({authored:true});assert.equal(await work,null);
});
test('private dummy staging uses original anchors in a separate namespace and rejects malformed hosts',async()=>{
 const canonical={id:0,objectType:5,areaId:7,appearance:{appearance:0}},world={areaId:7,registry:new Map([[0,canonical]])};
 const owner={area:{id:7},objects:new Map(),tables:{visualeffects:table({Imp_Root_M_Node:'impact'}),appearance:{defaultValue:'',columns:['SIZECATEGORY'],orderedRows:[]},progfx:table({})}},frontend={world,areaGeneration:1};
 const stage=createVisualDefinitionStaging({presentation:()=>owner,frontend,resource:async()=>({authored:true})});
 const privateHost={id:0,token:3,objectType:5,areaId:7,creatureData:{Appearance_Type:201},model:{loadedName:'c_dummy',parts:['c_Dummy','rootdummy','Impact']}};
 const request={actorId:0,record:{visualId:0,bodyPart:0,sourceId:0x7f000000,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}},privateHosts:[privateHost]};
 const result=await stage(request);assert.equal(result.hosts[0].privateToken,3);assert.equal(world.registry.get(0),canonical);assert.equal(owner.objects.size,0);
 for(const change of [{id:0x7f000000},{token:0},{objectType:11},{areaId:8},{model:{loadedName:'fake',parts:['root']}}])await assert.rejects(stage({...request,privateHosts:[{...privateHost,...change}]}),/dummy/);
});
