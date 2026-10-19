import {OBJECT_INVALID} from './game_object_array.js';
import {moduleTagKey,addModuleTag} from './module_tag_lookup.js';
import {removeAreaObject,addAreaObject,removeCreatureFromArea,addCreatureToArea,activateOnFirstClient} from './creature_area_lifecycle.js';
import {destroyCreature,destroyItem,destroyPlaceable,destroyWaypoint,destroyStore,destroyRepository,destroyEquipment,destroyBaseObject} from './object_destruction.js';
import {removeGroundObjectFromArea,addGroundObjectToArea,addStoreToArea,removePlaceableFromArea,addPlaceableToArea} from './world_object_area.js';
import {setCommonOrientation,setPlaceableOrientation} from './world_object_orientation.js';
import {removeAssociate,addSummonedAssociate,addHenchmanAssociate,unsummonCreature} from './summon_associate.js';
import {scriptAssociateAccess} from './henchman.js';
import {creatureAssociateId} from './associate_query.js';
import {disposeObjectAction} from './object_actions.js';
import {sendCombatFeedback} from './combat_broadcast.js';
import {setMovementRate} from './movement_rate.js';
import {removeAreaEffectFromArea,addAreaEffectToArea} from './area_effect.js';
import {associateListenPatterns} from './associate_listen_patterns.js';
import {receiveCorpseCleanup,scheduleCorpseCleanup} from './corpse_lifecycle.js';
import {removeEncounterActiveCreature,calculateEncounterPoints} from './encounter_activation.js';
import {secondsToWorldDelta} from './world_timer.js';
import {computeSafeLocation} from './safe_location.js';
import {constructSummonEffect,applySummonEffect,removeSummonEffect,receiveSummonEvent} from './summon_effect.js';
import {receiveAssociateCommand,broadcastAssociateCommand} from './associate_command.js';
import {realizeAssociates} from './player_area.js';
import {receiveItemDestroy} from './item_destroy_event.js';
import {budgeCreatures} from './world_displacement.js';
import {receiveWorldDestroy,closePlaceableInventory,placeableItemCount} from './world_destroy_event.js';
import {loadBodyBag,spawnBodyBag,receiveBodyBagAreaEvent} from './body_bag.js';
import {corpseBagAppearance,creatureCorpseItemCount} from './corpse_inventory.js';
import {acquireCorpseItems} from './corpse_transfer.js';
import {acquirePlaceableItem} from './item_acquisition.js';
import {intEntry} from './combat_stats.js';
import {setCreatureGold} from './creature_gold.js';
import {setOpenInventory,setInventoryGUIOpen,openPlaceableInventory,closePlaceableInventoryForPlayer} from './inventory_gui.js';
import {receiveInventoryInput,setInventoryCharacter,setInventoryPanel} from './inventory_input.js';
import {receiveContainerInput,stepContainerPage} from './container_input.js';
import {openItemInventory,closeItemInventory} from './item_inventory.js';
import {releaseObjectVisualTransforms,releaseObjectVisualPools,releaseCreatureVisualData} from './object_visual_data.js';
import {placeableField,placeableString,placeableResref,placeableLocalized,objectPortraitRef,releasePlaceableFields} from './placeable_fields.js';
import {releaseStoreFields} from './store_runtime.js';
const f=Math.fround,native=v=>[v[0],f(-v[2]),v[1]],render=v=>[v[0],v[2],f(-v[1])];

// Local-authority bridge for native world ownership. Canonical IDs, stored
// stale IDs, repository nodes and equipment slots remain separate owners.
export class ObjectLifecycleRuntime{
  constructor(session){this.session=session;this.destroying=new Set();this.realizing=new Set();}
  unsupported(o,message){return this.session.combat.unsupported(o,message);}
  areaProviders(){const s=this.session,c=s.combat,b=c.broadcastProviders();return{
    area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},ids:a=>a.nativeSpatial.view(),
    object:id=>s.registry.get(id)??null,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},asCreature:o=>o.objectType===5?o:null,asAreaEffect:o=>o.objectType===11?o:null,
    client:b.client,exitSuppressed:o=>o.nativeField9f4,dead:o=>Number(s.isDead(o)),dying:o=>Number(s.isDying(o)),
    setAILevel:(o,n)=>s.aiMaster.setLevel(o,n),hasAI:()=>Boolean(s.aiMaster),
    removeSpatial:(a,id)=>{a.nativeSpatial.remove(id);const i=a.objects.indexOf(id);if(i>=0)a.objects.splice(i,1);},
    insertSpatial:(a,id)=>{a.nativeSpatial.insert(id);if(!a.objects.includes(id))a.objects.push(id);},
    removeObject:(a,id)=>this.removeAreaObject(a,id),addObject:(a,id,flag)=>this.addAreaObject(a,id,flag),
    clearVisible:o=>o.perception.clear(),visibilityNode:(o,id)=>o.perception.node(id),removeVisible:(o,id)=>o.perception.remove(id),
    statsPC:o=>o.nativeStatsIsPCb0??0,areaService:a=>a.nativeField328??null,playerLeft:o=>this.unsupported(o,'Native area player-leaving service virtual20 is unavailable'),
    followingIds:o=>o.nativeFollowingAOEs.view(),removeAreaEffect:o=>removeAreaEffectFromArea(o,s.areaEffects.providers()),
    addAreaEffect:(o,a,x,y,z,flag)=>addAreaEffectToArea(o,a,[x,y,z],flag,s.areaEffects.providers()),
    setArea:(o,a)=>{o.areaId=a?.id??OBJECT_INVALID;},position:(o,point)=>{o.position=render(point);if(o.nativePosition)o.nativePosition=[...point];},orientation:o=>native(o.orientation),
    barter:o=>o.nativeBarter??null,cleanBarter:o=>this.unsupported(s.registry.get(o.ownerId)??{id:OBJECT_INVALID},'Native barter destruction cleanup is unavailable'),
    enqueue:(day,time,caller,target,id,payload)=>s.scheduler.enqueueDelta(target,{type:'combatAI',eventId:id,callerId:caller,payload},day,time),
    removeCreature:(o,flag)=>this.removeCreatureArea(o,flag),
    // AddToArea reads stats DM+ac here, not creature autoexplore+6e0.
    autoMapEnabled:o=>Number(o.isDM),reconcileMap:async(o,id)=>{await s.automap.reconcile(o);await s.automap.reveal(o,id,1);},
    message:()=>b,moduleInfoSucceeded:client=>client.nativeModuleInfoSucceededCC??0,warning:message=>c.warning(s.player,message),
    clientArea:(_m,client)=>this.unsupported(client.object,'Native ClientArea handshake uses the existing player transition adapter'),updateMap:(o,id)=>s.automap.update(o,id),
    activateOnEntry:o=>activateOnFirstClient(o,{
      asCreature:a=>a.objectType===5?a:null,asAreaEffect:a=>a.objectType===11?a:null,asTrigger:a=>a.objectType===7?a:null,
      asDoor:a=>a.objectType===10?a:null,asPlaceable:a=>{if(a.objectType!==9)return null;if(!Number.isInteger(a.nativeStatic5a0))this.unsupported(a,'Native placeable static load state is unavailable');return a;},
      scriptName:a=>({length:String(a.scripts?.heartbeat??'').split('\0')[0].length}),
    })
  };}
  addAreaObject(area,id,flag){return addAreaObject(area,id,flag,this.areaProviders());}
  removeAreaObject(area,id){return removeAreaObject(area,id,this.areaProviders());}
  removeCreatureArea(o,flag=0){return removeCreatureFromArea(o,flag,this.areaProviders());}
  addCreatureArea(o,a,x,y,z,force=0,flag=1){return addCreatureToArea(o,a,x,y,z,force,flag,this.areaProviders());}
  async budgeCreatures(area,origin,min,max,id,flag){
    const s=this.session,placement=s.encounters.placementProviders(),geometry=area.nativeGeometry?.objects;
    try{
      if(!geometry)throw new Error('Native displacement area geometry is unavailable');await geometry.load();
      return await budgeCreatures(area,origin,min,max,id,flag,{
        firstByX:(a,x)=>a.nativeSpatial.firstByX(x),ids:a=>a.nativeSpatial.view(),position:o=>native(o.position),
        creature:objectId=>{const o=s.registry.get(objectId);return o?.objectType===5?o:null;},
        door:objectId=>{const o=s.registry.get(objectId);return o?.objectType===10?o:null;},
        placeable:objectId=>{const o=s.registry.get(objectId);return o?.objectType===9?o:null;},
        safePoint:placement.safePoint,
        doorPoint:(o,point,force)=>geometry.nearestActionPoint(o,point,force),placeablePoint:(o,point)=>geometry.nearestPlaceablePoint(o,point),
        safeLocation:async(a,point,range,path,straight,out)=>{const result={point:[...out]},status=await computeSafeLocation(a,point,range,path,straight,result,placement);out.splice(0,3,...result.point);return status;},
        setPosition:(o,point,suppress)=>s.setPosition(o,render(point),suppress),
      });
    }catch(error){s.report(error,{areaId:area.id,objectId:id,operation:'native-area-budge-creatures'});throw error;}
  }
  async realizeAssociates(o,providers={}){
    const s=this.session,c=s.combat,m=c.jumpProviders();
    if(this.realizing.has(o.id))this.unsupported(o,'Native associate realization encountered an ownership cycle');
    this.realizing.add(o.id);
    try{return await realizeAssociates(o,{
      associates:a=>a.associateIds,creature:this.associateProviders().creature,module:()=>s.module,
      moduleArea:(_module,id)=>{const area=s.registry.get(id);return area?.objectType===4?area:null;},area:this.areaProviders().area,position:a=>native(a.position),
      safeLocation:m.safeLocation,addToArea:(...a)=>this.addCreatureArea(...a),realizeAssociates:a=>this.realizeAssociates(a),
      updateVisible:a=>c.updateVisibility(a),possessedFamiliar:a=>Number((a.associateType&65535)===3&&Boolean(c.broadcastProviders().client(a.id))),
      updateAutoMap:(a,id)=>s.automap.update(a,id),
      clearActions:a=>c.clearActions(a),warning:message=>c.warning(o,message),...providers,
    });}catch(error){s.report(error,{...s.diagnosticContext(o.id),operation:'native-realize-associates'});throw error;}
    finally{this.realizing.delete(o.id);}
  }
  removeItemArea(o){return removeGroundObjectFromArea(o,this.areaProviders());}
  addItemArea(o,area,x,y,z,flag=1){return addGroundObjectToArea(o,area,x,y,z,flag,{...this.areaProviders(),removeGround:a=>this.removeItemArea(a)});}
  addStoreArea(o,area,x,y,z,flag=1){return addStoreToArea(o,area,x,y,z,flag,this.areaProviders());}
  removeWaypointArea(o){return removeGroundObjectFromArea(o,this.areaProviders());}
  addWaypointArea(o,area,x,y,z,flag=1){return addGroundObjectToArea(o,area,x,y,z,flag,{...this.areaProviders(),removeGround:a=>this.removeWaypointArea(a)});}
  async setOrientation(o,vector){
    const area=this.areaProviders().area(o),geometry=o.objectType===9?area?.nativeGeometry?.objects:null;
    let previous,mesh;if(o.objectType===9&&area){if(!geometry)throw new Error('Native placeable orientation geometry is unavailable');await geometry.load();previous=geometry.preparePlaceableOrientation(o);}
    const write=(o,vector)=>{o.nativeOrientation=[...vector];o.orientation=render(vector);if(o.objectType===9)o.bearing=-Math.atan2(vector[0],vector[1]);};
    if(o.objectType!==9){setCommonOrientation(o,vector,{write});return;}
    await setPlaceableOrientation(o,vector,{
      threshold:Math.fround(.9999),orientation:o=>o.nativeOrientation??native(o.orientation),write,area:o=>this.areaProviders().area(o),
      appearance:o=>o.nativeMessageFields?.[0x32c]??o.authored.Appearance,
      mesh:async appearance=>mesh=await this.session.geometryResources.placeableMesh(appearance).then(value=>value?.mesh??null).catch(error=>{if(error.code!=='RESOURCE_NOT_FOUND'||error.resourceType!==2053)throw error;this.session.report(error,{...this.session.diagnosticContext(o.id),operation:'native-placeable-orientation-missing-pwk'});return null;}),
      slot:o=>o.nativeCollisionSlot,position:o=>o.nativePosition,replace:(_area,_slot,_id,_orientation,_position,value)=>geometry.replacePlaceable(o,value),points:o=>geometry.computePlaceablePoints(o,mesh),
    });
    if(geometry)geometry.commitPlaceableOrientation(o,previous);
  }
  async removePlaceableArea(o){
    const p=this.areaProviders(),old=p.area(o);
    if(old){if(!old.nativeGeometry?.objects)throw new Error('Native placeable removal geometry is unavailable');await old.nativeGeometry.objects.load();}
    return removePlaceableFromArea(o,{...p,
      removeStatic:(area,slot)=>{if(o.nativeCollisionSlot!==slot)throw new Error('Native placeable removal slot is inconsistent');return area.nativeGeometry.objects.removePlaceable(o);},
      removeObject:async(area,id)=>{if(area.nativeGeometry.objects.snapshots.has(id))await area.nativeGeometry.objects.removePlaceable(o);return this.removeAreaObject(area,id);},
      removeTrap:(area,id)=>area.nativeTrapIds158.remove(id),
    });
  }
  async addPlaceableArea(o,area,x,y,z,flag=1){
    if(!area)return addPlaceableToArea(o,null,x,y,z,flag,{removePlaceable:a=>this.removePlaceableArea(a)});
    const geometry=area.nativeGeometry?.objects;if(!geometry)throw new Error('Native placeable insertion geometry is unavailable');await geometry.load();
    const p=this.areaProviders();let mesh;
    o.nativePosition??=native(o.position);o.nativeOrientation??=native(o.orientation);
    return addPlaceableToArea(o,area,x,y,z,flag,{...p,removePlaceable:a=>this.removePlaceableArea(a),
      walkMesh:async a=>mesh=await geometry.placeableMesh(a),nativePosition:a=>a.nativePosition,
      addStatic:()=>geometry.insertPlaceable(o,mesh),
      addObject:async(a,id,n)=>{if(!geometry.snapshots.has(id))await geometry.insertPlaceable(o,mesh);return this.addAreaObject(a,id,n);},
      computeBoundingBox:a=>geometry.computePlaceablePoints(a,mesh),staticBounds:(_a,slot)=>geometry.store.getBounds(slot),
      displaceObjects:(...args)=>this.budgeCreatures(...args),
    });
  }
  bodyBagField(o,offset,value,width){
    return placeableField(o,offset,value,width);
  }
  bodyBagLocalized(o,offset,value){
    return placeableLocalized(o,offset,value);
  }
  loadBodyBag(o,appearance){const s=this.session;return loadBodyBag(o,appearance,{
    resref:placeableResref,tag:(o,value)=>{o.tag=value;},
    localized:(...args)=>this.bodyBagLocalized(...args),field:(...args)=>this.bodyBagField(...args),
    string:placeableString,portrait:objectPortraitRef,
    animation:(o,n)=>{o.nativeAnimationD8=n|0;},addTag:o=>addModuleTag(s.tags,o.tag,o.id),
  });}
  transferCorpseItems(bag,id,filter){
    const s=this.session,ownership=s.itemAcquisitionProviders(),object=(id,type)=>{const o=s.registry.get(id);return o?.objectType===type?o:null;};
    return acquireCorpseItems(bag,id,filter,{
      creature:id=>object(id,5),placeable:id=>object(id,9),hasEquipment:o=>Boolean(o.nativeEquipment),repository:o=>o.nativeRepository,
      equipment:(o,slot)=>o.nativeEquipment.get(slot,id=>object(id,6)),repositoryItem:(_r,node)=>object(node.id,6),baseInfo:i=>s.items.baseInfo(i),
      copyItem:(i,variables)=>s.items.copy(i,variables),
      acquire:(...args)=>acquirePlaceableItem(...args,ownership),
      constructItem:()=>s.register('item',`runtime:item:${s.registry.nextObjectId[0]}`,{authored:{},equipmentSlot:null,deferTagLookup:true}),
      loadTemplate:(item,name,flag)=>{if(flag!==0)throw new Error('Native corpse gold template flag is unavailable');return s.loadItemTemplate(item,name,'');},setGold:(o,n)=>setCreatureGold(o,n),
    });
  }
  spawnBodyBag(o){
    const s=this.session,object=id=>s.registry.get(id)??null,item=id=>{const o=object(id);return o?.objectType===6?o:null;},counts={
      hasEquipment:o=>Boolean(o.nativeEquipment),equipment:(o,slot)=>o.nativeEquipment.get(slot,item),repository:o=>o.nativeRepository,repositoryItem:(_r,node)=>item(node.id),
    };
    return spawnBodyBag(o,{
      asCreature:o=>o.objectType===5?o:null,asPlaceable:o=>o.objectType===9?o:null,object,asArea:o=>o?.objectType===4?o:null,
      creatureCount:(o,flag)=>creatureCorpseItemCount(o,flag,counts),placeableCount:(o,flag)=>placeableItemCount(o,flag,counts),
      construct:requestedId=>{if(requestedId!==OBJECT_INVALID)throw new Error('Native body-bag requested ID is unavailable');return s.register('placeable',`runtime:placeable:${s.registry.nextObjectId[0]}`,{authored:{},inventory:[],scripts:{},deferTagLookup:true});},
      appearance:o=>corpseBagAppearance(o,{entry:async(name,row,col)=>{const table=await s.items.table(name);if(!table)throw new Error(`Native body-bag ${name}.2da is unavailable`);return intEntry(table,row,col);},appearance:o=>o.objectType===9?o.nativeMessageFields[0x32c]:(o.creatureData??o.authored).Appearance_Type}),
      load:(...args)=>this.loadBodyBag(...args),destroy:o=>this.destroy(o),transfer:(...args)=>this.transferCorpseItems(...args),payload:()=>({}),
      localized:(...args)=>this.bodyBagLocalized(...args),field:(...args)=>this.bodyBagField(...args),position:o=>native(o.position),
      sourceName:o=>o.objectType===5?structuredClone((o.creatureData??o.authored).FirstName??{strRef:0xffffffff,entries:[]}):o.nativeBodyBagLocalized?.[0x308]??o.authored.LocalizedName??o.authored.LocName??{strRef:0xffffffff,entries:[]},
      enqueue:(day,time,caller,target,id,payload)=>this.areaProviders().enqueue(day,time,caller,target,id,payload),
    });
  }
  receiveBodyBagAreaEvent(area,payload){const s=this.session;return receiveBodyBagAreaEvent(area,payload,{
    lookup:id=>s.registry.getGameObject(id),asPlaceable:o=>o?.objectType===9?o:null,addToArea:(...args)=>this.addPlaceableArea(...args),releasePayload:()=>{},
  });}
  associateProviders(){const s=this.session,c=s.combat,b=c.broadcastProviders();return{
    module:()=>s.module,creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
    unsummon:o=>this.unsummon(o),setMovementRate:(o,n)=>setMovementRate(o,n,s.characterRules),
    listenPatterns:o=>{for(const entry of associateListenPatterns)s.setListenPattern(o,entry.pattern,entry.id);},
    setType:(o,n)=>{o.associateType=n&65535;if(o.associateType===0){if(o.id===OBJECT_INVALID)c.warning(o,'SetMasterId: cannot be own master');else o.masterId=OBJECT_INVALID;}},
    setMaster:(o,id)=>{if(o.id===(id>>>0))c.warning(o,'SetMasterId: cannot be own master');else o.masterId=id>>>0;},
    faction:id=>{if(!s.factionManager)throw new Error('Native faction manager is unavailable');return s.factionManager.get(id);},defaultFaction:()=>s.factionManager.defaultHostile,
    addFactionMember:(f,id,n)=>s.factionManager.addMember(f,id,n,s.factionProviders()),
    message:()=>b,clearActions:o=>c.clearActions(o),area:o=>this.areaProviders().area(o),position:o=>native(o.position),orientation:o=>native(o.orientation),
    visual:(a,id,point,orientation)=>s.effects.applyAtLocation(0,s.effects.create(30,OBJECT_INVALID,[id],0),{areaId:a.id,position:point,nativeOrientation:orientation}),
    feedback:(o,code,data)=>sendCombatFeedback(o,code,data,b),warning:message=>c.warning(s.player,message),client:b.client,
    sheet:client=>{if(!('characterSheetGUI' in client))this.unsupported(client.object,'Native associate character-sheet observer state is unavailable');return client.characterSheetGUI;},
    setDisplayed:(sheet,id)=>{sheet.displayedId=id;},notPermitted:(_m,client,id)=>s.onCombatMessage({recipientId:client.object.id,type:'character-sheet-not-permitted',objectId:id}),
    inventoryOpen:client=>client.inventoryGUI.field8,inventoryOwner:client=>client.inventoryGUI.ownerId,
    inventoryStatus:(_m,client,value,id)=>s.onCombatMessage({recipientId:client.object.id,type:'inventory-status',value,objectId:id}),
    setInventoryOpen:(client,a,b)=>setInventoryGUIOpen(client.inventoryGUI,a,b,this.inventoryGUIProviders()),enqueue:(...args)=>this.areaProviders().enqueue(...args)
  };}
  addAssociate(o,id){return addSummonedAssociate(o,id,this.associateProviders());}
  associateAccess(command,args){
    const s=this.session,b=s.combat.broadcastProviders(),creature=id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;};
    return scriptAssociateAccess(command,args,{creature,
      possessed:o=>Number((o.associateType&65535)===3&&Boolean(b.client(o.id))),
      // Native stats GetIsDM402f80 searches actual client objects only for
      // associate type0. Local isDM is the current client-info projection;
      // transport client-info import remains separate from canonical IDs.
      dm:o=>(o.associateType&65535)!==0?0:Number(Boolean(b.clients().find(c=>c.object?.id===o.id)?.object.isDM)),
      add:(o,id)=>addHenchmanAssociate(o,id,this.associateProviders()),
      remove:(o,id)=>this.removeAssociate(o,id),activity:(o,bit,value)=>s.combat.clearAttackActivity(o,bit,value),
      removeInvisibility:o=>s.combat.removeInvisibility(o),associate:(o,type,nth)=>creatureAssociateId(o,type,nth,creature)});
  }
  removeAssociate(o,id){return removeAssociate(o,id,this.associateProviders());}
  unsummon(o){return unsummonCreature(o,this.associateProviders());}
  commandProviders(){return{
    creature:this.associateProviders().creature,associates:o=>o.associateIds,
    receive:(o,n)=>this.receiveAssociate(o,n),unsummon:o=>this.unsummon(o),
    unpossess:o=>this.unsupported(o,'Native familiar unpossession is unavailable'),
    removeDomination:o=>this.unsupported(o,'Native domination effect removal is unavailable'),
    expression:(o,n)=>{const expressions=o.nativeListenExpressions;if(!expressions)this.unsupported(o,'Native associate listen-expression storage is unavailable');
      const value=expressions.entries.slice(0,expressions.count).find(e=>e.id===n);
      if(!value)this.unsupported(o,`Native associate listen expression ${n} is unavailable`);return value;},
    event:(caller,id,e)=>this.session.combat.enqueueEvent(10,caller,id,0,e)
  };}
  receiveAssociate(o,n){return receiveAssociateCommand(o,n,this.commandProviders());}
  broadcastAssociate(o,n){return broadcastAssociateCommand(o,n,this.commandProviders());}
  summonProviders(){const s=this.session,shared=this.associateProviders();return{
    asCreature:o=>o.objectType===5?o:null,creature:shared.creature,area:shared.area,position:shared.position,orientation:shared.orientation,
    addAssociate:(...args)=>this.addAssociate(...args),unsummon:o=>this.unsummon(o),visual:shared.visual,feedback:shared.feedback,
    construct:()=>s.register('creature',`runtime:creature:${s.registry.nextObjectId[0]}`,{areaId:OBJECT_INVALID,position:[0,0,0],authored:{},inventory:[],registerAI:true,isPC:false,isDM:false}),
    destroy:o=>this.destroy(o),areaById:id=>{const a=s.registry.get(id);return a?.objectType===4?a:null;},load:(o,name)=>s.loadCreatureTemplate(o,name),warning:message=>s.combat.warning(s.player,message),
    safeLocation:async(a,point,range,path,flag,out)=>{const target={point:[0,0,0]},result=await computeSafeLocation(a,point,range,path,flag,target,s.encounters.placementProviders());if(result===1)out.splice(0,3,...target.point);return result;},
    height:(a,point)=>s.encounters.placementProviders().height(a,point),
    day:seconds=>secondsToWorldDelta(seconds,s.worldTimer.secondsPerDay).day,time:seconds=>secondsToWorldDelta(seconds,s.worldTimer.secondsPerDay).time,
    enqueue:(...args)=>this.areaProviders().enqueue(...args),addToArea:(...args)=>this.addCreatureArea(...args),
    runEventScript:async(o,index)=>{if(index!==8)this.unsupported(o,`Native spawned-creature script slot ${index} is unavailable`);const name=o.scripts?.spawn;
      if(name)try{return await s.runScript(name,o.id,{scriptEventContext:5008});}catch(error){s.report(error,{...s.diagnosticContext(o.id),script:name,operation:'native-spawn-script'});return 0;}},
    createEffect:(...args)=>s.effects.create(...args),applyEffect:(o,e)=>s.effects.applyNative(e,o.id)
  };}
  constructSummon(args,self){const s=this.session;return constructSummonEffect(args,self,{create:(...a)=>s.effects.create(...a),setCreator:(...a)=>s.effects.setCreator(...a),creature:this.associateProviders().creature});}
  applySummon(o,e,loading){return applySummonEffect(o,e,loading,this.summonProviders());}
  removeSummon(o,e){return removeSummonEffect(o,e,this.summonProviders());}
  receiveSummon(o,data){return receiveSummonEvent(o,data,this.summonProviders());}
  requestDestroy(id,seconds,self){const s=this.session,delta=secondsToWorldDelta(seconds,s.worldTimer.secondsPerDay);this.areaProviders().enqueue(delta.day,delta.time,self>>>0,id>>>0,11,null);}
  removeTag(o){const s=this.session,key=moduleTagKey(o.tag??''),ids=s.tags.get(key);if(!ids)return;const i=ids.indexOf(o.id);if(i>=0)ids.splice(i,1);}
  releaseLocal(o,stage){
    if(stage==='stats'){o.stats=null;o.nativeTalentClasses=null;}
    else if(stage==='path')o.nativePathInfo=null;
    else if(stage==='round')o.combatRound=null;
    else if(stage==='repository')o.nativeRepository=null;
    else if(stage==='equipment')o.nativeEquipment=null;
    else if(stage==='creatureLists'){o.associateIds=null;o.personalReputationList=null;o.perception=null;o.inventory=[];}
    else if(stage==='creatureTail'){releaseCreatureVisualData(o);o.nativeFollowingAOEs?.setSize(0);o.nativeSubareaMembership?.setSize(0);}
    else if(stage==='itemProperties'){o.activeProperties=[];o.passiveProperties=[];o.nativeRepository=null;}
    else if(stage==='placeableLocal'){releasePlaceableFields(o);o.nativePlaceableActionPoints550=null;o.inventory=[];}
    else if(stage==='waypointLocal'){o.nativeName320=null;o.nativeMapNote310=null;}
    else if(stage==='storeLocal'){releaseStoreFields(o);o.nativeStoreClients350=null;o.nativeStoreRepositories=null;o.inventory=[];}
    else if(stage==='listenStrings'){o.nativeMatchedStrings?.clear();}
    else if(stage==='objectTail'){releaseObjectVisualTransforms(o);this.session.uuids.destroy(o);releaseObjectVisualPools(o);o.nativeCreatedAreaEffects170?.setSize(0);o.nativeLoopingVisuals160={records:[],capacity:0};o.nativeListenExpressions=null;o.locals=null;}
  }
  destructionProviders(){const s=this.session;return{
    creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},placeable:id=>{const o=s.registry.get(id);return o?.objectType===9?o:null;},
    removeAssociate:(...args)=>this.removeAssociate(...args),area:o=>this.areaProviders().area(o),removeCreatureArea:(...args)=>this.removeCreatureArea(...args),removeItemArea:o=>this.removeItemArea(o),
    removePlaceableArea:o=>this.removePlaceableArea(o),removeWaypointArea:o=>this.removeWaypointArea(o),setArea:(o,a)=>{o.areaId=a?.id??OBJECT_INVALID;},
    storeRepositories:o=>o.nativeStoreRepositories,client:id=>s.combat.broadcastProviders().client(id),
    closeStore:client=>this.unsupported(client.object,'Native retained store GUI closure1404b9520 is unavailable'),releaseStoreClient:()=>{},
    releaseLocal:(...args)=>this.releaseLocal(...args),removeAI:o=>s.aiMaster.removeObject(o),module:()=>s.module,removeTag:o=>this.removeTag(o),
    repository:o=>o.nativeRepository,equipment:o=>o.nativeEquipment,destroyRepository:repo=>destroyRepository(repo,{object:id=>s.registry.get(id),destroy:o=>this.destroy(o)}),
    destroyEquipment:equipment=>destroyEquipment(equipment,{item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},destroy:o=>this.destroy(o)}),
    clearAutoMap:o=>s.automap.clear(o),destroyBase:o=>this.destroyBase(o),
    removeAreaObject:(a,id)=>this.removeAreaObject(a,id),removeRegistry:o=>{s.registry.delete(o.id);s.sources.delete(o.sourceKey);s.triggerMembers.delete(o.id);},
    disposeEffect:e=>{e.linkLeft=null;e.linkRight=null;},disposeAction:node=>disposeObjectAction(node,situation=>s.deleteSituation(situation))
  };}
  destroyBase(o){return destroyBaseObject(o,this.destructionProviders());}
  receiveItemDestroy(o){
    const s=this.session,ownership=s.itemAcquisitionProviders();
    return receiveItemDestroy(o,{baseInfo:i=>s.items.baseInfo(i),
      clients:s.combat.broadcastProviders().clients,clientObject:c=>c.object,openContainerId:c=>this.inventoryGUIProviders().primary(c).openInventory.id,closeContainer:(...args)=>this.closeItemInventory(...args),
      object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,asItem:o=>o.objectType===6?o:null,asPlaceable:o=>o.objectType===9?o:null,asStore:o=>o.objectType===14?o:null,
      removeCreatureItem:(...a)=>ownership.removeCreatureItem(...a),repository:o=>{if(!o.nativeRepository)throw new Error('Native item destruction owner repository is unavailable');return o.nativeRepository;},
      repositoryIds:r=>r.ids(),removeRepositoryItem:(...a)=>ownership.removeRepositoryItem(...a),setPossessor:(...a)=>ownership.setPossessor(...a),
      hasInventory:o=>{if(!Number.isInteger(o.nativeHasInventory4f8))throw new Error('Native placeable destruction inventory flag4f8 is unavailable');return o.nativeHasInventory4f8;},
      inStore:()=>{throw new Error('Native item destruction store membership is unavailable');},removeStoreItem:()=>{throw new Error('Native item destruction store removal is unavailable');},
      lastHolder:i=>i.nativeLastHolder464,conversation:o=>{if(s.conversation.state?.participants.has(o.id))throw new Error('Native item destruction retained dialog inventory is unavailable');return null;},
      removeDialogItem:()=>{throw new Error('Native item destruction dialog item removal is unavailable');},removeFromArea:i=>this.removeItemArea(i),destroy:i=>this.destroy(i)});
  }
  corpseProviders(context){const s=this.session,p=this.areaProviders();return{
    possessed:a=>Number((a.associateType&65535)===3&&Boolean(s.combat.broadcastProviders().client(a.id))),dead:p.dead,
    spawnBag:a=>this.spawnBodyBag(a),
    spectacularEffect:(o,id,loading)=>s.effects.applyNative(s.effects.create(30,OBJECT_INVALID,[id]),o.id,context,loading),
    enqueue:(id,caller,target,time,payload)=>s.combat.enqueueEvent(id,caller,target,time,payload),playerDeath:o=>s.damage.playerEvent(10,o),
    removeFromArea:(...args)=>this.removeCreatureArea(...args),area:p.area,
    trapCount:a=>a.nativeTrapIds158.count,trapId:(a,n)=>a.nativeTrapIds158.ids[n],object:p.object,
    removeTrapObserver:(a,id)=>{if(!a.nativeTrapKnownIds)throw new Error('Native retained-area known-trap list is unavailable');a.nativeTrapKnownIds.remove(id);},
    encounter:id=>{const a=s.registry.get(id);return a?.objectType===13?a:null;},
    removeActiveCount:(a,cr,flag)=>removeEncounterActiveCreature(a,cr,flag,{points:(o,cr)=>calculateEncounterPoints(o,cr,s.encounters.providers()),
      worldTime:()=>s.worldTimer.time(),exhaustedEvent:a=>s.scheduler.enqueue(a.id,{type:'nativeSubareaScript',eventId:10,callerId:a.id,payload:{scriptEvent:21,objectIds:[a.id]}})}),
    destroy:a=>this.destroy(a)};}
  scheduleCorpse(o,effect,flag,context,loading=0){return scheduleCorpseCleanup(o,effect,flag,loading,this.corpseProviders(context));}
  receiveDestroy(o){return receiveCorpseCleanup(o,this.corpseProviders());}
  inventoryGUIProviders(){
    const s=this.session,b=s.combat.broadcastProviders(),p={
      primary:client=>{if(!client.inventoryGUI)throw new Error('Native primary inventory GUI is unavailable');return client.inventoryGUI;},
      alternate:client=>{if(!client.alternateInventoryGUI)throw new Error('Native alternate inventory GUI is unavailable');return client.alternateInventoryGUI;},
      lookup:id=>s.registry.getGameObject(id),asItem:o=>o.objectType===6?o:null,asPlaceable:o=>o.objectType===9?o:null,
      releaseEntry:()=>{},client:b.client,clientObject:client=>client.object,
      closeItem:(...args)=>this.closeItemInventory(...args),
      closePlaceable:(...args)=>this.closePlaceableInventoryForPlayer(...args),
      inventoryStatus:(client,value,id)=>s.onCombatMessage({recipientId:client.object.id,type:'inventory-status',value,objectId:id}),
      guiMessage:(client,id,value)=>s.onCombatMessage({recipientId:client.object.id,type:'inventory-gui',objectId:id,value}),
      enqueue:(caller,target,eventId,payload)=>s.combat.enqueueEvent(eventId,caller,target,0,payload),animation:(o,n)=>{o.nativeAnimationD8=n|0;},
    };
    p.setOwner=(...args)=>setOpenInventory(...args,p);p.setOpen=(...args)=>setInventoryGUIOpen(...args,p);return p;
  }
  openPlaceableInventory(o,playerId){return openPlaceableInventory(o,playerId,this.inventoryGUIProviders());}
  openItemInventory(o,playerId){return openItemInventory(o,playerId,{...this.inventoryGUIProviders(),baseInfo:i=>this.session.items.baseInfo(i)});}
  closeItemInventory(o,playerId,flag){return closeItemInventory(o,playerId,flag,{...this.inventoryGUIProviders(),baseInfo:i=>this.session.items.baseInfo(i)});}
  inventoryInputProviders(){
    const s=this.session,p={...this.inventoryGUIProviders(),creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      encumbrance:(...args)=>s.combat.encumbrance(...args),clientObjectId:c=>c.object.id,object:id=>s.registry.get(id)??null,
      asCreature:o=>o.objectType===5?o:null,repository:o=>{if(o.nativeRepository===undefined)throw new Error('Native inventory panel repository is unavailable');return o.nativeRepository;}};
    p.setCharacter=(...args)=>setInventoryCharacter(...args,p);p.setPanel=(...args)=>setInventoryPanel(...args,p);return p;
  }
  receiveInventoryInput(request,providers={}){
    const client=this.session.combat.broadcastProviders().client(this.session.player?.id);
    return receiveInventoryInput(client,request.subtype,{...this.inventoryInputProviders(),readBool:()=>request.value,readObjectId:()=>request.ownerId,readByte:()=>request.panel,overflow:()=>0,underflow:()=>0,...providers});
  }
  receiveContainerInput(request,providers={}){
    const s=this.session,p={...this.inventoryGUIProviders(),placeable:id=>{const o=s.registry.get(id);return o?.objectType===9?o:null;},repository:o=>{if(o.nativeRepository===undefined)throw new Error('Native container repository is unavailable');return o.nativeRepository;}};
    p.step=(...args)=>stepContainerPage(...args,p);
    return receiveContainerInput(s.combat.broadcastProviders().client(s.player?.id),request.subtype,{...p,readObjectId:()=>request.ownerId,overflow:()=>0,underflow:()=>0,...providers});
  }
  closePlaceableInventoryForPlayer(o,playerId,flag){return closePlaceableInventoryForPlayer(o,playerId,flag,this.inventoryGUIProviders());}
  closePlaceableInventory(o){
    const s=this.session,b=s.combat.broadcastProviders();return closePlaceableInventory(o,{
      clients:b.clients,clientObject:client=>client.object,client:b.client,
      inventory:client=>{const inventory=client.inventoryGUI?.openInventory;if(!inventory)throw new Error('Native placeable retained inventory GUI is unavailable');return{ownerId:inventory.id,open:inventory.field4};},
      inventoryStatus:(client,value,id)=>s.onCombatMessage({recipientId:client.object.id,type:'inventory-status',value,objectId:id}),
      setInventoryOpen:(client,...args)=>setInventoryGUIOpen(client.inventoryGUI,...args,this.inventoryGUIProviders()),
      clearInventory:(client,...args)=>setOpenInventory(client.inventoryGUI.openInventory,client,...args,this.inventoryGUIProviders()),
      guiMessage:(client,id,value)=>s.onCombatMessage({recipientId:client.object.id,type:'inventory-gui',objectId:id,value}),
      // Placeable vtable140df32f0+100 -> common SetAnimation14049abc0,
      // a direct DWORD d8 write, rather than creature animation remapping.
      enqueue:(caller,target,eventId,payload)=>s.combat.enqueueEvent(eventId,caller,target,0,payload),setAnimation:(o,n)=>{o.nativeAnimationD8=n|0;},
    });
  }
  receiveWorldDestroy(o){
    const s=this.session,p=this.areaProviders();return receiveWorldDestroy(o,{
      closeInventory:a=>this.closePlaceableInventory(a),
      spawnBag:a=>this.spawnBodyBag(a),
      removePlaceableArea:a=>this.removePlaceableArea(a),removeWaypointArea:a=>this.removeWaypointArea(a),area:p.area,
      removeAreaObject:(...args)=>this.removeAreaObject(...args),setArea:(o,a)=>{o.areaId=a?.id??OBJECT_INVALID;},destroy:a=>this.destroy(a),
    });
  }
  async destroy(o){
    const s=this.session;if(s.registry.get(o.id)!==o)return;
    if(this.destroying.has(o.id))throw new Error('Native ownership destruction encountered a cycle');
    if(s.conversation.state?.participants.has(o.id))this.unsupported(o,'Native active-dialog destruction lifecycle is unavailable');
    if(o.nativeBarter)this.unsupported(o,'Native barter destruction lifecycle is unavailable');
    this.destroying.add(o.id);
    try{if(o.objectType===5)await destroyCreature(o,this.destructionProviders());else if(o.objectType===6)await destroyItem(o,this.destructionProviders());
      else if(o.objectType===9)await destroyPlaceable(o,this.destructionProviders());else if(o.objectType===12)await destroyWaypoint(o,this.destructionProviders());
      else if(o.objectType===14){if(o.inventory?.length&&!o.nativeStoreInventoryImported)this.unsupported(o,'Native store destruction cannot own legacy unloaded inventory');await destroyStore(o,this.destructionProviders());}
      else if(o.objectType===11)await s.areaEffects.destroy(o);else this.unsupported(o,`Native ${o.kind} destruction owner is unavailable`);
    }finally{this.destroying.delete(o.id);}
  }
}
