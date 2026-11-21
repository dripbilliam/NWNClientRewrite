import * as T from 'three';
import {loadCharacterCreationAssets} from '../../src/character_creation_assets.js';
import {prepareCreationRigTransfer} from './export-rigs.mjs';
import {exportGodotRoom} from './export-room.mjs';

export const CREATION_APPEARANCE_FIELDS=['gender','raceId','phenotype','head','clothes','skin','hair','tattoo1','tattoo2'];
export const CREATION_PREVIEW_TABLES=['appearance','racialtypes','gender','phenotype','chargenclothes'];
export function creationAppearance(draft){const value={};for(const key of CREATION_APPEARANCE_FIELDS){if(!Number.isInteger(draft?.[key])||draft[key]<0||draft[key]>65535)throw Error('Invalid creation appearance');value[key]=draft[key];}return value;}
export function previewTables(rules){return Object.fromEntries(CREATION_PREVIEW_TABLES.map(key=>{const t=rules[key];if(!t?.orderedRows||!t.rows?.entries)throw Error('Creation appearance table is unavailable: '+key);return[key,{orderedRows:t.orderedRows,entries:[...t.rows]}];}));}

export async function exportCreationPreview({scene,camera,models,draft}){
 scene.updateMatrixWorld(true);
 const rigs=prepareCreationRigTransfer({scene,models}),bounds=new T.Box3().setFromObject(scene);
 if(bounds.isEmpty()||![...bounds.min,...bounds.max].every(Number.isFinite))throw Error('Creation model has no finite visible bounds');
 const result=await exportGodotRoom({scene,camera,inventory:[],entities:[],buffer:[300,400],includeCamera:false,rigTransfer:rigs});
 if(!result.manifest.counts.meshes||result.manifest.meshes.some(m=>m.objectId!==0))throw Error('Creation mesh ownership is incomplete');
 Object.assign(result.manifest,{kind:'creation-preview',scope:'Private original creator body/part hierarchy; no gameplay object or collision',modelResources:models.map(m=>m.model.modelName),creationAppearance:creationAppearance(draft),bounds:{min:bounds.min.toArray(),max:bounds.max.toArray()}});
 return result;
}

export function createCreationPreviewStaging({frontend,resource,textureResource=null,loadTextures,buildObject,findObjectByName,createModelAnimator,load=loadCharacterCreationAssets,exporter=exportCreationPreview}){
 return async request=>{
  const owner=frontend.id;if(!owner)throw Error('Creation resource owner is unavailable');
  const draft=creationAppearance(request.draft),resolver={getResource:(...args)=>resource(owner,...args),...(textureResource?{getTextureResource:name=>textureResource(owner,name)}:{})},rules={creationResolver:resolver};
  for(const key of CREATION_PREVIEW_TABLES){const t=request.tables?.[key];if(!Array.isArray(t?.orderedRows)||!Array.isArray(t?.entries))throw Error('Creation appearance table is unavailable: '+key);rules[key]={orderedRows:t.orderedRows,rows:new Map(t.entries)};}
  const current=()=>frontend.id===owner;
  let textures,scene;const geometries=new Set(),materials=new Set(),roots=[];
  try{
   const data=await load(draft,rules);if(!current())return null;
   textures=await loadTextures(data.files,resolver,data.paletteRows);if(!current())return null;
   scene=new T.Scene();const models=[],animations=[];
   const build=(name,override)=>{const model=data.parsed.get(name),root=buildObject(model,textures,override,{previews:false});roots.push(root);root.userData.mdlRoot=model.modelName;root.traverse(o=>{if(o.geometry)geometries.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])materials.add(m);});const animator=createModelAnimator(model,root,'Creation preview',animations);root.traverse(o=>{if(o.geometry)geometries.add(o.geometry);});const value={model,root,animator};models.push(value);return value;};
   const body=build(data.bodyName);scene.add(body.root);
   for(const part of data.appearance.parts){const anchor=findObjectByName(body.root,part.node);if(!anchor)throw Error('Creation body anchor is unavailable: '+part.node);anchor.add(build(data.partNames.get(part),textures.get(data.partKeys.get(part))).root);}
   if(!current())return null;
   const result=await exporter({scene,camera:new T.PerspectiveCamera(),models,draft});return current()?result:null;
  }finally{for(const root of roots)root.traverse(o=>{if(o.geometry)geometries.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])materials.add(m);});scene?.clear();for(const g of geometries)g.dispose();for(const m of materials)m.dispose();for(const t of new Set(textures?.values()??[]))t.dispose();}
 };
}
