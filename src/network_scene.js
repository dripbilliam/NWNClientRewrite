import * as THREE from 'three';
import {parseTileset,parse2da,resolveCreatureModels,resolveDoorModel,decodeNwnColor,loadAreaWalkmesh} from './area.js';
import {pickedWorldObject} from './world_picking.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {nativeAnimationName} from './native_animation.js';
import {clientWeaponAnimationClass} from './client_combat_animation.js';
import {clientAnimationCategory} from './client_body_transition.js';
import {intEntry} from './combat_stats.js';
import {animateDoorState} from './door_animation.js';
import {networkDoorState} from './network_door.js';
import {parseDoorWalkmesh,findWalkableHeight} from './walkmesh.js';
import {groundItemModelPlan,selectGroundItemModels} from './item_model.js';
import {tileMainLightColors,applyTileMainLights} from './tile_lighting.js';
import {nativeWeaponAttachments} from './network_equipment_models.js';
import {visualLocalPoseServices} from './visual_scene_pose.js';
import {setModelLightPriority} from './model_light.js';
import {NetworkCombatPresentation} from './network_combat_presentation.js';
import {networkProjectilePresentation} from './network_projectile_presentation.js';
import {NetworkMotion} from './network_motion.js';
import {clientGaitSpeed} from './network_gait.js';
import {NetworkVisualPresentation} from './network_visual_presentation.js';
import {NetworkAreaVisualPresentation} from './network_area_visual_presentation.js';
import {nativeFloatEntry} from './movement_rate.js';
export {networkDoorState} from './network_door.js';

// Native item part order (SaveItem 14046b760, UpdateAppearance 1404ea6c0).
const bodyFields=['ArmorPart_RFoot','BodyPart_LFoot','BodyPart_RShin','BodyPart_LShin','BodyPart_LThigh','BodyPart_RThigh','BodyPart_Pelvis','BodyPart_Torso','BodyPart_Belt','BodyPart_Neck','BodyPart_RFArm','BodyPart_LFArm','BodyPart_RBicep','BodyPart_LBicep','BodyPart_RShoul','BodyPart_LShoul','BodyPart_RHand','BodyPart_LHand','BodyPart_Robe'];
const materialFields=['Leather1','Leather2','Cloth1','Cloth2','Metal1','Metal2'];
export function networkCreatureAppearance(object){
 const a=object.appearance;if(!a||!Number.isInteger(a.appearance))return null;
 const data={Appearance_Type:a.appearance,Appearance_Head:a.head??0,Phenotype:a.phenotype??0,Gender:a.gender??0,Race:object.replicated.stats?.racialType??object.replicated.stats?.fieldD20??0,
  Color_Skin:a.skin??0,Color_Hair:a.hair??0,Color_Tattoo1:a.tattoo1??0,Color_Tattoo2:a.tattoo2??0,XPosition:0,YPosition:0,ZPosition:0};
 for(const p of a.bodyParts??[])data[bodyFields[p.index]]=p.value;
 const armor=a.equipment?.find(e=>e.slot===2)?.item;
 if(armor?.modelType===3){for(const [i,value]of armor.parts.entries())data[bodyFields[i]]=value;for(const [i,name]of materialFields.entries())data['Color_'+name]=armor.colors[i];}
 return data;
}
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
 constructor({world,resolver,loadAsset,instantiate,releaseAsset,report,configureShadow=null}){
  Object.assign(this,{world,resolver,loadAsset,instantiate,releaseAsset,report,configureShadow});this.root=new THREE.Group();this.assets=new Map();this.instances=new Set();this.objects=new Map();this.failures=new Map();this.closed=false;this.animators=[];
  this.poses=visualLocalPoseServices({sceneRoot:this.root});
  this.motion=new NetworkMotion({height:(p,z)=>findWalkableHeight(this.groundTriangles??[],p[0],-p[1],z)??z,report});
 }
 async asset(name,palette=null,candidates=[],resolver=this.resolver){
  const key=JSON.stringify([name,palette,candidates]);if(!this.assets.has(key)){const started=performance.now();this.assets.set(key,Promise.resolve().then(()=>this.loadAsset(name,resolver,palette,candidates)).finally(()=>{const durationMs=performance.now()-started;if(durationMs>250)this.report('network.scene-asset-slow','Model resource preparation exceeded 250ms',{model:name,durationMs});}));}return this.assets.get(key);
 }
 async model(name,palette=null,candidates=[],resolver=this.resolver){
  const asset=await this.asset(name,palette,candidates,resolver);if(this.closed)throw new Error('Network scene is closed');const instance=this.instantiate(asset,name);instance.model=asset.model;instance.resourceName=name;this.instances.add(instance);if(instance.animator)this.animators.push(instance.animator);return instance;
 }
 destroyModels(models){for(const model of models){model.dispose();model.root.removeFromParent();this.instances.delete(model);}this.animators=this.animators.filter(a=>!models.some(m=>m.animator===a));}
 async itemModels(item,objectId){
  const plan=groundItemModelPlan(item,this.tables),resources=new Map(),resolver=Object.create(this.resolver),models=[];
  try{
   const selected=await selectGroundItemModels(plan,async name=>{try{const key=name.toLowerCase();resources.set(key,await this.resolver.getResource(key,RESOURCE_TYPE.MDL));return true;}catch{return false;}});
   resolver.getResource=(name,type)=>type===RESOURCE_TYPE.MDL&&resources.has(name.toLowerCase())?Promise.resolve(resources.get(name.toLowerCase())):this.resolver.getResource(name,type);
   for(const [index,selection]of selected.entries()){
    if(selection.fallback)this.report('network.scene-item-model-fallback','Native item model uses the active base-item default',{objectId,model:plan.models[index].primary,fallback:selection.name});
    const piece=await this.model(selection.name.toLowerCase(),plan.palette,[],resolver);models.push(piece);
    if(plan.defaultAnimation&&piece.animator?.model.animations.some(c=>c.name==='default'))piece.animator.play('default',{loop:true});
   }
   if(item.field462)this.report('network.scene-item-effects-unhandled','Native item visual-effect attachment is not connected',{objectId,value:item.field462});
   if(item.visualTransform?.entries?.length)this.report('network.scene-item-transform-unhandled','Native item visual transform presentation is not connected',{objectId});
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
 async loadArea(area){
  this.area=area;this.root.name=area.resRef;
  if(area.sounds.length||Object.values(area.ambient).some(Number))this.report('network.scene-audio-unhandled','Network area music and sound presentation is not connected',{areaId:area.id,sounds:area.sounds.length});
  if(area.weather.enabled&&area.weather.type)this.report('network.scene-weather-unhandled','Network weather presentation is not connected',{areaId:area.id,type:area.weather.type});
  const tileset=parseTileset(decodeResourceText(await this.resolver.getResource(area.tileset,RESOURCE_TYPE.SET)));
  const names=['placeables','genericdoors','doortypes','appearance','racialtypes','gender','phenotype','baseitems','parts_chest','lightcolor','ammunitiontypes','spells','visualeffects','progfx'];this.tables=Object.fromEntries(await Promise.all(names.map(async name=>[name,parse2da(decodeResourceText(await this.resolver.getResource(name,RESOURCE_TYPE.TWO_DA)))])));
  this.combat=new NetworkCombatPresentation({world:this.world,bindings:this.objects,tables:this.tables,pose:networkObjectPose,context:networkAnimationContext,report:this.report,microseconds:()=>BigInt(Math.trunc(performance.now()*1000))});
  this.projectiles=networkProjectilePresentation(this);
  this.visuals=new NetworkVisualPresentation(this);
  this.areaVisuals=new NetworkAreaVisualPresentation(this);
  this.tileLighting=[];
  const tiles=[];
  for(const [i,tile]of area.tiles.entries()){
   const f=tile.fields,name=tileset.tiles[f['14']]?.model;if(!name)throw new Error('Network tile has no model in the active tileset');
   tiles.push({model:name,height:f['18'],orientation:f['24']});
   const instance=await this.model(name);instance.root.position.set(i%area.width*10+5,f['18']*tileset.transition,-(Math.floor(i/area.width)*10+5));instance.root.rotation.y=f['24']*Math.PI/2;instance.root.userData.nativeStaticTile=true;this.root.add(instance.root);
   this.tileLighting.push({index:i,model:name,indices:[f['28'],f['29']],lights:applyTileMainLights(instance,name,tileMainLightColors([f['28'],f['29']],this.tables.lightcolor),this.configureShadow)});
  }
  const sourceTiles=area.tiles.filter(tile=>tile.fields['2a']||tile.fields['2b']).length;
  if(sourceTiles)this.report('network.scene-tile-flames-unhandled','Native tile source-flame animation and attachment are not connected',{areaId:area.id,tiles:sourceTiles});
  const walkmesh=await loadAreaWalkmesh({resRef:area.resRef,width:area.width,tileHeight:tileset.transition,tiles},this.resolver);this.groundTriangles=walkmesh.triangles;this.cameraTriangles=walkmesh.cameraTriangles;
  this.tileCount=area.tiles.length;await this.sync();return this;
 }
 lighting(){const f=this.area.fields;return{moonAmbientColor:decodeNwnColor(f['98']),moonDiffuseColor:decodeNwnColor(f['9c']),moonDiffuseDirection:[f.ac??0,f.b0??0,f.b4??0],sunAmbientColor:decodeNwnColor(f.b8),sunDiffuseColor:decodeNwnColor(f.bc),sunDiffuseDirection:[f.cc??0,f.d0??0,f.d4??0],sunShadows:f.c8,moonShadows:f.a8,shadowOpacity:f['104']};}
 async sync(){
  for(const object of this.world.registry.objects.values()){
   if(object.areaId!==this.area.id||object.replicationRemoved){this.remove(object.id);this.motion.objects.delete(object.id);continue;}
   if(![5,6,9,10].includes(object.objectType))continue;
   const pose=networkObjectPose(object);if(!pose)continue;
   const s=object.replicated??{};
   const signature=JSON.stringify(object.objectType===5?[object.appearance,s.stats?.racialType??s.stats?.fieldD20]:object.objectType===6?[object.item??s.item]:[s.appearance,s.doorType,s.genericType,object.staticState?.appearance,object.lightState?.appearance]);
   if(this.failures.get(object.id)===signature)continue;
   let binding=this.objects.get(object.id);
   if(binding?.signature!==signature){this.remove(object.id);binding=null;
    const models=[],held=[];let doorPickVertices=null;
    try{
     const wrapper=new THREE.Group();wrapper.userData.networkObjectId=object.id;wrapper.userData.worldObjectId=object.id;
     let bodyType=0;
     if(object.objectType===6){
      const item=object.item??s.item,pieces=await this.itemModels(item,object.id);for(const piece of pieces){wrapper.add(piece.root);models.push(piece);}
      if(s.visualTransform?.entries?.length)this.report('network.scene-item-transform-unhandled','Native item visual transform presentation is not connected',{objectId:object.id});
     }else if(object.objectType===5){
      const data=networkCreatureAppearance(object);if(!data)continue;
      const placement=resolveCreatureModels(data,object.id,{appearance:this.tables.appearance,racialTypes:this.tables.racialtypes,gender:this.tables.gender,phenotype:this.tables.phenotype});if(!placement)throw new Error('Network creature appearance is unavailable');
      bodyType=Number(/[PF]/.test(this.tables.appearance.rows.get(data.Appearance_Type)?.MODELTYPE??''));
      let main;try{main=await this.model(placement.model);}catch(error){if(!placement.fallbackModel||placement.fallbackModel===placement.model)throw error;main=await this.model(placement.fallbackModel);}
      wrapper.add(main.root);models.push(main);
      for(const part of placement.parts){
       let piece;try{piece=await this.model(part.model,placement.paletteColors,part.pltCandidates);}catch(error){if(!part.fallbackModel||part.fallbackModel===part.model)throw error;piece=await this.model(part.fallbackModel,placement.paletteColors,part.pltCandidates);}
       let anchor;main.root.traverse(node=>{if(!anchor&&node.name.toLowerCase()===part.node.toLowerCase())anchor=node;});
       if(!anchor){piece.dispose();this.instances.delete(piece);this.animators=this.animators.filter(a=>a!==piece.animator);throw new Error('Network creature part anchor '+part.node+' is unavailable in '+placement.model);}
       anchor.add(piece.root);models.push(piece);
      }
      if((data.BodyPart_Robe??0)!==0)this.report('network.scene-robe-unhandled','Network robe presentation is not connected',{objectId:object.id});
      await this.heldModels(object,main,models,held);
      for(const e of object.appearance.equipment??[])if(![2,16,32].includes(e.slot))this.report('network.scene-equipment-unhandled','Network worn equipment model attachment is not connected',{objectId:object.id,itemId:e.id,slot:e.slot});
      if(object.appearance.equipment?.some(e=>e.item.partColors?.some(row=>row.some(c=>c!==255))))this.report('network.scene-part-color-unhandled','Network per-part material colors are not connected',{objectId:object.id});
     }else{
      let name;
      if(object.objectType===9){const appearance=s.appearance??object.staticState?.appearance??object.lightState?.appearance;name=this.tables.placeables.rows.get(appearance)?.ModelName;}
      else{const door=resolveDoorModel(s.doorType,s.genericType,this.tables.genericdoors,this.tables.doortypes);if(door?.visible===false)continue;name=door?.model;}
      if(!name||name==='****')throw new Error('Network object appearance is unavailable');const model=await this.model(name.toLowerCase());wrapper.add(model.root);models.push(model);
      if(object.objectType===10)try{doorPickVertices=(parseDoorWalkmesh(await this.resolver.getResource(name.toLowerCase(),RESOURCE_TYPE.DWK))[0]??[]).flatMap(t=>t.vertices);}catch(error){this.report('network.scene-door-picking-unavailable',error.message,{objectId:object.id,model:name});}
     }
     wrapper.userData.nativeLoadedModelName=models[0]?.resourceName??'';
     binding={wrapper,models,held,signature,animation:null,bodyType,doorPickVertices};this.objects.set(object.id,binding);this.failures.delete(object.id);this.root.add(wrapper);
    }catch(error){for(const h of held){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(models);this.failures.set(object.id,signature);this.report('network.scene-object-failed',error.message,{objectId:object.id,objectType:object.objectType});continue;}
   }
   if(object.objectType===5){const motion=this.motion.ensure(object);if(motion)motion.modelType=binding.bodyType;}const displayPose=object.objectType===5?this.motion.pose(object.id):null;
   binding.wrapper.position.fromArray(displayPose?.position??pose.position);binding.wrapper.rotation.y=displayPose?.rotation??pose.rotation;
   if(binding.doorPickVertices?.length){binding.wrapper.updateWorldMatrix(true,false);const box=new THREE.Box3().setFromPoints(binding.doorPickVertices.map(v=>new THREE.Vector3(...v).applyMatrix4(binding.wrapper.matrixWorld))).expandByScalar(0.04);binding.pickBounds={min:box.min.toArray(),max:box.max.toArray()};}
   binding.wrapper.userData.worldPickingPlayer=object.id===this.world.localObjectId;
   for(const h of binding.held??[])h.root.userData.worldPickingPlayer=binding.wrapper.userData.worldPickingPlayer;
   const animation=s.animation;
   if(animation!==undefined&&binding.animation!==animation){const previousAnimation=binding.animation;binding.animation=animation;
    if(object.objectType!==5)this.combat.observeObjectBase(object,animation);
    if(object.objectType===5){
     if(this.combat.base(object,animation))continue;
     const name=nativeAnimationName(animation,networkAnimationContext(object,this.tables,binding.bodyType));const animator=binding.models[0].animator;
     const loop=![5,6,7,8,9].includes(animation)&&(clientAnimationCategory(5,animation)===1||[2,3,4].includes(animation));
     if(animator?.model.animations.some(c=>c.name===name))animator.play(name,{loop});else this.report('network.scene-animation-unavailable','Native animation clip is unavailable',{objectId:object.id,animation,clip:name});
    }else if(object.objectType===10&&networkDoorState(animation)!==null){
     binding.doorVisual??={animator:binding.models[0].animator};binding.doorVisual.animationState=networkDoorState(animation);
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
 receiveMovementChanges(events){for(const e of events)if(e.action==='movement'){const object=this.world.registry.get(e.id);if(object?.objectType===5&&!object.replicationRemoved&&object.areaId===this.area.id){const active=this.motion.objects.get(e.id)?.active;this.motion.observe(object,e.changes,e.created);if(!active&&this.motion.objects.get(e.id)?.active){const binding=this.objects.get(e.id);if(binding)binding.animation=null;}}}}
 async receiveProjectile(header){if(this.closed)return;this.combat.timer.snapshot();await this.projectiles.receive({header,areaId:this.world.areaId,source:this.world.registry.get(header.sourceId),target:this.world.registry.get(header.targetId)});}
 remove(id){const b=this.objects.get(id);if(!b)return;this.combat?.unbind(b);this.objects.delete(id);for(const h of b.held??[]){this.poses.forgetAttachment(h);h.root.removeFromParent();}this.destroyModels(b.models);b.wrapper.removeFromParent();}
 update(delta){if(this.closed)return;for(const [id,s]of this.motion.objects)s.visualAnimation=this.objects.get(id)?.combat?.visual??s.animation;this.motion.update(delta);
  for(const [id,s]of this.motion.objects){const o=this.world.registry.get(id);if(!o||!this.objects.has(id))continue;if(s.correctionCue)this.combat?.movementCue(o,s.correctionCue);if(s.facingTurn!==null&&s.facingTurn!==undefined)this.combat?.movementCue(o,{animation:s.facingTurn});}this.combat?.update(delta);
  const movementSpeeds=new Map();for(const [id,b]of this.objects){if(this.world.registry.get(id)?.objectType!==5)continue;const pose=this.motion.pose(id),motion=this.motion.objects.get(id);if(pose){b.wrapper.position.fromArray(pose.position);b.wrapper.rotation.y=pose.rotation;}
   if(motion?.active&&motion.gait){const animator=b.models[0].animator,distance=motion.animation===78||motion.animation===79 ? .8:nativeFloatEntry(this.tables.appearance,this.world.registry.get(id).appearance.appearance,[2,3,84,85].includes(motion.animation)?'WALKDIST':'RUNDIST').value;if(animator?.clip&&distance>0)movementSpeeds.set(animator,clientGaitSpeed(motion.gait,{distance,clipSeconds:animator.clip.length}));}
   if(motion?.finished){motion.finished=false;const object=this.world.registry.get(id),animation=motion.restingBase;if(this.combat?.base(object,animation))continue;const name=nativeAnimationName(animation,networkAnimationContext(object,this.tables,b.bodyType)),animator=b.models[0].animator;if(animator?.model.animations.some(c=>c.name===name))animator.play(name,{loop:true});}
  }
  for(const animator of this.animators)animator.update(delta*(movementSpeeds.get(animator)??this.combat?.speedFor(animator)??1));this.poses.updateAttachments();this.projectiles?.update(delta);this.visuals?.update(delta);this.areaVisuals?.update(delta);}
 pick(raycaster,{includePlayer=false}={}){
  if(this.closed)return null;
  // Closed-DWK bounds keep an open doorway selectable even when its leaf
  // swings into a wall. Bounds belong to render bindings, never replicated
  // game objects or a competing collision/pathfinding simulation.
  const picks={get:id=>this.world.registry.get(id),objects:new Map([...this.objects].map(([id,b])=>[id,{id,object:b.wrapper,pickBounds:b.pickBounds}]))};
  const visible=pickedWorldObject(raycaster,this.root,picks,{includePlayer});if(visible?.object)return{...visible,object:this.world.registry.get(visible.object.id)};
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
 snapshot({camera=null,bounds=null}={}){return{tiles:this.tileCount??0,tileLighting:structuredClone(this.tileLighting??[]),groundTriangles:this.groundTriangles?.length??0,objects:[...this.objects].map(([id,b])=>{const objectType=this.world.registry.get(id)?.objectType,value={id,objectType,position:b.wrapper.position.toArray(),models:b.models.length,animation:b.animation,clip:b.models[0].animator?.clip?.name??null};if(objectType===5)value.held=(b.held??[]).map(h=>({itemId:h.itemId,anchor:h.anchor,right:h.right,scale:h.scale,resources:h.pieces.map(p=>p.root.name),position:h.root.position.toArray()}));if([5,6,9,10].includes(objectType)){const box=new THREE.Box3().setFromObject(b.wrapper);if(objectType===6)value.resources=b.models.map(m=>m.root.name);if(!box.isEmpty()){value.bounds={min:box.min.toArray(),max:box.max.toArray()};if(camera&&bounds){camera.updateMatrixWorld();const center=box.getCenter(new THREE.Vector3()).project(camera);value.screen={x:bounds.left+(center.x+1)*bounds.width/2,y:bounds.top+(1-center.y)*bounds.height/2,z:center.z};}}}return value;}),failedObjects:[...this.failures.keys()]};}
 async dispose(){if(this.closed)return;this.closed=true;this.areaVisuals?.dispose();this.visuals?.dispose();this.projectiles?.dispose();this.root.removeFromParent();for(const id of [...this.objects.keys()])this.remove(id);for(const instance of this.instances)instance.dispose();this.instances.clear();this.animators=[];for(const promise of this.assets.values())try{this.releaseAsset(await promise);}catch{}this.assets.clear();}
}
