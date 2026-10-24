import {visualMainModel} from '../../src/visual_scene_pose.js';
import {prepareVisualDefinition} from './visual-definition.mjs';
import {nativeStringEntry} from '../../src/spell_metadata.js';
import {prepareAreaVisualDefinition} from './area-visual-definition.mjs';

export function createVisualDefinitionStaging({presentation,frontend,resource}){
 const stage=async request=>{
  const owner=presentation(),world=frontend.world,generation=frontend.areaGeneration,areaId=world?.areaId;
  if(!owner||!world||owner.closed||owner.area.id!==world.areaId)return null;
  if(request.kind==='area-visual')return prepareAreaVisualDefinition({message:request.message,table:owner.tables.visualeffects,resource,current:()=>!owner.closed&&presentation()===owner&&frontend.world===world&&world.areaId===areaId&&frontend.areaGeneration===generation});
  const privateHosts=new Map();
  if(request.privateHosts!==undefined){
   if(!Array.isArray(request.privateHosts)||request.privateHosts.length>2)throw Error('Invalid private visual hosts');
   for(const host of request.privateHosts){
    if(!Number.isInteger(host.id)||host.id<0||host.id>=0x7effffff||!Number.isSafeInteger(host.token)||host.token<1||host.objectType!==5||host.areaId!==areaId||host.creatureData?.Appearance_Type!==201||host.model?.loadedName!=='c_dummy'||!Array.isArray(host.model.parts)||!host.model.parts.length||host.model.parts.length>256||host.model.parts.some(name=>typeof name!=='string'||name.length>64)||privateHosts.has(host.id))throw Error('Invalid original private dummy descriptor');
    privateHosts.set(host.id,{...host,privateToken:host.token});
   }
  }
  const binding=owner.objects.get(request.actorId),source=owner.objects.get(request.record.sourceId);
  const current=()=>!owner.closed&&presentation()===owner&&frontend.world===world&&world.areaId===areaId&&frontend.areaGeneration===generation&&owner.objects.get(request.actorId)===binding&&owner.objects.get(request.record.sourceId)===source;
  const objects={get:id=>{if(privateHosts.has(id))return privateHosts.get(id);const object=world.registry.get(id);return object&&!object.replicationRemoved&&object.areaId===areaId?object:null;}};
  const modelFor=id=>{
   if(privateHosts.has(id))return privateHosts.get(id).model;
   const entry=owner.objects.get(id);if(!entry)return null;
   const main=visualMainModel(entry.wrapper),instance=entry.models.find(model=>model.root===main?.root);
   return instance?{parts:instance.model.nodes.map(node=>node.name),loadedName:entry.wrapper.userData.nativeLoadedModelName??instance.resourceName??instance.model.modelName}:null;
  };
  if(objects.get(request.actorId)&&!modelFor(request.actorId))return{pending:true};
  try{return await prepareVisualDefinition({...request,objects,modelFor,tables:{visuals:owner.tables.visualeffects,programs:owner.tables.progfx,appearance:owner.tables.appearance},resource,current});}
  catch(error){if(!current())return null;throw error;}
 };
 // Bounded installed-data diagnostic only. This does not fabricate a server
 // event or insert an effect into gameplay/native presentation lists.
 stage.probe=async actorId=>{
  const owner=presentation(),visuals=owner?.tables.visualeffects;if(!visuals)return null;
  let attempts=0;
  for(let id=0;id<(visuals.orderedRows??[...visuals.rows.values()]).length&&attempts<8;id++){
   if(!nativeStringEntry(visuals,id,'Imp_Root_M_Node').value)continue;attempts++;
   const result=await stage({actorId,record:{visualId:id,sourceId:actorId,bodyPart:0,transform:{scale:1,translate:[0,0,0],rotate:[0,0,0]}}});
   if(result===null||result.pending)return null;if(Object.keys(result.resources).length)return result;
  }
  throw Error('Installed visual-definition probe found no loadable geometry resource');
 };
 return stage;
}
