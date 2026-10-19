import {MapUi} from './map_ui.js';
import {encodeGffText} from './gff_text.js';
import {nativeSinf,nativeCosf} from './native_math.js';

// Reuse installed map artwork and verified marker projection. This adapter is
// a read-only view model, not ModuleSession, local AI, or canonical allocation.
export class NetworkMapView{
 constructor(body,{world,assets,resolve}){
  Object.assign(this,{world,resolve});this.pins=new Map();this.view={player:{},diagnosticContext:()=>({areaId:this.world()?.areaId}),mapPins:{scene:{initialLoaded:true,nativeMapPins2b8:[]}}};
  const w=world(),area=w.registry.get(w.areaId)?.state;if(!area)throw new Error('Native map area is unavailable');
  this.view.currentArea={id:area.id,width:area.width,height:area.height,tilesetResRef:area.tileset,tilePlacements:area.tiles.map(t=>({Tile_ID:t.fields['14'],Tile_Orientation:t.fields['24']}))};
  this.updateActor();this.ui=new MapUi(body,this.view,assets,{network:true,tileStates:()=>Uint8Array.from(this.world()?.registry.get(this.world().localObjectId)?.playerState?.mapExploration?.[area.id]??Array(area.width*area.height).fill(0))});
 }
 updateActor(){const w=this.world(),a=w.registry.get(w.localObjectId),p=a?.replicated?.position??[0,0,0],o=a?.replicated?.orientation,radians=Math.fround((o?.yaw??0)*Math.PI/180),d=Array.isArray(o)?o:o?.vector??[-nativeSinf(radians),nativeCosf(radians),0];Object.assign(this.view.player,{id:w.localObjectId,areaId:w.areaId,position:[p[0],p[2],-p[1]],orientation:[d[0],d[2],-d[1]]});Object.assign(this.view.mapPins.scene,{areaId:w.areaId,clientObjectId:w.localObjectId});}
 async sync(){
  const w=this.world();if(!w||w.areaId!==this.view.currentArea.id)return;this.updateActor();const source=[...[...w.mapPins.values()].map(p=>({...p,type:0,reference:p.id})),...(w.registry.get(w.areaId)?.state?.playerMapPins??[]).map(p=>({...p,name:{text:p.text},enabled:true,type:1,reference:p.index}))],live=new Set();
  for(const p of source){const key=`${p.type}:${p.reference}`;live.add(key);let pin=this.pins.get(key);if(!pin){pin={nativeReference188:p.reference,nativeType18c:p.type};this.pins.set(key,pin);}Object.assign(pin,{nativeEnabled170:Number(p.enabled),nativePosition38:p.position,nativeText178:encodeGffText(await this.resolve(p.name))});}
  for(const key of this.pins.keys())if(!live.has(key))this.pins.delete(key);this.view.mapPins.scene.nativeMapPins2b8=[...this.pins.values()];await this.ui.refresh();
 }
 destroy(){this.ui.destroy();}
}
