import * as T from 'three';
import {ModelReferenceScene} from '../../src/model_reference_scene.js';
import {exportVisualModel} from './export-visual-model.mjs';

// Decode/export on demand, once off the native presentation loop. Callers may
// cache the returned bundle within their connection/resource-package scope.
export function createVisualModelStaging({presentation,frontend,exporter=exportVisualModel}){
 const caches=new WeakMap();
 const exportModel=async function(name){
  if(typeof name!=='string'||!/^[a-z0-9_]{1,16}$/i.test(name))throw Error('Invalid visual model resource name');
  const owner=presentation(),world=frontend.world,areaId=world?.areaId,generation=frontend.areaGeneration;
  if(!owner||!owner.visuals)throw Error('Visual resource owner is unavailable');
  const current=()=>!owner.closed&&presentation()===owner&&frontend.world===world&&frontend.world?.areaId===areaId&&frontend.areaGeneration===generation;
  let asset;try{asset=await owner.visuals.asset(name.toLowerCase());}catch(error){if(!current())return null;throw error;}
  if(!current())return null;
  const scene=new T.Scene(),camera=new T.PerspectiveCamera(),owned=new Set();
  function destroy(instance){
   if(!owned.delete(instance))return;
   try{instance.references?.dispose();}finally{instance.root.removeFromParent();instance.dispose?.();}
  }
  function create(value,resource){
   const instance=owner.instantiate(value,resource);instance.model=value.model;instance.resourceName=resource;owned.add(instance);scene.add(instance.root);
   if(value.model.nodes.some(node=>node.type==='reference'))instance.references=new ModelReferenceScene({owner:instance,asset:value,sceneRoot:scene,createModel:create,destroyModel:destroy});
   return instance;
  }
  try{
   const model=create(asset,name.toLowerCase()),result=await exporter({scene,camera,model});
   return current()?result:null;
  }catch(error){if(!current())return null;throw error;
  }finally{for(const instance of [...owned])destroy(instance);scene.clear();}
 };
 return async name=>{
  if(typeof name!=='string'||!/^[a-z0-9_]{1,16}$/i.test(name))throw Error('Invalid visual model resource name');
  const owner=presentation(),world=frontend.world,generation=frontend.areaGeneration,areaId=world?.areaId;
  if(!owner)throw Error('Visual resource owner is unavailable');
  let cache=caches.get(owner);
  if(!cache||cache.world!==world||cache.generation!==generation||cache.areaId!==areaId){cache={world,generation,areaId,values:new Map()};caches.set(owner,cache);}
  const key=name.toLowerCase();
  if(!cache.values.has(key)){
   const work=exportModel(key).then(value=>{if(value===null)cache.values.delete(key);return value;}).catch(error=>{cache.values.delete(key);throw error;});
   cache.values.set(key,work);
  }
  const result=await cache.values.get(key);
  return presentation()===owner&&!owner.closed&&frontend.world===world&&frontend.areaGeneration===generation&&world?.areaId===areaId?result:null;
 };
}
