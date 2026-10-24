import {nativeStringEntry} from './spell_metadata.js';
import {intEntry} from './combat_stats.js';

// Read active resource rows for presentation, never for action resolution.
export function networkQueuedAction(entry,tables){
 const {actions,spells,feat}=tables;if(!actions)throw new Error('Native actions table is unavailable');
 const str=(table,id,key)=>nativeStringEntry(table,id,key),name=intEntry(actions,entry.type,'STRING_REF');
 let icon=str(actions,entry.type,'ICONRESREF'),spell=null,hidden=false;
 if(!entry.special&&(entry.type===4||entry.type===19)){
  spell=spells?.orderedRows?.[entry.spell|0];hidden=entry.type===19&&!spell;
  icon={value:''};
  if(spell){const associated=intEntry(spells,entry.spell|0,'FeatID').value&65535;icon=entry.type===4&&associated?str(feat,associated,'ICON'):str(spells,entry.spell|0,'IconResRef');}
 }else if(!icon.found&&!entry.special)icon={value:'ir_use'};
 return{hidden,icon:icon.value.toLowerCase()||null,strRef:name.found?name.value>>>0:null,label:str(actions,entry.type,'LABEL').value||'Action',missingSpell:!entry.special&&[4,19].includes(entry.type)&&!spell};
}

// Native874a00 dims the clicked widget. Only a server D update removes it.
export class NetworkActionQueueView{
 constructor(viewport,{world,quickbar,resolve,cancel,report}){
  Object.assign(this,{viewport,world,quickbar,resolve,cancel,report});this.generation=0;this.pending=new Set();
  this.host=document.createElement('div');this.host.className='network-action-queue';this.host.setAttribute('aria-label','Action queue');this.host.hidden=true;viewport.append(this.host);
  for(const type of ['pointerdown','pointerup','click','dblclick','contextmenu','wheel','keydown','keyup'])this.host.addEventListener(type,e=>e.stopPropagation());
 }
 reset(){this.generation++;this.signature=null;this.pending.clear();this.host.replaceChildren();this.host.hidden=true;this.host.dataset.state='[]';this.viewport.classList.remove('network-queue-visible');}
 async sync(){
  const world=this.world(),actor=world?.registry.get(world.localObjectId),assets=this.quickbar.assets,tables=this.quickbar.tables;
  if(world!==this.owner||actor?.id!==this.actorId||assets!==this.assets){this.reset();this.owner=world;this.actorId=actor?.id;this.assets=assets;}
  if(!actor||!assets||!tables)return;
  const entries=actor.playerState?.actionQueue??[],signature=JSON.stringify(entries);if(signature===this.signature)return;this.signature=signature;
  for(const serial of this.pending)if(!entries.some(e=>e.widgetSerial===serial))this.pending.delete(serial);
  const generation=++this.generation,current=()=>generation===this.generation&&world===this.world()&&world.localObjectId===actor.id&&assets===this.quickbar.assets;
  const descriptions=entries.map(entry=>({entry,...networkQueuedAction(entry,tables)}));
  for(const row of descriptions)if(row.missingSpell)this.report('network.action-queue-spell-unavailable','Native queued spell metadata is unavailable',{spellId:row.entry.spell,actionId:row.entry.type});
  const rows=descriptions.filter(row=>!row.hidden).slice(0,10);
  this.host.replaceChildren();this.host.hidden=!rows.length;this.viewport.classList.toggle('network-queue-visible',Boolean(rows.length));
  this.host.dataset.state=JSON.stringify(entries.map(e=>({...e,pending:this.pending.has(e.widgetSerial)})));
  const decorate=rows.map(async row=>{
   const {entry}=row,b=document.createElement('button');b.type='button';b.className='game-queued-action';b.dataset.widgetSerial=String(entry.widgetSerial);b.dataset.actionId=String(entry.type);b.dataset.groupId=String(entry.group);b.title=row.label;b.setAttribute('aria-label','Cancel '+row.label);b.style.opacity=this.pending.has(entry.widgetSerial)?'.5':'1';this.host.append(b);
   b.addEventListener('click',()=>{if(!current())return;this.pending.add(entry.widgetSerial);b.style.opacity='.5';this.host.dataset.state=JSON.stringify(entries.map(e=>({...e,pending:this.pending.has(e.widgetSerial)})));void this.cancel(entry.type,entry.group).catch(error=>{if(current())this.report('network.action-cancel-failed',error.message);});});
   const results=await Promise.allSettled([assets.skin('ctl_actionqueue'),row.strRef===null?row.label:this.resolve({strRef:row.strRef}),row.icon?this.quickbar.icon(row.icon):null]);
   if(!current())return;
   for(const result of results)if(result.status==='rejected')this.report('network.action-queue-presentation-failed',result.reason.message,{actionId:entry.type,resource:row.icon});
   const [skin,label,url]=results.map(r=>r.status==='fulfilled'?r.value:null);
   if(skin?.url){b.style.backgroundImage=`url("${skin.url}")`;b.dataset.nativeModel='ctl_actionqueue';}
   b.title=label||row.label;b.setAttribute('aria-label','Cancel '+b.title);
   if(url){const img=document.createElement('img');img.className='game-queue-icon';img.alt='';img.src=url;b.append(img);}
  });
  await Promise.all(decorate);
 }
}
