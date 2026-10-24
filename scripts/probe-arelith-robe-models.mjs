// Offline real-resource integration: production model planning, scene binding,
// transforms, animation and skin deformation. No wire session or game actions.
// Writes derived counts/bounds/hashes only, never proprietary model/image bytes.
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {TGALoader} from 'three/addons/loaders/TGALoader.js';
import {NetworkScene} from '../src/network_scene.js';
import {ModelAnimator} from '../src/model_animation.js';
import {createModelHierarchy} from '../src/model_hierarchy.js';
import {deformSkinnedVertices} from '../src/model_skinning.js';
import {decodeBioWarePlt,PLT_PALETTE_NAMES} from '../src/bioware_plt.js';
import {installedNetworkResources} from '../electron/installed_network_resources.mjs';
import {resolveServerResources} from '../src/network_resources.js';
import {ModelSourceCache} from '../src/model_source_cache.js';
import {parse2da} from '../src/area.js';
import {RESOURCE_TYPE,decodeResourceText} from '../src/resource_archive.js';
const[install,downloadFile,adFile,output]=process.argv.slice(2),download=JSON.parse(await fs.readFile(downloadFile)),ad=JSON.parse(await fs.readFile(adFile));
const report={scope:'Offline scene/animation/skin and palette integration; not live visual acceptance',httpAttempts:0,assets:[],animations:[],issues:[]},resources=installedNetworkResources({install,cacheDirectory:download.cache.directory,reuseInstalledNWSync:false,contentOptions:{fetch:()=>{report.httpAttempts++;throw Error('Offline only');}}});let scene,cache;
try{
 const result=await resolveServerResources(ad.requirements,{...resources,language:0});assert.ok(result.ready);
 const resolver=await resources.openModule(null,result.resolved);cache=new ModelSourceCache(resolver);
 const palettes=new Map(),tga=new TGALoader();for(const name of new Set(PLT_PALETTE_NAMES)){const image=tga.parse(await resolver.getResource(name,RESOURCE_TYPE.TGA));palettes.set(name,image);}
 const id=0xfffffff0,areaId=0x80000001,object={id,objectType:5,areaId,replicated:{position:[0,0,0],orientation:{yaw:0},animation:0,stats:{racialType:0}},appearance:{appearance:0,gender:0,phenotype:0,head:1,skin:0,hair:0,tattoo1:0,tattoo2:0,bodyParts:[],equipment:[{id:0x80000002,slot:2,item:{baseItem:16,modelType:3,parts:Array(18).fill(1).concat(3),colors:[10,20,30,40,50,60],partColors:Array.from({length:19},()=>Array(6).fill(255))}}]}};
 object.appearance.equipment[0].item.partColors[18]=[11,21,31,41,51,61];
 const objects=new Map([[id,object]]),world={localObjectId:id,areaId,registry:{objects,get:id=>objects.get(id)}};
 scene=new NetworkScene({world,resolver,report:(...args)=>report.issues.push(args),loadAsset:async(name,r,palette,candidates)=>{
  const model=await cache.load(name);let selected=null;
  for(const candidate of candidates){if(!resolver.hasResource(candidate,RESOURCE_TYPE.PLT))continue;const image=decodeBioWarePlt(await r.getResource(candidate,RESOURCE_TYPE.PLT),palettes,palette);selected={name:candidate,width:image.width,height:image.height,pixelsSha256:crypto.createHash('sha256').update(image.data).digest('hex')};break;}
  report.assets.push({name,palette,selected});return{model};
 },instantiate:asset=>{const hierarchy=createModelHierarchy(asset.model),instance={...hierarchy,model:asset.model,dispose:()=>{}};instance.animator=new ModelAnimator(asset.model,instance.root);return instance;},releaseAsset:()=>{}});
 scene.area={id:areaId};scene.tables={};for(const name of ['appearance','racialtypes','gender','phenotype','capart','parts_robe','baseitems','tailmodel','wingmodel','cloakmodel'])scene.tables[name]=parse2da(decodeResourceText(await resolver.getResource(name,RESOURCE_TYPE.TWO_DA)));
 scene.combat={base:()=>false,speedFor:()=>1,update:()=>{},unbind:()=>{}};
 const before=structuredClone(object);await scene.sync();assert.deepEqual(object,before);assert.equal(scene.failures.size,0,JSON.stringify(report.issues));
 const binding=scene.objects.get(id),robe=binding.model18;assert.ok(robe);assert.equal(robe.resourceName,'pmd0_robe003');assert.equal(robe.nativeVisualScope,18);assert.ok(report.assets.find(a=>a.name===robe.resourceName)?.selected);
 report.robedModels=binding.models.map(m=>m.resourceName);report.robePalette=report.assets.find(a=>a.name===robe.resourceName).palette;
 const skin=robe.model.nodes.find(n=>n.skinned);assert.ok(skin);const skinGroup=robe.nodeGroups.get(skin);
 const measure=()=>{robe.root.updateWorldMatrix(true,true);const vertices=deformSkinnedVertices(skin,robe.model.nodes,robe.groups,skinGroup,robe.nodeGroups);assert.ok(vertices.flat().every(Number.isFinite));return{vertices:vertices.length,min:[0,1,2].map(c=>Math.min(...vertices.map(v=>v[c]))),max:[0,1,2].map(c=>Math.max(...vertices.map(v=>v[c]))),hash:crypto.createHash('sha256').update(JSON.stringify(vertices)).digest('hex')};};
 for(const name of ['pause1','walk','1hslashl']){
  assert.ok(binding.models[0].animator.play(name,{loop:true}));assert.equal(robe.animator.clip.name,name);scene.update(1/60);const first=measure();for(let i=0;i<17;i++)scene.update(1/60);const last=measure();
  assert.equal(robe.animator.time,binding.models[0].animator.time);assert.notEqual(first.hash,last.hash,name+' must deform real robe skin');report.animations.push({name,first,last});
 }
 object.appearance.equipment[0].item.parts[18]=0;await scene.sync();const unrobed=scene.objects.get(id);assert.equal(unrobed.model18,null);assert.ok(unrobed.models.length>binding.models.length);report.unrobedModels=unrobed.models.map(m=>m.resourceName);
 const helmetBase=[...scene.tables.baseitems.rows].find(([,row])=>/helm/i.test(row.ItemClass??''));assert.ok(helmetBase,'An active helmet base-item row is required');
 const helmetId=0x80000003,modelType=Number(helmetBase[1].ModelType),helmet={id:helmetId,slot:1,item:{baseItem:helmetBase[0],modelType,parts:Array(modelType===2?3:modelType===3?19:1).fill(1),colors:[12,22,32,42,52,62]}};object.appearance.equipment.push(helmet);
 await scene.sync();const helmetBinding=scene.objects.get(id),worn=helmetBinding.worn[0];assert.ok(worn,JSON.stringify(report.issues));assert.equal(worn.itemId,helmetId);assert.equal(worn.anchor,'head_g');assert.equal(helmetBinding.models.some(m=>m.resourceName==='pmd0_head001'),false);report.helmet={resources:worn.pieces.map(p=>p.resourceName),scale:worn.scale};
 helmet.item.visualTransform={entries:[{key:0,value:{channels:[.5,1,1,0,0,0,0,0,0,1].map(value=>({value}))}}]};await scene.sync();assert.equal(scene.objects.get(id),helmetBinding);assert.equal(worn.pieces[0].root.parent.scale.x,.5);assert.equal(helmetBinding.visualTransforms.state.lookup(254),null);assert.equal(helmetBinding.visualTransforms.state.lookup(248),null);
 object.appearance.equipment.pop();await scene.sync();assert.equal(scene.objects.get(id).worn.length,0);assert.ok(scene.objects.get(id).models.some(m=>m.resourceName==='pmd0_head001'));
 object.appearance=JSON.parse(await fs.readFile(new URL('../backups/animations/creation-experience-mounted-appearance-fixture-v1.json',import.meta.url)));await scene.sync();
 const mounted=scene.objects.get(id);assert.ok(mounted,JSON.stringify(report.issues));const mountName=scene.tables.tailmodel.rows.get(object.appearance.fieldAA4).MODEL.toLowerCase(),mount=mounted.models.find(m=>m.resourceName===mountName);assert.ok(mount,JSON.stringify(report.issues));assert.equal(mount.nativeVisualScope,253);
 const chest=mounted.models.find(m=>m.resourceName.endsWith('_chest057')),chestMesh=chest.model.nodes.find(n=>n.meshSubtype==='danglymesh');assert.equal(chestMesh.type,'trimesh');assert.equal(chestMesh.faces.length,220);assert.ok(chest.model.materialNames.some(n=>n.toLowerCase()==='pmh0_chest057'));report.mounted={model:mountName,chest:chest.resourceName,chestFaces:chestMesh.faces.length,poses:[]};
 for(const name of ['pause2','walk']){
  assert.ok(mounted.models[0].animator.play(name,{loop:true}));assert.equal(mount.animator.clip.name,name);scene.update(.1);assert.equal(mount.animator.time,mounted.models[0].animator.time);
  mount.root.updateWorldMatrix(true,true);let vertices=0;for(const node of mount.model.nodes.filter(n=>n.skinned)){const v=deformSkinnedVertices(node,mount.model.nodes,mount.groups,mount.nodeGroups.get(node),mount.nodeGroups);assert.ok(v.flat().every(Number.isFinite));vertices+=v.length;}assert.ok(vertices>0);report.mounted.poses.push({name,vertices});
 }
 object.appearance.fieldAA4=0;await scene.sync();assert.equal(scene.objects.get(id).models.some(m=>m.resourceName===mountName),false);assert.equal(scene.instances.has(mount),false);
 assert.equal(report.httpAttempts,0);report.success=true;
}catch(error){report.failure=error.stack;process.exitCode=1;}
finally{await scene?.dispose();cache?.dispose();resources.close();await fs.writeFile(output,JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({success:report.success,httpAttempts:report.httpAttempts,assets:report.assets.length,robed:report.robedModels?.length,unrobed:report.unrobedModels?.length,animations:report.animations.map(a=>a.name),failure:report.failure}));}
