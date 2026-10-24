import {parseTileset} from '../../src/area.js';
import {decodeResourceText,RESOURCE_TYPE} from '../../src/resource_archive.js';
import {presentMapPin,playerMapPosition,mapPlayerHeading} from '../../src/map_pin_presentation.js';
import {nativeSinf,nativeCosf} from '../../src/native_math.js';
import {richText} from './gameplay-text.mjs';
const f=Math.fround;
// Reuses installed artwork and original pin/player projection. Exploration is
// exclusively the replicated mapExploration state; this client reveals no tiles.
export class MapService{
 constructor({actions,art=async()=>null,onView=()=>{}}){Object.assign(this,{actions,art,onView});this.serial=0;this.epoch=0;this.tasks=new Set();this.reset();}
 get session(){return this.actions.session;}
 capture(){return{...this.actions.capture(),world:this.session.world};}
 owned(s){return s?.world===this.session.world&&this.actions.owned(s);}
 reset(){this.epoch++;this.opened=false;this.view=null;this.signature=null;this.poseKey=null;}
 async retire(){this.reset();await Promise.allSettled([...this.tasks]);return{pendingArt:this.tasks.size,closed:true};}
 data(v){const s=v.scope,states=s.actor.playerState?.mapExploration?.[s.areaId]??Array(v.area.width*v.area.height).fill(0),pins=[...[...s.world.mapPins.values()].map(p=>({...p,type:0,reference:p.id})),...(v.area.playerMapPins??[]).map(p=>({...p,name:{text:p.text},enabled:true,type:1,reference:p.index}))];return{states,pins,signature:JSON.stringify([states,pins,s.world.customTokens,s.world.tlkOverrideVersion])};}
 async close(){this.reset();this.actions.emit({kind:'map-closed'});}
 async open(){if(this.opened&&this.view){await this.refresh(true);return;}const epoch=++this.epoch,s=this.capture();if(!this.owned(s))throw Error('Map owner is unavailable');this.opened=true;
  const area=s.world.registry.get(s.areaId)?.state,size=area?.width*area?.height;
  if(!area||!Number.isInteger(size)||size<1||size>65536||area.tiles?.length!==size)throw Error('Native map tile placements are unavailable');
  const set=parseTileset(decodeResourceText(await this.session.getResource(area.tileset,RESOURCE_TYPE.SET))),art=[],keys=new Map(),cells=[];
  const add=row=>{const key=JSON.stringify(row);if(!keys.has(key)){keys.set(key,art.length);art.push(row);}return keys.get(key);};
  for(const tile of area.tiles){const definition=set.tiles[tile.fields['14']],orientation=tile.fields['24']??0;if(!definition||!Number.isInteger(orientation)||orientation<0||orientation>3)throw Error('Native map tile definition/orientation is unavailable');cells.push(add({kind:'tile',reference:definition.mapImage,orientation}));}
  const controls={};for(const[key,reference,state]of[['pin','CTL_MAP_PIN','up'],['hilite','CTL_MAP_PIN','hilite'],['down','CTL_MAP_PIN','down'],['player','CTL_MAP_XMARKER','up']])controls[key]=add({kind:'control',reference,state});
  if(epoch!==this.epoch||!this.opened||!this.owned(s))return;const id=++this.serial;this.view={id,scope:s,area,controls};this.signature=null;this.poseKey=null;this.actions.emit({kind:'map-view',viewId:id,width:area.width,height:area.height,cells,controls,zoom:16});this.onView({id,area,scope:s});await this.refresh(true);
  let cursor=0;const valid=()=>this.opened&&this.view?.id===id&&this.owned(s);const work=Promise.all(Array.from({length:Math.min(4,art.length)},async()=>{while(cursor<art.length&&valid()){const index=cursor++,row=art[index];try{const skin=await this.art(row);if(!skin?.url)throw Error('Installed map artwork is unavailable');if(valid())this.actions.emit({kind:'map-art',viewId:id,index,skin});}catch(error){if(valid()){this.actions.diagnose('godot.map-art-unavailable',error.message);this.actions.emit({kind:'map-notice',viewId:id,text:error.message});}}}}));this.tasks.add(work);void work.finally(()=>this.tasks.delete(work));
 }
 async refresh(force=false){if(!this.opened||!this.view)return;const v=this.view,s=v.scope;if(!this.owned(s))return;const a=s.actor,area=v.area,{states,pins,signature}=this.data(v);
  if(force||signature!==this.signature){const rows=[];for(const p of pins){let point=null;const widget={nativeStateE8:0};if(p.enabled)await presentMapPin({width:area.width,height:area.height,zoom514:16},widget,0,{position:()=>p.position,tileState:(_m,i)=>states[i]??0,attach:()=>1,model:()=>widget,viewOrigin:()=>[0,0,0],transform:(_m,_root,value)=>{point=value;}});rows.push({reference:p.reference,type:p.type,visible:widget.nativeStateE8===1,point,rich:richText(await this.actions.text.resolve(p.name,s.actorId))});}
   if(this.view!==v||!this.opened||!this.owned(s)||signature!==this.data(v).signature)return;this.signature=signature;this.actions.emit({kind:'map-state',viewId:v.id,explored:Array.from(states,n=>n===1),pins:rows});}
  const p=a.replicated?.position??[0,0,0],o=a.replicated?.orientation,radians=f((o?.yaw??0)*Math.PI/180),d=Array.isArray(o)?o:o?.vector??[-nativeSinf(radians),nativeCosf(radians),0],point=playerMapPosition({width:area.width,height:area.height,zoom514:16},p),heading=mapPlayerHeading(d),key=JSON.stringify([point,heading]);
  if(force||key!==this.poseKey){this.poseKey=key;this.actions.emit({kind:'map-pose',viewId:v.id,point,heading});}
 }
}
