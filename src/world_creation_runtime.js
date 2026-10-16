import {scriptCreateObject} from './create_object.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {computeSafeLocation} from './safe_location.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
const f=Math.fround,render=point=>[f(point[0]),f(point[2]),f(-point[1])],native=point=>[f(point[0]),f(-point[2]),f(point[1])];

// Concrete providers for the independently compared five-type command. Each
// newly constructed object is the canonical record used by its data loader,
// area/spatial/collision owners, scripts and renderer; no preview-only IDs.
export class WorldCreationRuntime{
 constructor(session){this.session=session;}
 providers(self){
  const s=this.session,b=s.combat.broadcastProviders(),placement=s.encounters.placementProviders();return{
   getGameObject:id=>s.registry.getGameObject(id),asArea:o=>o?.objectType===4?o:null,
   construct:kind=>s.register(kind,`runtime:${kind}:${s.registry.nextObjectId[0]}`,{tag:'',authored:{},areaId:OBJECT_INVALID,position:[0,0,0],inventory:[],deferTagLookup:true,registerAI:kind==='creature',isPC:false,isDM:false,equipmentSlot:null}),
   loadTemplate:(kind,o,name,tag)=>kind==='creature'?s.loadCreatureTemplate(o,name,tag):kind==='item'?s.loadItemTemplate(o,name,tag):s.worldTemplates.load(kind,o,name,tag),
   warning:message=>runtimeDiagnostics.record('object.creation-warning',message,{...s.diagnosticContext(self),operation:'native-create-object'}),destroy:o=>s.lifecycle.destroy(o),
   position:(o,point,flag)=>s.setPosition(o,render(point),flag),orientation:(o,vector)=>s.lifecycle.setOrientation(o,vector),placeableOrientation:(o,vector)=>s.lifecycle.setOrientation(o,vector),
   safeLocation:async(area,point,range,path,flag,out)=>{const result={point:[...out]},status=await computeSafeLocation(area,point,range,path,flag,result,placement);out.splice(0,3,...result.point);return status;},height:placement.height,
   createEffect:flag=>{if(flag!==1)throw new Error('Native creation effect constructor flag is unavailable');return s.effects.create(0,OBJECT_INVALID);},setCreator:(...args)=>s.effects.setCreator(...args),
   applyEffect:(o,e,loading,flag)=>{if(flag!==0)throw new Error('Native creation effect apply flag is unavailable');return s.effects.applyNative(e,o.id,undefined,loading);},
   addToArea:(kind,o,area,...args)=>({creature:()=>s.lifecycle.addCreatureArea(o,area,...args),item:()=>s.lifecycle.addItemArea(o,area,...args),waypoint:()=>s.lifecycle.addWaypointArea(o,area,...args),placeable:()=>s.lifecycle.addPlaceableArea(o,area,...args),store:()=>s.lifecycle.addStoreArea(o,area,...args)})[kind](),
   appendTrap:(area,id)=>{if(!area?.nativeTrapIds158)throw new Error('Native created-placeable area trap list is unavailable');area.nativeTrapIds158.append(id);},nativePosition:o=>o.nativePosition??native(o.position),
   message:()=>b,clients:b.clients,clientObject:client=>client.object?s.registry.get(client.object.id)??null:null,
   mapPin:(_message,client,id,point,_note,enabled)=>{
    // The native command ignores this transport return value. Record the
    // missing delivery instead of aborting successful world-object creation.
    runtimeDiagnostics.record('world.map-pin-message-unimplemented','Created waypoint requires native map-pin delivery and map UI',{...s.diagnosticContext(id),recipientId:client.object?.id,position:[...point],enabled});return 0;
   },
  };
 }
 async create(args,self){
  try{return await scriptCreateObject(args,self,this.providers(self));}
  catch(error){this.session.report(error,{...this.session.diagnosticContext(self),operation:'native-create-object',requestedType:args[0],resource:args[1]});throw error;}
 }
}
