import * as THREE from 'three';
import {manageLocalMatrix} from './managed_local_matrix.js';
import {ownMatrixSubtree} from './renderer_matrix_subtree.js';
import {cacheRootMatrix} from './cached_root_matrix.js';
import {parseTileset,parse2da,resolveCreatureModels,resolveDoorModel,decodeNwnColor,loadAreaWalkmesh} from './area.js';
import {pickedWorldObject} from './world_picking.js';
import {syncNetworkTriggerSurface,pickNetworkTriggerSurfaces} from './network_trigger_surface.js';
import {attachPlaceableHitMeshes,disposePlaceableHitMeshes} from './placeable_hit_mesh.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {nativeAnimationName} from './native_animation.js';
import {clientWeaponAnimationClass} from './client_combat_animation.js';
import {clientAnimationCategory} from './client_body_transition.js';
import {intEntry} from './combat_stats.js';
import {animateDoorState} from './door_animation.js';
import {networkDoorState} from './network_door.js';
import {parseDoorWalkmesh,findWalkableHeight} from './walkmesh.js';
import {WalkableHeightIndex} from './walkable_height_index.js';
import {groundItemModelPlan,selectGroundItemModels} from './item_model.js';
import {tileMainLightColors,applyTileMainLights} from './tile_lighting.js';
import {nativeWeaponAttachments} from './network_equipment_models.js';
import {visualLocalPoseServices} from './visual_scene_pose.js';
import {setModelLightPriority} from './model_light.js';
import {NetworkCombatPresentation} from './network_combat_presentation.js';
import {networkProjectilePresentation} from './network_projectile_presentation.js';
import {NetworkMotion} from './network_motion.js';
import {NetworkPathAcceptance} from './network_path_acceptance.js';
import {drivePreviewPlan,driveTurnFacing,drivePreviewPath,blockedDrivePreviewAnimation} from './network_drive_preview.js';
import {NetworkDriveGeometry} from './network_drive_geometry.js';
import {prepareResourceBatch} from './resource_preparation.js';
import {ResourcePrefetch} from './resource_prefetch.js';
import {NetworkSceneDelivery} from './network_scene_delivery.js';
import {clientGaitSpeed} from './network_gait.js';
import {NetworkVisualPresentation} from './network_visual_presentation.js';
import {NetworkAreaVisualPresentation} from './network_area_visual_presentation.js';
import {NetworkCreatureVoices} from './network_creature_voices.js';
import {NetworkParryVisual} from './network_parry_visual.js';
import {NetworkBloodVisual} from './network_blood_visual.js';
import {nativeFloatEntry} from './movement_rate.js';
import {resourceFlow} from './resource_flow.js';
import {networkModelVisuals} from './network_model_visuals.js';
import {networkCreatureAppearance,networkCreatureModelPlan,nativeHelmetAttachment,nativeCreatureAttachments,relayCreatureAnimations,creatureAnimationSource,networkBindingAnimator} from './network_creature_models.js';
export {networkCreatureAppearance} from './network_creature_models.js';
export {networkDoorState} from './network_door.js';

export function networkObjectPose(object){
 const s=object.replicated??{},fixed=object.staticState??object.lightState,position=s.position??fixed?.position;
 if(!position)return null;
 const orientation=s.orientation??fixed?.orientation;
 const vector=Array.isArray(orientation)?orientation:orientation?.vector;
 // Native A vectors and U yaw in the same captured snapshots agree here:
 // Fenthick [-.83147,-.55557,0] ->123.75deg; player [.92388,.38268,0] ->292.5deg.
 const rotation=vector?-Math.atan2(vector[0],vector[1]):(orientation?.yaw??0)*Math.PI/180;
 return{position:[position[0],position[2],-position[1]],rotation};
}
function objectRenderSignature(object){const s=object.replicated??{};return JSON.stringify(object.objectType===5?[object.appearance,s.stats?.racialType??s.stats?.fieldD20]:object.objectType===6?[object.item??s.item]:[s.appearance,s.doorType,s.genericType,object.staticState?.appearance,object.lightState?.appearance],(key,value)=>key==='visualTransform'?undefined:value);}
export function networkAnimationContext(object,tables,bodyType){
 const context={fieldDE:bodyType,fieldDD:0,fieldDF:0,fieldE0:0,fieldE8:0,fieldEC:0};
 if(!object.appearance?.equipment)throw new Error('Network equipment appearance state is unavailable');
 const baseInfo=item=>{const field=name=>intEntry(tables.baseitems,item.baseItem,name).value;return{weaponWield:field('WeaponWield'),weaponType:field('WeaponType'),weaponSize:field('WeaponSize')};};
 clientWeaponAnimationClass(object,{context:()=>context,equipped:(_o,slot)=>object.appearance.equipment.find(e=>e.slot===slot)?.item,baseInfo,
  weaponSize:(_o,item)=>item.baseItem===111?0:baseInfo(item).weaponSize-intEntry(tables.appearance,object.appearance.appearance,'SIZECATEGORY').value,
  warning:message=>{throw new Error(message);}});
 return context;
}

export class NetworkScene {
 constructor({world,resolver,loadAsset,instantiate,releaseAsset,report,configureShadow=null,prepareAsset=null,prepareAssets=null,oneShot=null,soundFactory=null,voiceCaption=null,releaseSources=()=>{},cancelResources=()=>{},loadTable=null,gore=()=>1,frameWork=null,cachedRootMatrices=false,matrixSubtrees=false}){
  this.matrixSubtrees=matrixSubtrees;
  Object.assign(this,{world,resolver,loadAsset,instantiate,releaseAsset,report,configureShadow,prepareAsset,prepareAssets,oneShot,soundFactory,voiceCaption,gore,frameWork,cachedRootMatrices});this.root=new THREE.Group();this.assets=new Map();this.instances=new Set();this.objects=new Map();this.failures=new Map();this.closed=false;this.animators=[];
  this.poses=visualLocalPoseServices({sceneRoot:this.root});
  this.motion=new NetworkMotion({height:(p,z)=>(this.groundHeightIndex&&this.groundHeightIndex.source===this.groundTriangles?this.groundHeightIndex.height(p[0],-p[1],z):findWalkableHeight(this.groundTriangles??[],p[0],-p[1],z))??z,report});
  this.pathAcceptance=new NetworkPathAcceptance(this);
  this.delivery=new NetworkSceneDelivery(this);this.releaseSources=releaseSources;this.cancelResources=cancelResources;
  this.loadTable=loadTable??(async name=>parse2da(decodeResourceText(await this.resolver.getResource(name,RESOURCE_TYPE.TWO_DA))));
  this.sourcePrefetch=new ResourcePrefetch({current:()=>!this.closed,read:async request=>{try{return await this.sourceAsset(request.model,request.paletteColors??null,request.pltCandidates??[]);}catch(error){if(!request.fallbackModel||request.fallbackModel===request.model||!request.current())throw error;return this.sourceAsset(request.fallbackModel,request.paletteColors??null,request.pltCandidates??[]);}}});
 }
 setGroundWalkmesh(walkmesh){this.groundHeightIndex?.dispose();this.groundTriangles=walkmesh.triangles;this.cameraTriangles=walkmesh.cameraTriangles;this.groundHeightIndex=this.closed?null:new WalkableHeightIndex(this.groundTriangles);}
 manageLocalMatrices(){this.managedMatrices=true;manageLocalMatrix(this.root);}
 workPriority(objectId=null){return this.loadingTiles||objectId===this.world.localObjectId||!this.objects.has(this.world.localObjectId)?0:1;}
 runFrameWork(work,kind,objectId=null){if(!this.frameWork)return work();return this.frameWork.run(work,{kind,priority:this.workPriority(objectId),current:()=>!this.closed});}
 async sourceAsset(name,palette=null,candidates=[],resolver=this.resolver){
  if(this.closed)throw Error('Network scene is closed');
  const key=JSON.stringify([name,palette,candidates]);if(!this.assets.has(key)){this.assetPending=(this.assetPending??0)+1;const started=performance.now();this.assets.set(key,Promise.resolve().then(()=>{if(this.closed)throw Error('Network scene is closed');return this.loadAsset(name,resolver,palette,candidates);}).finally(()=>{this.assetPending--;const durationMs=performance.now()-started;if(durationMs>250)this.report('network.scene-asset-slow','Model resource preparation exceeded 250ms',{model:name,durationMs});}));}
  return this.assets.get(key);
 }
 async asset(name,palette=null,candidates=[],resolver=this.resolver){
  const asset=await this.sourceAsset(name,palette,candidates,resolver);if(this.prepareAsset)await this.prepareAsset(asset,name,{priority:this.workPriority()});return asset;
 }
 prefetchObjects(objects){
  if(this.closed||!this.tables||!this.area)return;const requests=[];
  for(const object of objects){
   if(![5,9,10].includes(object.objectType)||object.id===this.world.localObjectId||this.objects.has(object.id)||object.areaId!==this.area.id||object.replicationRemoved||!networkObjectPose(object))continue;
   const signature=objectRenderSignature(object);if(this.objects.get(object.id)?.signature===signature||this.failures.get(object.id)===signature)continue;
   let plans=[];try{
    if(object.objectType===5){const placement=networkCreatureModelPlan(object,this.tables);if(!placement)continue;plans=[{model:placement.model,fallbackModel:placement.fallbackModel},...placement.parts.map(part=>({...part,paletteColors:part.paletteColors??placement.paletteColors})),...nativeCreatureAttachments(object,this.tables,placement.paletteColors).map(part=>({...part,pltCandidates:[part.model]}))];}
    else if(object.objectType===9){const s=object.replicated??{},appearance=s.appearance??object.staticState?.appearance??object.lightState?.appearance;plans=[{model:this.tables.placeables.rows.get(appearance)?.ModelName?.toLowerCase()}];}
    else if(object.objectType===10){const s=object.replicated??{},door=resolveDoorModel(s.doorType,s.genericType,this.tables.genericdoors,this.tables.doortypes);if(door?.visible===false)continue;plans=[{model:door?.model?.toLowerCase()}];}
   }catch{continue;} // The ordered consumer owns real errors and fallback policy.
   const current=()=>!this.closed&&this.world.registry.get(object.id)===object&&!object.replicationRemoved&&object.areaId===this.area.id&&objectRenderSignature(object)===signature;
   for(const plan of plans){if(!plan.model||plan.model==='****')continue;const key=JSON.stringify([plan.model,plan.paletteColors??null,plan.pltCandidates??[]]);if(!this.assets.has(key))requests.push({...plan,key,current});}
  }
  this.sourcePrefetch.enqueue(requests);
 }
 async model(name,palette=null,candidates=[],resolver=this.resolver){
  const asset=await this.asset(name,palette,candidates,resolver);return this.runFrameWork(()=>this.instantiateAsset(asset,name),'model');
 }
 instantiateAsset(asset,name){
  if(this.closed)throw new Error('Network scene is closed');const instance=this.instantiate(asset,name);if(this.cachedRootMatrices)instance.root.traverse(cacheRootMatrix);instance.model=asset.model;instance.resourceName=name;this.instances.add(instance);if(instance.animator)this.animators.push(instance.animator);return instance;
 }
 async preparedModel(result,request){
  // The ordered assembly owns this already-warmed asset. Do not rescan the
  // full light scene or recompile it for a second time immediately afterward.
  if(result?.status==='fulfilled')return this.runFrameWork(()=>this.instantiateAsset(result.value.asset,result.value.name),'model');
  try{return await this.model(request.model,request.paletteColors??null,request.pltCandidates??[]);}
  catch(error){if(!request.fallbackModel||request.fallbackModel===request.model)throw error;return this.model(request.fallbackModel,request.paletteColors??null,request.pltCandidates??[]);}
 }
 async prepareModels(requests){
  // A failure is observed by the existing ordered model consumer, which owns
  // fallbacks, diagnostics and partial-instance cleanup. Never attach here.
  const prepare=async(request,sourceOnly=false)=>{
   const load=name=>sourceOnly?this.sourceAsset(name,request.paletteColors??null,request.pltCandidates??[]):this.asset(name,request.paletteColors??null,request.pltCandidates??[]);
   try{return{asset:await load(request.model),name:request.model};}
   catch(error){if(!request.fallbackModel||request.fallbackModel===request.model)throw error;return{asset:await load(request.fallbackModel),name:request.fallbackModel};}
  };
  if(!this.prepareAssets)return prepareResourceBatch(requests,request=>prepare(request),{current:()=>!this.closed});
  const results=await prepareResourceBatch(requests,request=>prepare(request,true),{current:()=>!this.closed});
  try{if(!this.closed)await this.prepareAssets(results.filter(result=>result?.status==='fulfilled').map(result=>result.value),{priority:this.workPriority()});return results;}
  catch{
   // Isolate a bad shader/resource with the original per-model fallback path.
   // A failed member must not remove unrelated character parts from the scene.
   return prepareResourceBatch(requests,request=>prepare(request),{current:()=>!this.closed});
  }
 }
 destroyModels(models){for(const model of models){if(!this.instances.delete(model))continue;disposePlaceableHitMeshes(model);model.dispose();model.root.removeFromParent();}this.animators=this.animators.filter(a=>!models.some(m=>m.animator===a));}
 async itemModels(item,objectId){
  const plan=groundItemModelPlan(item,this.tables),resources=new Map(),resolver=Object.create(this.resolver),models=[];
  try{
   const selected=await selectGroundItemModels(plan,async name=>{try{const key=name.toLowerCase();resources.set(key,await this.resolver.getResource(key,RESOURCE_TYPE.MDL));return true;}catch{return false;}});
   resolver.getResource=(name,type)=>type===RESOURCE_TYPE.MDL&&resources.has(name.toLowerCase())?Promise.resolve(resources.get(name.toLowerCase())):this.resolver.getResource(name,type);
   for(const [index,selection]of selected.entries()){
    if(selection.fallback)this.report('network.scene-item-model-fallback','Native item model uses the active base-item default',{objectId,model:plan.models[index].primary,fallback:selection.name});
    const piece=await this.model(selection.name.toLowerCase(),plan.palette,[],resolver);piece.nativeVisualScope=selection.selector;piece.nativeItemComponent=true;models.push(piece);
    if(plan.defaultAnimation&&piece.animator?.model.animations.some(c=>c.name==='default'))piece.animator.play('default',{loop:true});
   }
   if(item.field462)this.report('network.scene-item-effects-unhandled','Native item visual-effect attachment is not connected',{objectId,value:item.field462});
   return models;
  }catch(error){this.destroyModels(models);throw error;}
 }
 async heldModels(object,main,models,held){
  const candidates=new Map();
  for(const e of object.appearance.equipment??[])if([16,32].includes(e.slot)&&!candidates.has(e.id)){
   try{const pieces=await this.itemModels(e.item,e.id),root=new THREE.Group();for(const p of pieces)root.add(p.root);models.push(...pieces);candidates.set(e.id,{root,pieces});}
   catch(error){this.report('network.scene-equipment-model-failed',error.message,{objectId:object.id,itemId:e.id,slot:e.slot});}
  }
  main.root.userData.mdlRoot??=main.root.name;
  for(const command of nativeWeaponAttachments(object,this.tables.appearance,{localObjectId:this.world.localObjectId,modelAvailable:id=>candidates.has(id)})){
   const candidate=candidates.get(command.itemId);if(!candidate)continue;
   try{
    candidate.root.scale.setScalar(command.scale);candidate.root.userData.worldObjectId=object.id;candidate.root.userData.worldPickingPlayer=object.id===this.world.localObjectId;
    if(!this.poses.setParent(candidate,main,command.anchor,0))throw new Error('Native equipment anchor '+command.anchor+' is unavailable');
    setModelLightPriority(candidate.root,command.priority);Object.assign(candidate,{itemId:command.itemId,anchor:command.anchor,right:command.right,scale:command.scale});held.push(candidate);
    const item=object.appearance.equipment.find(e=>e.id===command.itemId)?.item;
    if(item?.baseItem===15)this.report('network.scene-equipment-torch-unhandled','Native torch equip/unequip playback and wield-mode transitions are not connected',{objectId:object.id,itemId:command.itemId});
   }catch(error){this.poses.forgetAttachment(candidate);candidate.root.removeFromParent();this.report('network.scene-equipment-attachment-failed',error.message,{objectId:object.id,itemId:command.itemId,anchor:command.anchor});}
  }
 }
 async helmetModel(object,main,models,worn){
  const command=nativeHelmetAttachment(object,this.tables);if(!command)return;
  let candidate;
  try{
   const item=object.appearance.equipment.find(e=>e.id===command.itemId).item,pieces=await this.itemModels(item,command.itemId),root=new THREE.Group();for(const piece of pieces)root.add(piece.root);models.push(...pieces);
   candidate={root,pieces,...command};root.scale.setScalar(command.scale);root.userData.worldObjectId=object.id;root.userData.worldPickingPlayer=object.id===this.world.localObjectId;
   if(!this.poses.setParent(candidate,main,command.anchor,0))throw Error('Native helmet anchor '+command.anchor+' is unavailable');worn.push(candidate);
  }catch(error){if(candidate){this.poses.forgetAttachment(candidate);candidate.root.removeFromParent();this.destroyModels(candidate.pieces);for(const piece of candidate.pieces){const index=models.indexOf(piece);if(index>=0)models.splice(index,1);}}this.report('network.scene-helmet-model-failed',error.message,{objectId:object.id,itemId:command.itemId});}
 }
 async loadArea(area){
  this.area=area;this.root.name=area.resRef;
  let stageAt=performance.now();const stage=name=>{const now=performance.now();this.report('network.area-load-stage','Area preparation stage completed',{stage:name,areaId:area.id,durationMs:now-stageAt,tiles:area.tiles.length});stageAt=now;};
  if(area.weather.enabled&&area.weather.type)this.report('network.scene-weather-unhandled','Network weather presentation is not connected',{areaId:area.id,type:area.weather.type});
  const tileset=parseTileset(decodeResourceText(await this.resolver.getResource(area.tileset,RESOURCE_TYPE.SET)));
  stage('tileset');
  const names=['placeables','genericdoors','doortypes','appearance','racialtypes','gender','phenotype','baseitems','parts_chest','capart','parts_robe','tailmodel','wingmodel','cloakmodel','lightcolor','ammunitiontypes','spells','visualeffects','progfx','appearancesndset','weaponsounds','defaultacsounds','placeableobjsnds'];this.tables=Object.fromEntries(await Promise.all(names.map(async name=>[name,await this.loadTable(name)])));
  stage('rules');
  this.voices=new NetworkCreatureVoices({world:this.world,resolver:this.resolver,appearance:this.tables.appearance,soundFactory:this.soundFactory,caption:event=>this.voiceCaption?this.voiceCaption(event):this.report('network.quickchat-caption-unhandled','Native quick-chat caption output is unavailable',{objectId:event.actorId}),position:actor=>{const p=this.objects.get(actor.id)?.wrapper.position;return p?[p.x,-p.z,p.y]:actor.replicated.position;},report:this.report});
  const parry=new NetworkParryVisual(this);
  this.blood=new NetworkBloodVisual(this);
  this.combat=new NetworkCombatPresentation({world:this.world,bindings:this.objects,tables:this.tables,pose:networkObjectPose,context:networkAnimationContext,report:this.report,parryEffect:actor=>parry.receive(actor),impactEffect:(actor,source,record)=>this.blood.receive(actor,source,record),oneShot:cue=>this.oneShot?this.oneShot(cue):this.report('network.scene-combat-audio-unhandled','Native combat one-shot audio output is unavailable',{objectId:cue.objectId}),voice:(actor,code)=>{void this.voices.bark(actor.id,code);},microseconds:()=>BigInt(Math.trunc(performance.now()*1000))});
  this.projectiles=networkProjectilePresentation(this);
  this.visuals=new NetworkVisualPresentation(this);
  this.areaVisuals=new NetworkAreaVisualPresentation(this);
  this.tileLighting=[];
  const tiles=[];
  const tileNames=[...new Set(area.tiles.map(tile=>tileset.tiles[tile.fields['14']]?.model))];
  if(tileNames.some(name=>!name))throw new Error('Network tile has no model in the active tileset');
  this.loadingTiles=true;const tilePreparation=await this.prepareModels(tileNames.map(model=>({model}))),preparedTiles=new Map(tileNames.map((name,index)=>[name,tilePreparation[index]]));
  stage('tile-assets');
  for(const [i,tile]of area.tiles.entries()){
   const f=tile.fields,name=tileset.tiles[f['14']]?.model;if(!name)throw new Error('Network tile has no model in the active tileset');
   tiles.push({model:name,height:f['18'],orientation:f['24']});
   const instance=await this.preparedModel(preparedTiles.get(name),{model:name}),attach=()=>{instance.root.position.set(i%area.width*10+5,f['18']*tileset.transition,-(Math.floor(i/area.width)*10+5));instance.root.rotation.y=f['24']*Math.PI/2;instance.root.userData.nativeStaticTile=true;if(this.managedMatrices)manageLocalMatrix(instance.root);this.root.add(instance.root);
    this.tileLighting.push({index:i,model:name,indices:[f['28'],f['29']],lights:applyTileMainLights(instance,name,tileMainLightColors([f['28'],f['29']],this.tables.lightcolor),this.configureShadow)});
    if(this.matrixSubtrees&&this.managedMatrices){const release=ownMatrixSubtree(instance.root),dispose=instance.dispose;instance.dispose=()=>{release();dispose.call(instance);};}};
   if(this.frameWork)await this.runFrameWork(attach,'tile');else attach();
  }
  const sourceTiles=area.tiles.filter(tile=>tile.fields['2a']||tile.fields['2b']).length;
  stage('tile-instances');
  if(sourceTiles)this.report('network.scene-tile-flames-unhandled','Native tile source-flame animation and attachment are not connected',{areaId:area.id,tiles:sourceTiles});
  const walkmesh=await loadAreaWalkmesh({resRef:area.resRef,width:area.width,tileHeight:tileset.transition,tiles},this.resolver);this.setGroundWalkmesh(walkmesh);
  stage('walkmesh');this.loadingTiles=false;this.tileCount=area.tiles.length;await this.sync();stage('initial-objects');return this;
 }
 lighting(){const f=this.area.fields;return{moonAmbientColor:decodeNwnColor(f['98']),moonDiffuseColor:decodeNwnColor(f['9c']),moonDiffuseDirection:[f.ac??0,f.b0??0,f.b4??0],sunAmbientColor:decodeNwnColor(f.b8),sunDiffuseColor:decodeNwnColor(f.bc),sunDiffuseDirection:[f.cc??0,f.d0??0,f.d4??0],sunShadows:f.c8,moonShadows:f.a8,shadowOpacity:f['104']};}
 // Rendering loads must not hold NetworkFrontend's ordered replication queue.
 // One coalesced job bounds resource work; later updates request another pass.
 requestSync(){
  if(this.closed)return Promise.resolve();this.syncRequested=true;
  if(this.syncWork)return this.syncWork;
  const work=Promise.resolve().then(async()=>{while(this.syncRequested&&!this.closed){this.syncRequested=false;await this.sync();}});
  this.syncWork=work.finally(()=>{this.syncWork=null;if(this.syncRequested&&!this.closed)void this.requestSync().catch(error=>this.report('network.scene-sync-failed',error.message));});return this.syncWork;
 }
 async sync(){
  const objects=[...this.world.registry.objects.values()].sort((a,b)=>Number(b.id===this.world.localObjectId)-Number(a.id===this.world.localObjectId));
  if(this.objects.has(this.world.localObjectId)||!this.world.registry.get(this.world.localObjectId))this.prefetchObjects(objects);
  for(const object of objects){
   if(this.closed)return;
   if(object.areaId!==this.area.id||object.replicationRemoved){this.remove(object.id);this.motion.objects.delete(object.id);continue;}
   if(object.objectType===7){const sync=()=>{if(!this.closed&&this.world.registry.get(object.id)===object&&!object.replicationRemoved&&object.areaId===this.area.id)syncNetworkTriggerSurface(this,object);};if(this.frameWork)await this.runFrameWork(sync,'trigger',object.id);else sync();continue;}
   if(![5,6,9,10].includes(object.objectType))continue;
   let pose=networkObjectPose(object);if(!pose)continue;
   const s=object.replicated??{};
   const signature=objectRenderSignature(object);
   if(this.failures.get(object.id)===signature)continue;
   let binding=this.objects.get(object.id);
   if(binding?.signature!==signature){this.remove(object.id);binding=null;
    const models=[],held=[],worn=[],animationFollowers=[];let doorPickVertices=null,model18=null;
    try{
     const wrapper=new THREE.Group();wrapper.userData.networkObjectId=object.id;wrapper.userData.worldObjectId=object.id;
     let bodyType=0;
     if(object.objectType===6){
      const item=object.item??s.item,pieces=await this.itemModels(item,object.id);for(const piece of pieces){wrapper.add(piece.root);models.push(piece);}
     }else if(object.objectType===5){
      const data=networkCreatureAppearance(object);if(!data)continue;
      const placement=networkCreatureModelPlan(object,this.tables);if(!placement)throw new Error('Network creature appearance is unavailable');
      bodyType=Number(/[PF]/.test(this.tables.appearance.rows.get(data.Appearance_Type)?.MODELTYPE??''));
      let main;try{main=await this.model(placement.model);}catch(error){if(!placement.fallbackModel||placement.fallbackModel===placement.model)throw error;main=await this.model(placement.fallbackModel);}
      wrapper.add(main.root);models.push(main);
      const partRequests=placement.parts.map(part=>({...part,paletteColors:part.paletteColors??placement.paletteColors})),preparedParts=await this.prepareModels(partRequests);
      for(const [partIndex,part]of placement.parts.entries()){
       const piece=await this.preparedModel(preparedParts[partIndex],partRequests[partIndex]);
       let anchor=part.node===null?main.root:null;main.root.traverse(node=>{if(!anchor&&node.name.toLowerCase()===part.node.toLowerCase())anchor=node;});
       if(!anchor){piece.dispose();this.instances.delete(piece);this.animators=this.animators.filter(a=>a!==piece.animator);throw new Error('Network creature part anchor '+part.node+' is unavailable in '+placement.model);}
       anchor.add(piece.root);if(part.node==='head_g')piece.nativeVisualScope=254;if(part.nativeVisualScope!==undefined)piece.nativeVisualScope=part.nativeVisualScope;if(part.partIndex===18)model18=piece;models.push(piece);
      }
      await this.heldModels(object,main,models,held);
      await this.helmetModel(object,main,models,worn);
      if(model18?.animator)animationFollowers.push(model18.animator);
      for(const part of nativeCreatureAttachments(object,this.tables,placement.paletteColors,(message,data)=>this.report('network.scene-creature-attachment-failed',message,{objectId:object.id,...data}))){
       let piece;
       try{
        piece=await this.model(part.model,part.paletteColors,[part.model]);let anchor=null;main.root.traverse(node=>{if(!anchor&&node.name.toLowerCase()===part.node)anchor=node;});
        if(!anchor)throw Error('Native creature attachment '+part.node+' is unavailable');
        anchor.add(piece.root);piece.root.scale.setScalar(part.scale);piece.nativeVisualScope=part.nativeVisualScope;models.push(piece);if(piece.animator)animationFollowers.push(piece.animator);
       }catch(error){if(piece)this.destroyModels([piece]);this.report('network.scene-creature-attachment-failed',error.message,{objectId:object.id,model:part.model,scope:part.nativeVisualScope});}
      }
      for(const e of object.appearance.equipment??[])if(![1,2,16,32].includes(e.slot))this.report('network.scene-equipment-unhandled','Network worn equipment model attachment is not connected',{objectId:object.id,itemId:e.id,slot:e.slot});
     }else{
      let name;
      if(object.objectType===9){const appearance=s.appearance??object.staticState?.appearance??object.lightState?.appearance;name=this.tables.placeables.rows.get(appearance)?.ModelName;}
      else{const door=resolveDoorModel(s.doorType,s.genericType,this.tables.genericdoors,this.tables.doortypes);if(door?.visible===false)continue;name=door?.model;}
      if(!name||name==='****')throw new Error('Network object appearance is unavailable');const model=await this.model(name.toLowerCase());wrapper.add(model.root);models.push(model);
      if(object.objectType===9)attachPlaceableHitMeshes(model);
      if(object.objectType===10)try{doorPickVertices=(parseDoorWalkmesh(await this.resolver.getResource(name.toLowerCase(),RESOURCE_TYPE.DWK))[0]??[]).flatMap(t=>t.vertices);}catch(error){this.report('network.scene-door-picking-unavailable',error.message,{objectId:object.id,model:name});}
     }
     // Replication can advance while resources/compileAsync are pending. Never
     // attach a deleted, moved, replaced or changed appearance from that wait.
     if(this.closed||this.world.registry.get(object.id)!==object||object.replicationRemoved||object.areaId!==this.area.id||objectRenderSignature(object)!==signature){for(const h of [...held,...worn]){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(models);if(!this.closed)this.syncRequested=true;continue;}
     const attach=()=>{
      if(this.closed||this.world.registry.get(object.id)!==object||object.replicationRemoved||object.areaId!==this.area.id||objectRenderSignature(object)!==signature)return null;
      wrapper.userData.nativeLoadedModelName=models[0]?.resourceName??'';const currentPose=networkObjectPose(object);if(!currentPose)return null;wrapper.position.fromArray(currentPose.position);wrapper.rotation.y=currentPose.rotation;
      const animator=object.objectType===5?creatureAnimationSource(models[0]?.animator,animationFollowers):models[0]?.animator;
      const result={wrapper,models,held,worn,signature,animation:null,bodyType,doorPickVertices,model18,animator,animationFollowers:animationFollowers.filter(a=>a!==animator),model18Unavailable:false};result.visualTransforms=networkModelVisuals(this,object,result);if(this.cachedRootMatrices)wrapper.traverse(cacheRootMatrix);result.disposeRobeRelay=relayCreatureAnimations(animator,result.animationFollowers);this.objects.set(object.id,result);this.failures.delete(object.id);this.root.add(wrapper);if(object.id===this.world.localObjectId)this.prefetchObjects(objects);return result;
     };
     binding=this.frameWork?await this.runFrameWork(attach,'object',object.id):attach();if(!binding){for(const h of [...held,...worn]){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(models);if(!this.closed)this.syncRequested=true;continue;}
    }catch(error){for(const h of [...held,...worn]){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(models);if(this.closed)continue;this.failures.set(object.id,signature);this.report('network.scene-object-failed',error.message,{objectId:object.id,objectType:object.objectType});continue;}
   }
   pose=networkObjectPose(object);if(!pose){this.remove(object.id);continue;}
   binding.visualTransforms.sync(object);
   if(object.objectType===5){const motion=this.motion.ensure(object);if(motion)motion.modelType=binding.bodyType;}const displayPose=object.objectType===5?this.motion.pose(object.id):null;
   binding.wrapper.position.fromArray(displayPose?.position??pose.position);binding.wrapper.rotation.y=displayPose?.rotation??pose.rotation;
   if(binding.doorPickVertices?.length){const visual=binding.visualTransforms.root.group;visual.updateWorldMatrix(true,false);const box=new THREE.Box3().setFromPoints(binding.doorPickVertices.map(v=>new THREE.Vector3(...v).applyMatrix4(visual.matrixWorld))).expandByScalar(0.04);binding.pickBounds={min:box.min.toArray(),max:box.max.toArray()};}
   binding.wrapper.userData.worldPickingPlayer=object.id===this.world.localObjectId;
   for(const h of binding.held??[])h.root.userData.worldPickingPlayer=binding.wrapper.userData.worldPickingPlayer;
   for(const h of binding.worn??[])h.root.userData.worldPickingPlayer=binding.wrapper.userData.worldPickingPlayer;
   const localMotion=object.objectType===5?this.motion.objects.get(object.id):null;
   const animation=localMotion?.previewBase&&localMotion.active?localMotion.animation:s.animation;
   if(animation!==undefined&&binding.animation!==animation){const previousAnimation=binding.animation;binding.animation=animation;
    if(object.objectType!==5)this.combat.observeObjectBase(object,animation);
    if(object.objectType===5){
     if(this.combat.base(object,animation))continue;
     const name=nativeAnimationName(animation,networkAnimationContext(object,this.tables,binding.bodyType));const animator=networkBindingAnimator(binding);
     const loop=![5,6,7,8,9].includes(animation)&&(clientAnimationCategory(5,animation)===1||[2,3,4].includes(animation));
     if(animator?.model.animations.some(c=>c.name===name))animator.play(name,{loop});else this.report('network.scene-animation-unavailable','Native animation clip is unavailable',{objectId:object.id,animation,clip:name});
    }else if(object.objectType===10&&networkDoorState(animation)!==null){
     binding.doorVisual??={animator:networkBindingAnimator(binding)};binding.doorVisual.animationState=networkDoorState(animation);
     if(!animateDoorState(binding.doorVisual,networkDoorState(previousAnimation)))this.report('network.scene-animation-unavailable','Native door resting clip is unavailable',{objectId:object.id,animation});
    }else this.report('network.scene-object-animation-unhandled','Network object animation state is not connected',{objectId:object.id,animation});
   }
  }
  this.poses.updateAttachments();
 }
 receiveAnimationChanges(events){this.combat?.receive(events);}
 receiveVisualChanges(events){return this.visuals?.receive(events);}
 receiveObjectVisual(message){return this.visuals?.receiveInstant(message);}
 receiveAreaVisual(message){return this.areaVisuals?.receive(message);}
 canAcceptPaths(){return Boolean(this.tables&&this.groundTriangles);}
 acknowledgementGeometry(){return this.driveGeometry??=new NetworkDriveGeometry(this);}
 receiveMovementChanges(events){const work=[];for(const e of events)if(e.action==='movement'){const object=this.world.registry.get(e.id);if(object?.objectType===5&&!object.replicationRemoved&&object.areaId===this.area.id)work.push(this.pathAcceptance.observe(object,e.changes,e.created));}return Promise.all(work);}
 keyboardPose(id){const object=this.world.registry.get(id),m=object?this.motion.ensure(object):null;return m?{position:m.render.slice(),orientation:m.orientation.slice(),motionLifetime:m.lifetime}:null;}
 endKeyboard(id,lifetime){const m=this.motion.objects.get(id);if(m&&(lifetime===undefined||m.lifetime===lifetime)){m.previewGeneration=(m.previewGeneration??0)+1;this.motion.endDrive(id);}}
 previewKeyboard(id,flags,options={}){return resourceFlow(this.keyboardPreviewResources(id,flags,options));}
 *keyboardPreviewResources(id,flags,{capture=null}={}){
  const object=this.world.registry.get(id);if(this.closed||id!==this.world.localObjectId||!object||object.areaId!==this.area.id||object.replicationRemoved||blockedDrivePreviewAnimation(object.replicated?.animation))return;
  const m=this.motion.ensure(object);if(!m)return;
  if(object.replicated.field8D4!==undefined&&(object.replicated.field8D4&2)===0)return;
  const generation=m.previewGeneration=(m.previewGeneration??0)+1;m.driveHeld=true;
  if((flags&15)===0){this.motion.previewTurn(object,driveTurnFacing(m.orientation,flags));return;}
  const current=()=>!this.closed&&this.motion.objects.get(id)===m&&generation===m.previewGeneration&&id===this.world.localObjectId&&this.world.registry.get(id)===object&&!object.replicationRemoved&&object.areaId===this.area.id&&!blockedDrivePreviewAnimation(object.replicated?.animation)&&(object.replicated.field8D4===undefined||(object.replicated.field8D4&2)!==0),same=(a,b)=>a.every((value,i)=>value===b[i]),discarded=[];
  try{
   // Native planning is synchronous. Resource IO can let our pose advance;
   // replan against that new pose before installing a result. Bound retries
   // per input call; a later held-key tick can retry continually changing IO.
   for(let attempt=0;attempt<3;attempt++){
    if(!current())return;
    const from=m.position.slice(),render=m.render.slice(),orientation=m.orientation.slice(),walkRate=m.walkRate,runRate=m.runRate,appearance=object.appearance?.appearance,plan=drivePreviewPlan({position:from,orientation,walkRate,runRate},flags),trace=capture?{startedAt:performance.now(),from:from.slice(),render:render.slice(),orientation:orientation.slice(),walkRate,runRate,animation:m.animation,correction:m.correction,sequence:m.driveSequence,flags,generation,attempt,discardedAttempts:structuredClone(discarded),plan:structuredClone(plan)}:null;if(trace)capture(trace);
    const geometry=this.driveGeometry??=new NetworkDriveGeometry(this),clear=yield geometry.query(object,trace?{capture:query=>trace.query=query}:undefined),path=yield drivePreviewPath(from,plan.target,clear,{render});if(trace){trace.completedAt=performance.now();trace.applied=false;}
    if(!current()){if(trace)trace.discarded='owner-or-control-changed';return;}
    if(!same(m.position,from)||!same(m.render,render)||!same(m.orientation,orientation)||m.walkRate!==walkRate||m.runRate!==runRate||object.appearance?.appearance!==appearance){if(trace){trace.discarded='pose-changed';discarded.push({from:from.slice(),render:render.slice(),positionAfter:m.position.slice(),renderAfter:m.render.slice(),durationMs:trace.completedAt-trace.startedAt});}continue;}
    if(path)this.motion.previewDrive(object,{...plan,factor:path.factor},path.target);else this.motion.previewAnimation(object,plan.animation);if(trace)trace.applied=true;m.previewFailure=null;return path;
   }
  }catch(error){if(m.previewFailure!==error.message){m.previewFailure=error.message;this.report('network.drive-preview-unavailable',error.message,{objectId:id});}}
 }
 async receiveProjectile(header){if(this.closed)return;this.combat.timer.snapshot();await this.projectiles.receive({header,areaId:this.world.areaId,source:this.world.registry.get(header.sourceId),target:this.world.registry.get(header.targetId)});}
 remove(id){const b=this.objects.get(id);if(!b)return;this.blood?.remove(id);this.combat?.unbind(b);b.disposeRobeRelay?.();b.visualTransforms?.dispose();b.disposeTrigger?.();this.objects.delete(id);for(const h of [...b.held??[],...b.worn??[]]){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(b.models);b.wrapper.removeFromParent();}
 update(delta){if(this.closed)return;this.pathAcceptance?.update();for(const [id,s]of this.motion.objects)s.visualAnimation=this.objects.get(id)?.combat?.visual??s.animation;this.motion.update(delta);
  for(const [id,s]of this.motion.objects){const b=this.objects.get(id),o=this.world.registry.get(id);if(!b||!o||!s.previewBase||!s.active&&!s.previewAnimationPending)continue;s.previewAnimationPending=false;if((b.combat?.base??b.animation)===s.animation)continue;
   try{b.animation=s.animation;if(this.combat?.base(o,s.animation))continue;const name=nativeAnimationName(s.animation,networkAnimationContext(o,this.tables,b.bodyType));if(!networkBindingAnimator(b)?.play(name,{loop:true}))throw Error('Native keyboard clip '+name+' is unavailable');}
   catch(error){this.report('network.drive-animation-unavailable',error.message,{objectId:id});}
  }
  for(const [id,s]of this.motion.objects){const o=this.world.registry.get(id);if(!o||!this.objects.has(id))continue;if(s.correctionCue)this.combat?.movementCue(o,s.correctionCue);if(s.facingTurn!==null&&s.facingTurn!==undefined)this.combat?.movementCue(o,{animation:s.facingTurn});}this.combat?.update(delta);
  const movementSpeeds=new Map();for(const [id,b]of this.objects){if(this.world.registry.get(id)?.objectType!==5)continue;const pose=this.motion.pose(id),motion=this.motion.objects.get(id);if(pose){b.wrapper.position.fromArray(pose.position);b.wrapper.rotation.y=pose.rotation;}
   if(motion?.active&&motion.gait){const animator=networkBindingAnimator(b),distance=motion.animation===78||motion.animation===79 ? .8:nativeFloatEntry(this.tables.appearance,this.world.registry.get(id).appearance.appearance,[2,3,84,85].includes(motion.animation)?'WALKDIST':'RUNDIST').value;if(animator?.clip&&distance>0)movementSpeeds.set(animator,clientGaitSpeed(motion.gait,{distance,clipSeconds:animator.clip.length}));}
   if(motion?.finished){motion.finished=false;const object=this.world.registry.get(id),animation=motion.restingBase;motion.animation=animation;b.animation=animation;if(this.combat?.base(object,animation))continue;const name=nativeAnimationName(animation,networkAnimationContext(object,this.tables,b.bodyType)),animator=networkBindingAnimator(b);if(animator?.model.animations.some(c=>c.name===name))animator.play(name,{loop:true});}
  }
  for(const b of this.objects.values())b.visualTransforms?.update();
  for(const b of this.objects.values())for(const animator of b.animationFollowers??[])movementSpeeds.set(animator,movementSpeeds.get(networkBindingAnimator(b))??this.combat?.speedFor(networkBindingAnimator(b))??1);
  for(const animator of this.animators)animator.update(delta*(movementSpeeds.get(animator)??this.combat?.speedFor(animator)??1));this.poses.updateAttachments();this.blood?.update(delta);this.projectiles?.update(delta);this.voices?.update();this.visuals?.update(delta);this.areaVisuals?.update(delta);}
 pick(raycaster,{includePlayer=false,objectsOnly=false}={}){
  if(this.closed||this.graphicsPending)return null;
  // Closed-DWK bounds keep an open doorway selectable even when its leaf
  // swings into a wall. Bounds belong to render bindings, never replicated
  // game objects or a competing collision/pathfinding simulation.
  const picks={get:id=>this.world.registry.get(id),objects:new Map([...this.objects].map(([id,b])=>[id,{id,object:b.wrapper,pickBounds:b.pickBounds}]))};
  const visible=pickNetworkTriggerSurfaces(this,raycaster,pickedWorldObject(raycaster,this.root,picks,{includePlayer,frame:this.pickFrame}));if(visible?.object)return{...visible,object:this.world.registry.get(visible.object.id)};
  if(objectsOnly)return null;
  let point=null,distance=Infinity;const target=new THREE.Vector3();
  for(const triangle of this.groundTriangles??[]){
   const vertices=triangle.vertices.map(v=>new THREE.Vector3(...v));const hit=raycaster.ray.intersectTriangle(...vertices,false,target);
   if(hit){const d=hit.distanceTo(raycaster.ray.origin);if(d<distance){distance=d;point=hit.clone();}}
  }
  if(!point)return null;
  // Preserve visible scenery occlusion. This is geometric hit testing only;
  // reachability, obstacles and pathfinding remain owned by the server.
  if(visible&&visible.distance+0.05<distance&&Math.abs(visible.point.y-point.y)>0.4)return null;
  return{object:null,point,distance};
 }
 snapshot({camera=null,bounds=null}={}){return{frameWork:this.frameWork?.snapshot()??null,blood:this.blood?.snapshot()??[],voices:this.voices?.snapshot()??null,areaId:this.area?.id??null,resRef:this.area?.resRef??null,attached:Boolean(this.root.parent),graphicsPending:Boolean(this.graphicsPending),tiles:this.tileCount??0,tileLighting:structuredClone(this.tileLighting??[]),groundTriangles:this.groundTriangles?.length??0,groundHeightIndex:this.groundHeightIndex?.snapshot()??null,objects:[...this.objects].map(([id,b])=>{const objectType=this.world.registry.get(id)?.objectType,value={id,objectType,position:b.wrapper.position.toArray(),models:b.models.length,animation:b.animation,clip:networkBindingAnimator(b)?.clip?.name??null};value.visualTransforms=b.visualTransforms?.snapshot()??null;if(objectType===5){value.appearance=this.world.registry.get(id)?.appearance?.appearance;value.resources=b.models.map(m=>m.resourceName);}if(objectType===5)value.held=(b.held??[]).map(h=>({itemId:h.itemId,anchor:h.anchor,right:h.right,scale:h.scale,resources:h.pieces.map(p=>p.root.name),position:h.root.position.toArray()}));if([5,6,7,9,10].includes(objectType)){const box=new THREE.Box3().setFromObject(b.wrapper);if(objectType===6)value.resources=b.models.map(m=>m.root.name);if(!box.isEmpty()){value.bounds={min:box.min.toArray(),max:box.max.toArray()};if(camera&&bounds){camera.updateMatrixWorld();const center=box.getCenter(new THREE.Vector3()).project(camera);value.screen={x:bounds.left+(center.x+1)*bounds.width/2,y:bounds.top+(1-center.y)*bounds.height/2,z:center.z};}}}return value;}),failedObjects:[...this.failures.keys()]};}
 async dispose(){if(this.closed)return;this.closed=true;this.frameWork?.dispose();this.retiredFrameWork=this.frameWork?.snapshot()??null;this.sourcePrefetch.close();this.cancelResources();this.pathAcceptance.dispose();this.cancelGraphics?.();this.delivery.dispose();this.voices?.dispose();this.blood?.dispose();this.areaVisuals?.dispose();this.visuals?.dispose();this.projectiles?.dispose();this.root.removeFromParent();await this.syncWork?.catch(()=>{});await this.sourcePrefetch.idle();await Promise.allSettled([...this.pathAcceptance.running.values()]);for(const id of [...this.objects.keys()])this.remove(id);for(const instance of this.instances)instance.dispose();this.instances.clear();this.animators=[];for(const promise of this.assets.values())try{this.releaseAsset(await promise);}catch{}this.assets.clear();this.groundHeightIndex?.dispose();this.retiredGroundHeightIndex=this.groundHeightIndex?.snapshot()??null;this.groundHeightIndex=null;this.releaseSources();}
}
