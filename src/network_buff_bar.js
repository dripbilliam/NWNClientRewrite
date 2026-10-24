import {parse2da} from './area.js';
import {decodeResourceText,RESOURCE_TYPE} from './resource_archive.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry} from './spell_metadata.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
// The wire Boolean is icon state, not presence. Both 0 and 1 are active;
// only the server's removal list removes an icon. No duration is transmitted.
export function networkEffectIcons(actor){return Object.entries(actor?.playerState?.effectIcons??{}).map(([id,state])=>({id:Number(id),state})).filter(row=>Number.isInteger(row.id)&&row.id>=0&&row.id<=65535).sort((a,b)=>a.id-b.id);}
export class NetworkBuffBarView{
 constructor(viewport,{world,assets,resolve,icon,report=(code,message,data)=>runtimeDiagnostics.record(code,message,data)}){
  Object.assign(this,{viewport,world,assets,resolve,icon,report});this.tables=new WeakMap();this.generation=0;
  this.host=document.createElement('aside');this.host.className='network-buff-bar';this.host.hidden=true;this.host.setAttribute('aria-label','Active effects');this.list=document.createElement('div');this.list.className='network-buff-icons';this.list.setAttribute('role','list');this.host.append(this.list);viewport.append(this.host);
  this.tooltip=document.createElement('div');this.tooltip.className='network-buff-tooltip';this.tooltip.id='network-active-effect-tooltip';this.tooltip.setAttribute('role','tooltip');this.tooltip.hidden=true;viewport.append(this.tooltip);
  for(const type of ['pointerdown','pointerup','click','dblclick','contextmenu'])this.host.addEventListener(type,event=>{event.stopPropagation();if(type==='contextmenu')event.preventDefault();});
  viewport.addEventListener('pointerdown',event=>{if(!this.host.contains(event.target))this.hideTooltip();},true);window.addEventListener('blur',()=>this.hideTooltip());window.addEventListener('keydown',event=>{if(event.key==='Escape')this.hideTooltip();});this.resize=new ResizeObserver(()=>{if(this.hovered)this.showTooltip(this.hovered);});this.resize.observe(viewport);this.reset();
 }
 reset(){this.generation++;this.owner=null;this.assetOwner=null;this.actorId=null;this.version=null;this.rows=new Map();this.list.replaceChildren();this.host.hidden=true;this.host.dataset.state='null';this.hideTooltip();}
 hideTooltip(){this.hovered=null;this.pinned=false;this.tooltip.hidden=true;}
 showTooltip(row){if(!row?.button.isConnected)return;this.hovered=row;this.tooltip.textContent=row.label;this.tooltip.hidden=false;const view=this.viewport.getBoundingClientRect(),anchor=row.button.getBoundingClientRect(),rect=this.tooltip.getBoundingClientRect();this.tooltip.style.left=`${Math.max(4,Math.min(anchor.right-view.left-rect.width,view.width-rect.width-4))}px`;this.tooltip.style.top=`${Math.max(4,Math.min(anchor.bottom-view.top+6,view.height-rect.height-4))}px`;}
 table(assets){if(!this.tables.has(assets))this.tables.set(assets,Promise.resolve().then(()=>assets.resolver.getResource('effecticons',RESOURCE_TYPE.TWO_DA)).then(bytes=>parse2da(decodeResourceText(bytes))).catch(error=>{this.report('network.effect-icons-table-unavailable',error.message);return null;}));return this.tables.get(assets);}
 async describe(row,world,assets,generation,version){
  const current=()=>generation===this.generation&&world===this.world()&&assets===this.assets()&&this.rows.get(row.id)===row&&this.actorId===world.localObjectId&&version===this.version;
  const table=await this.table(assets);if(!current())return;const ref=table?intEntry(table,row.id,'StrRef'):null,name=table?nativeStringEntry(table,row.id,'Icon').value:'';
  const label=ref?.found&&ref.value>0?await this.resolve({strRef:ref.value>>>0},this.actorId):'';if(!current())return;row.label=label||`Effect ${row.id}`;row.button.setAttribute('aria-label',row.label);row.button.dataset.label=row.label;if(this.hovered===row)this.showTooltip(row);
  if(name&&name!=='****')try{const url=await this.icon(name);if(!current())return;if(url){const image=document.createElement('img');image.src=url;image.alt='';image.draggable=false;row.button.replaceChildren(image);row.button.dataset.icon=name;}}catch(error){if(current())this.report('network.effect-icon-unavailable',error.message,{iconId:row.id,resource:name});}
 }
 sync(){
  const world=this.world(),assets=this.assets(),actor=world?.registry.get(world.localObjectId);if(!world||!assets||!actor||actor.replicationRemoved){if(this.owner)this.reset();return;}
  if(this.owner!==world||this.assetOwner!==assets||this.actorId!==world.localObjectId){this.reset();this.owner=world;this.assetOwner=assets;this.actorId=world.localObjectId;}
  const icons=networkEffectIcons(actor),ids=new Set(icons.map(row=>row.id)),version=world.tlkOverrideVersion??0,changed=version!==this.version;this.version=version;
  for(const[id,row]of this.rows)if(!ids.has(id)){if(this.hovered===row)this.hideTooltip();row.item.remove();this.rows.delete(id);}
  let cursor=this.list.firstChild;for(const{id,state}of icons){let row=this.rows.get(id),fresh=!row;if(fresh){const item=document.createElement('span'),button=document.createElement('button');item.setAttribute('role','listitem');button.type='button';button.className='network-buff-icon';button.textContent='?';button.setAttribute('aria-describedby',this.tooltip.id);item.append(button);row={id,item,button,label:`Effect ${id}`};button.setAttribute('aria-label',row.label);button.dataset.effectId=id;this.rows.set(id,row);
    button.addEventListener('pointerenter',()=>{this.pinned=false;this.showTooltip(row);});button.addEventListener('pointerleave',()=>{if(!this.pinned&&document.activeElement!==button)this.hideTooltip();});button.addEventListener('focus',()=>this.showTooltip(row));button.addEventListener('blur',()=>{if(!this.pinned)this.hideTooltip();});button.addEventListener('click',()=>{this.pinned=!this.pinned;if(this.pinned)this.showTooltip(row);else this.hideTooltip();});
   }
   row.button.dataset.effectState=String(state);if(row.item!==cursor)this.list.insertBefore(row.item,cursor);cursor=row.item.nextSibling;if(fresh||changed)void this.describe(row,world,assets,this.generation,version).catch(error=>{if(this.owner===world)this.report('network.effect-icon-description-unavailable',error.message,{iconId:id});});
  }
  this.host.hidden=icons.length===0;this.host.dataset.state=JSON.stringify({actorId:this.actorId,icons});if(!icons.length)this.hideTooltip();
 }
}
